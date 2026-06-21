<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->

# SDRAM Framebuffer Migration Plan

Move both framebuffers from BRAM to SDRAM, reducing BRAM to a small ping-pong row buffer.
BRAM is exhausted; SDRAM bandwidth is non-issue at 90 MHz with a 16-bit wide part.

CHANGE/ADD/REMOVE AS FEW LINES AS POSSIBLE

## Command Viability

No controller command reads framebuffer data back to the host — `data_out` in every cmd module
is the RAM write data, not a UART TX. Removing `multimem` port A (`QA`) is therefore invisible
to all commands except `copyframe`, which is the only internal user of `QA`.

**blankpanel, fillpanel, fillrect** — iterate framebuffer locations and write constant values.
Pure write path; no QA readback. In the new architecture the SDRAM write address is computed
from the same `{row, col, pixel_byte}` inputs already in `control_module.sv`. Byte enables on
`wdata_we` preserve byte-granularity without read-modify-write. The SPI slave (`spi_slave.sv`) has no receive FIFO — it is a raw shift register with one
`done` pulse per byte. At 80MHz SPI a byte arrives every ~9 FPGA cycles; a monolithic
1,536-word prefetch burst (~35µs) would stall priority-2 for ~350 SPI byte periods, losing
data. The arbiter (3.2) must therefore interleave prefetch grants with priority-2 write windows
rather than issuing one long burst — keeping each priority-2 stall within a handful of SPI byte
periods. Average write demand (~14% of available SDRAM bandwidth) is well within budget once
that interleaving is in place. Result: identical. ✓

**readpixel, readrow, readcol, readrect, readframe** — host streams pixel data; FPGA writes it
to the framebuffer. Same write-path argument as above. No QA readback. Result: identical. ✓

**copyframe** — the only command that uses `QA`: the copy engine reads the front buffer via port
A and writes to the back buffer. In the new architecture `control_cmd_copyframe.sv` stays a
standalone state machine (priority 3 on the SDRAM arbiter) and performs burst-capped
SDRAM-to-SDRAM transfers instead of driving `multimem` directly. The `mem_copy_if` interface
simplifies to a start/done handshake; `control_cmd_copyframe.sv` changes by a few lines.
Functional result: back buffer receives a copy of the front buffer. ✓

**readbrightness, watchdog** — no framebuffer access. Unchanged. ✓

## Phase 1 — Row-buffer front-end (BRAM-backed)

Decouple the BAM engine from the main framebuffer backing store. After this phase the display
pipeline reads from a row buffer instead of directly from `multimem`, but `multimem` is still
the source of truth. No visible change to output.

- [x] **1.1** `row_prefetch.sv` — contains the ping-pong row buffer BRAM banks internally and the
  prefetch state machine. When triggered, iterates `col = 0..PIXEL_WIDTH-1`, reads `multimem`
  via port-B, and writes `mem_read_data_t` into the inactive bank. Drives `bank_sel` (swaps
  registered when `fill_done` and `brightness_mask == 1` at `row_latch`). Read port accepts
  `mem_read_addr_t` and ignores the row field, so `framebuffer_fetch.sv` needs no changes.
  Trigger: `brightness_mask == 1` at `row_latch` (8× display-time slack before next row needed).
  Added `tb_row_prefetch.sv` (standalone, behavioral 2-cycle memory model) covering boot state,
  three consecutive bank swaps, and that the read port ignores `.row`. Passes in simulation.

- [x] **1.2** Wire in `main.sv` only — instantiate `row_prefetch`; reroute port B of
  `framebuffer_fabric` to `row_prefetch` (was `framebuffer_fetch`); connect `framebuffer_fetch`
  data/address ports to `row_prefetch` read port instead. Feed `row_latch` and `brightness_mask`
  from `matrix_scan`. `framebuffer_fetch.sv` and `framebuffer_fabric.sv` unchanged. (Added one
  `matrix_row_latch` alias wire so the FM6126A-blended top-level `row_latch` doesn't leak into
  row_prefetch's trigger; under `-DUSE_FM6126A` it points at `row_latch_intermediary` instead.)

- [x] **1.3 (sim)** `tb_row_prefetch` passes; `make simulation` (full suite, including `tb_main`)
  and `make build/mydesign.json` (yosys synthesis) both pass/complete cleanly with row_prefetch
  wired in. `make lint` clean.
- [x] **1.3 (hw)** Verified on hardware via the existing ESPHome test window — confirmed all
  commands render correctly with `row_prefetch` in the display path. Phase 1 complete.

## Phase 2 — SDRAM standalone verification

Confirm the controller is reliable before swapping the backend.

- [x] **2.1** `litedram_bist` hardware run — confirmed on hardware: LED0 (`init_done`) and LED3
  (`done`) lit, no error/busy bits. LiteDRAM controller initializes and the write/read/compare
  transaction passes.

- [x] **2.2** `litedram_write_mirror` hardware run — confirmed on hardware (at `-DCLK_80`, SPI
  rate halved to 40MHz to get a closeable build; see nextpnr note below): LED0 (`init_done`) and
  LED3 (`seen_write`) lit, LED5 (`error`)/LED6 (`dropped_before_init`) off — controller
  initializes cleanly and never faults. LED4 (`dropped`) was also lit. Doubling the per-byte
  slack (vs. the original 90MHz/80MHz-SPI target) didn't stop the drops, which points away from
  FPGA clock margin and toward real SDR SDRAM command timing (RAS/CAS/precharge) — plausible
  since `write_mirror` issues one full SDRAM transaction per incoming byte, no batching. Reading:
  **controller health confirmed good; the one-word-per-byte opportunistic mirror scheme confirmed
  inadequate**, which is the expected, instrumented-for failure mode per its own header comment
  ("deliberately never backpressures... missed writes are reported with sticky flags") — not a
  blocking regression. Matches why 3.2 specifies real backpressure (`ready_for_data`) for the
  production write path instead of opportunistic mirroring. Phase 2 complete.

  **nextpnr runtime regression found while chasing this:** profiled (8 paired samples, serial,
  not parallel — parallel runs bias the timing measurement itself) plain `make pack` (no LiteDRAM
  flags) before vs. after `row_prefetch`: place+route time went from ~29s avg to ~179s avg
  (~6x), consistently across samples, not seed noise. DP16KD utilization is identical (128/208)
  both ways; TRELLIS_FF only grew 9%. Working theory: `row_prefetch`'s two row-buffer banks must
  route into/out of an already 61%-utilized BRAM region (`multimem`), and that congestion — not
  raw cell count — is what's costing the router. Untested whether this regresses further, holds,
  or improves once 3.4 removes `multimem` (the actual experiment to check that was proposed and
  declined — open question, not resolved). Worth reassessing once 3.1-3.4 land.

## Phase 3 — SDRAM backend swap

- [x] **3.1** SDRAM address mapping — added `calc::sdram_word_addr` / `calc::num_sdram_buffer_words`
  to `calc.sv`:
  ```
  sdram_word_addr = (frame × buffer_words) + (scan_pos × PIXEL_WIDTH × 4) + (col × 4) + (half × 2) + pixel_word
  ```
  where `scan_pos = y[3:0]`, `half = y[4]`, `pixel_word` selects which of a pixel's 2 SDRAM words
  (4 bytes/pixel = 2 words). Corrected from the original 1-bit `half`-only formula, which only
  budgeted one word per pixel instead of two (would have aliased two pixels' data onto the same
  address). `buffer_words = PIXEL_HALFHEIGHT × PIXEL_WIDTH × num_subpanels × 2`, matching the
  96KB/buffer and 3072-word-burst figures already in the Notes section below — no bandwidth/
  capacity numbers changed, only the literal formula. Verified with `tb_calc_sdram_addr.sv`
  (exhaustive collision check over every `(frame, scan_pos, col, half, pixel_word)` combination).

- [x] **3.2** SDRAM arbiter — `sdram_arbiter.sv`: generic fixed-priority req/grant mux on the
  single LiteDRAM native port, parameterized by `NUM_CLIENTS` (client 0 = highest priority).
  Arbitrates at single-word granularity — one transaction in flight at a time, no pipelining —
  and re-arbitrates from scratch after every word. This makes the arbiter genuinely
  client-agnostic (it has no notion of "a row fill" or "a copy"), and gives the originally
  planned behavior for free instead of needing special-cased logic:
  - Priority-1 (row prefetch) bursts are not monolithic: a client that wants many words just
    re-requests one word at a time, so priority-2 never waits longer than a single native-port
    transaction — better than the original "few SPI byte periods" target, with zero interleaving
    logic in the arbiter itself.
  - Priority-2 (upstream writes) backpressure becomes a plain req/done wait inside the write
    client (same toggle-and-wait idiom already used elsewhere in `control_module.sv`), not new
    arbiter-aware branches in the core FSM. Not yet wired in — that lands with the write path in
    a later step.
  - Priority-3 (copy engine) burst-capping is the client's own pacing choice, not the arbiter's;
    nothing in `sdram_arbiter.sv` knows about "256 words."
  Verified standalone via `tb_sdram_arbiter.sv` (priority ordering across simultaneous requests,
  write and read round-trips against a mocked native port, and an explicit interleaving check
  that a lower-priority client gets served as soon as a higher-priority one withdraws its
  request). Not yet wired into `main.sv` — `row_prefetch.sv` becomes its first real client in
  3.3.

- [x] **3.3** Rewrite `row_prefetch.sv` — gated behind a new `USE_SDRAM_FB` flag (requires
  `USE_LITEDRAM`, same convention as `USE_LITEDRAM_BIST`/`USE_LITEDRAM_WRITE_MIRROR`); the default
  build is untouched. The original plan assumed identical ports and no `main.sv` change, but that
  didn't survive contact with 3.2's actual arbiter shape: SDRAM latency isn't fixed the way
  multimem's was, so the fill port had to become a real req/done handshake (`sdram_req`,
  `sdram_done`, `sdram_addr`, `sdram_rdata`, `frame_select`) instead of a free-running strobe.
  Under the flag, each column is fetched one SDRAM word at a time (`WORDS_PER_COL` round trips,
  generically derived as `$bits(mem_read_data_t)/$bits(sdram_word_data_t)` — 4 for the current
  RGB24/2-subpanel config) and assembled into the same bank arrays the display read port already
  used; the old fixed-2-cycle multimem burst path is preserved verbatim under `\`else`. `main.sv`
  now instantiates `sdram_arbiter` (3 clients; row_prefetch is client 0, clients 1/2 idle until
  3.4) and ties off `framebuffer_fabric`'s now-unused RAM-B port, all behind the same flag.
  `tb_row_prefetch.sv` got a matching `\`ifdef` split — shared trigger/swap/read-port assertions,
  a new word-at-a-time behavioral SDRAM mock for the flagged path. Verified: both module variants
  pass standalone simulation (`tb_row_prefetch`, `tb_sdram_arbiter`); default-flag `make lint`/
  `make simulation` unaffected; `make litedram-main-smoke LITEDRAM_MAIN_SMOKE_FLAGS=-DUSE_SDRAM_FB`
  elaborates `main` cleanly (0 errors) the same way BIST/WRITE_MIRROR bring-up was checked.

- [ ] **3.3 (build)** Build/route/timing checkpoint for `USE_LITEDRAM`+`USE_SDRAM_FB` — Phase 1
  and 2 each had an explicit sim *and* hardware checkpoint per item; Phase 3 didn't, which is a
  real gap given this exact spot (LiteDRAM + new logic on top of it) is where timing closure has
  bitten this project before (`write_mirror` only closed at `-DCLK_80`; `row_prefetch` alone cost
  ~6x nextpnr runtime). Confirm `make pack` actually synthesizes, places, routes, and meets timing
  for the arbiter+row_prefetch combination now, before 3.4 stacks the write path and copy engine
  on top of it — isolating any timing problem here is cheaper than finding it at 3.5.

  First hardware attempt (`make pack EXTRA_BUILD_FLAGS="-DUSE_LITEDRAM -DUSE_SDRAM_FB"`, flashed):
  built/routed, but the panel showed unstructured noise that shifted when the ESP32 test-pattern
  button toggled `frame_select`. Root cause: `sdram_arbiter.sv` never gated on `init_done` —
  unlike `litedram_bist.sv`/`litedram_write_mirror.sv`, which both explicitly refuse to issue
  commands before the controller finishes init/calibration. `row_prefetch` starts requesting
  words almost immediately at boot (it primes bank1 with row 1 before any real trigger), so the
  arbiter was very likely driving the native port before LiteDRAM was ready — undefined behavior,
  not "DRAM powers up with random bits." Fixed: the arbiter now takes an `init_done` input and
  won't leave `STATE_IDLE` (grant anyone) until it's high. `tb_sdram_arbiter.sv` got a new
  scenario asserting no grant occurs while `init_done` is low, and that a pending request is
  served the moment it goes high.

  Re-flash after the `init_done` fix: noise persisted, but LED0/LED1 confirmed `init_done` was
  healthy. Not a new bug — root cause is that the write path still isn't connected to SDRAM (that
  lands in 3.4), so SDRAM genuinely holds uninitialized garbage and `row_prefetch` is correctly
  displaying it. Expected at this stage; no further action needed until 3.4's write path lands.

  After 3.4's write path landed, `make pack` only achieved ~38.97MHz (target 80MHz) on
  `sdram_clk`/`clk_root`. Root cause: an entirely combinational round trip from each client's
  address computation through the arbiter, through LiteDRAM's bank-machine logic, back through the
  arbiter's done-detection, into the client's own write-enable — all within one cycle, no register
  breaking the loop. Fixed by registering `sdram_addr`/`sdram_we`/`sdram_wdata_*` in each of the 3
  clients (`row_prefetch.sv`, `sdram_write_client.sv`, `control_cmd_copyframe.sv`) and adding a
  `STATE_DONE` pipeline stage in `sdram_arbiter.sv` so `client_done`/`client_rdata` are pure flop
  outputs. Raised Fmax to ~79.85-81.37MHz (near-miss, varying by seed) — hard failure to placement
  variance.

  That near-miss masked a separate, larger problem: nextpnr place&route runtime had grown to
  ~167-179s (vs ~30s pre-migration). Root cause wasn't BRAM congestion with `multimem` (ruled out —
  removing `multimem` under `USE_SDRAM_FB` didn't help) but `row_prefetch.sv`'s `bank0`/`bank1` row
  buffers (~12KB combined) failing BRAM inference entirely (0 `DP16KD` cells), falling back to
  thousands of flip-flops — caused by missing `(* ram_style="block", no_rw_check *)` and by muxing
  `bank_sel_q ? bank1[addr] : bank0[addr]` *inside* the read-index expression, which defeats yosys's
  BRAM-transparency heuristic. Fixed by adding the attribute and restructuring the read to register
  each bank's output unconditionally before muxing (mirroring `mem_lane.sv`'s established pattern,
  though without instantiating `mem_lane` itself — its port B has a 2-cycle latency, while this read
  port is deliberately 1-cycle to match `framebuffer_fetch.sv`'s existing expectations unchanged).
  Verified 8 `DP16KD` cells now present; place&route dropped to ~33s.

  With timing closed and `make pack` flashed, the panel rendered but showed corrupted/garbage
  image content (not noise — `init_done` was healthy and timing met). Bit-layout of
  `mem_read_data_t` between the write path and `row_prefetch`'s read-side reassembly was traced and
  confirmed correct (no inversion/reversal). Root cause: `control_module.sv`'s `busy` output — the
  only off-chip flow-control signal for the SPI/ESP32 host path (`ready_for_data` is computed but
  never wired off-chip) — went low the instant the *last byte* of a write command (`READFRAME`,
  `FILLRECT`, `FILLPANEL`) was merely *accepted* into the BRAM-style write port, not once that
  byte's SDRAM round trip through `sdram_write_client` actually completed. A host polling `busy`
  before sending `TOGGLE_FRAME` could flip `frame_select` while the tail of an upload was still in
  flight to SDRAM — latent-but-harmless under the old BRAM path (write-accept and write-commit were
  the same cycle there), only a real bug once writes gained multi-cycle SDRAM latency. Fixed by
  adding an `sdram_write_pending_q` tracking flop in `control_module.sv` (set on the write-pulse
  edge, cleared once `sdram_write_ready` is observed high — ordered so the set wins the same cycle
  `sdram_write_ready` hasn't dropped yet) and ORing it into `busy` under `USE_SDRAM_FB`. Note:
  `tb_control_module_copyframe_readframe.sv` ties `sdram_write_ready` to a constant `1'b1` (its
  docstring says it's scoped to command-duration timing, not data correctness), so this exact race
  was structurally invisible to the existing test suite — an integration test wiring the real
  `sdram_write_client` in is still worth adding. `make lint` (default flags) and full `make
  simulation` (default flags) clean; `make litedram-main-smoke` clean for all LiteDRAM flag combos;
  targeted `USE_SDRAM_FB` testbenches (`control_module`, `control_module_copyframe_readframe`,
  `control_module_readrect`, `row_prefetch`, `sdram_arbiter`, `sdram_write_client`) all pass.
  Awaiting real-hardware re-flash to confirm the displayed image is now correct.

- [x] **3.4** Remove BRAM framebuffer — once SDRAM path is verified, remove `multimem`,
  `framebuffer_fabric`, `mem_lane` from the build. `litedram_write_mirror` becomes dead code
  (write path now goes directly through the arbiter at priority 2).

  Per-step progress (write path + copy engine wired into the arbiter as clients 1/2, then the
  BRAM removal):
  - [x] `calc.sv` — added `sdram_pixel_word_select`/`sdram_byte_in_word_select`, decomposing a
    byte index within a (possibly multi-word) pixel into which SDRAM word holds it and which byte
    within that word. Verified exhaustively via `tb_calc_sdram_pixel_word.sv`.
  - [x] `sdram_write_client.sv` (new) — converts `control_module`'s existing per-byte write output
    into a priority-2 arbiter client; `ready` gates `control_module`'s `ready_for_data` so the host
    can't outrun a single in-flight SDRAM write. Verified standalone via
    `tb_sdram_write_client.sv` (every pixel-byte index, plus a `frame_select` flip targeting the
    opposite/back buffer).
  - [x] `control_module.sv` — added `sdram_write_ready` input (AND'd into `ready_for_data` under
    `USE_SDRAM_FB`) and the `sdram_copyframe_*` port group for driving `control_cmd_copyframe` as
    an arbiter client (dual-mode with the original `mem_copy_if` under `\`else`).
  - [x] `control_cmd_copyframe.sv` — rewritten dual-mode: the `\`else` branch is the original
    byte-at-a-time `mem_copy_if` engine, unchanged. Under `USE_SDRAM_FB`, the engine is a flat
    word-for-word copy (`calc::sdram_word_addr` already visits every word in `[0, BUFFER_WORDS)`
    exactly once for a fixed frame, so no per-pixel decomposition is needed) with a frame-based
    base offset for front/back. Verified via a rewritten `tb_control_cmd_copyframe.sv` (behavioral
    one-client SDRAM mock under the flag, original `multimem`-based testbench unchanged under
    `\`else`) — passes for the full 24576-word buffer.
  - [x] Wired all three real clients (`row_prefetch`=0, `sdram_write_client`=1,
    `control_cmd_copyframe`=2) into `sdram_arbiter` in `main.sv`. Added the missing
    `sdram_client_wdata_we_vec_t`/`sdram_client_wdata_vec_t` typedefs to `types.sv` to match the
    existing `sdram_client_addr_vec_t` pattern (parallel per-port vectors, mirroring
    `sdram_arbiter.sv`'s own parallel-port shape — not a struct, by design discussion). Client 2
    ties off cleanly without `DOUBLE_BUFFER` (copyframe command doesn't exist in that build).
  - [x] Removed `framebuffer_fabric` from `main.sv` under `USE_SDRAM_FB` (replaced by
    `sdram_write_client`); `multimem`/`mem_lane` become orphaned-but-harmless in the source list
    (still compiled, never instantiated under the flag). `mem_copy_if copy_int` is now only
    declared under `\`ifndef USE_SDRAM_FB`, since nothing drives or consumes it once
    `control_cmd_copyframe`'s copy traffic goes through the arbiter instead.
  - [x] Re-verified: `make lint` clean (default flags) and clean of any code-introduced
    issues under `-DUSE_LITEDRAM -DUSE_SDRAM_FB` (only the pre-existing, already-documented ECP5
    primitive-cell gaps remain, identical to the BIST/WRITE_MIRROR combos). `make litedram-main-smoke`
    now passes 0-errors for all three LiteDRAM flag combos (`USE_LITEDRAM_BIST`,
    `USE_LITEDRAM_WRITE_MIRROR`, `USE_SDRAM_FB`) — fixed by adding `--top main` to the `read_slang`
    invocation in `mk/litedram.mk`, since removing `framebuffer_fabric`'s instantiation left it as
    an orphaned module with an unconnected interface port, which `read_slang` was elaborating as
    an implicit second top before `hierarchy -top main` could prune it. `make simulation`
    (full suite) and `make build/mydesign.json` (yosys synthesis, default flags) both pass.
    Fixed three control_module-level testbenches that referenced the now-gone `cmd_copyframe_if`
    port under `USE_SDRAM_FB` (`tb_control_module.sv`, `tb_control_module_readrect.sv` — neither
    exercises COPYFRAME, so just tie off the new ports; `tb_control_module_copyframe_readframe.sv`
    — does exercise COPYFRAME, so got its own dual-mode behavioral SDRAM mock, mirroring
    `tb_control_cmd_copyframe.sv`'s).

  **Open performance question for 3.5:** `tb_control_module_copyframe_readframe.sv` used to assert
  copyframe completes within 20% of readframe's cycle count, using the old engine's real ~1-byte/clk
  multimem throughput. Under `USE_SDRAM_FB` that assertion is dropped (cycle counts are still
  measured and reported) because the standalone testbench has no real arbiter/LiteDRAM — it can only
  measure against a mocked, invented latency constant (`params::SDRAM_MOCK_READ_LATENCY = 3`),
  which produced a copyframe time statistically indistinguishable from readframe's. That number
  reflects the mock, not real hardware. A back-of-envelope estimate using the project's own
  documented SDRAM timing figure (PLAN.md 3.2/Command-Viability: ~22.8ns/word, from the "1,536-word
  burst (~35µs)" figure) puts real copyframe at one read + one write per word ≈ 45.6ns/word ×
  24576 words ≈ 1.12ms, against readframe's ≈3.69ms at the modeled 80Mbit SPI rate — roughly 30% of
  readframe time, worse than the old engine's comfortable <20% margin but not in the same league as
  the mock's ~100%. This needs a real hardware measurement (e.g. instrumenting
  `control_cmd_copyframe` with a cycle counter exposed the way `litedram_bist` exposes `busy`/`done`
  on LEDs) — not resolved by simulation alone. If it comes back too slow, the current engine reads
  then writes each word strictly sequentially (no overlap between word N's write and word N+1's
  read), which is a real, available optimization lever, not a dead end.

- [ ] **3.5** Verification sequence — in order:
  1. Solid fill (white) — confirms no address aliasing
  2. Column ramp (x → hue) — confirms `col` address bits correct
  3. Row ramp (y → hue) — confirms `scan_pos` / `half` bits correct
  4. Walked pixel (single pixel at known coordinates) — confirms interleave and frame-select
  5. Double-buffer swap under live write traffic — confirms arbiter backpressure and copy engine

## Notes

- Pixel format is unchanged: RGB24 already pads to 4 bytes/pixel via `color_field_subpanel_t`.
  "XRGB8888" in the design doc is just naming what already exists.
- Net BRAM after migration: ~12 KB (two 6 KB row buffer banks) + gamma LUT. Everything else freed.
- Chain length, not memory, is now the binding growth constraint. Substantial expansion means a
  second parallel chain → second prefetch stream into the same arbiter.
- `litedram_write_mirror` address function will need updating in 3.5 if it is repurposed;
  current mapping is `{frame, bram_addr}` (one word per byte), not scan-order.
