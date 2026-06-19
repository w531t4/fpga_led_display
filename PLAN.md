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

- [ ] **1.1** `row_prefetch.sv` — contains the ping-pong row buffer BRAM banks internally and the
  prefetch state machine. When triggered, iterates `col = 0..PIXEL_WIDTH-1`, reads `multimem`
  via port-B, and writes `mem_read_data_t` into the inactive bank. Drives `bank_sel` (swaps
  registered when `fill_done` and `brightness_mask == 1` at `row_latch`). Read port accepts
  `mem_read_addr_t` and ignores the row field, so `framebuffer_fetch.sv` needs no changes.
  Trigger: `brightness_mask == 1` at `row_latch` (8× display-time slack before next row needed).

- [ ] **1.2** Wire in `main.sv` only — instantiate `row_prefetch`; reroute port B of
  `framebuffer_fabric` to `row_prefetch` (was `framebuffer_fetch`); connect `framebuffer_fetch`
  data/address ports to `row_prefetch` read port instead. Feed `row_latch` and `brightness_mask`
  from `matrix_scan`. `framebuffer_fetch.sv` and `framebuffer_fabric.sv` unchanged.

- [ ] **1.3** Verify — run `tb_main` and compare waveforms against pre-patch baseline. Verify on
  hardware: solid-color fill, then column-ramp pattern.

## Phase 2 — SDRAM standalone verification

Confirm the controller is reliable before swapping the backend.

- [ ] **2.1** `litedram_bist` hardware run — BIST module and `USE_LITEDRAM_BIST` build target
  already exist. Flash and confirm `done` LED asserts with no error bits.

- [ ] **2.2** `litedram_write_mirror` hardware run — `seen_write`, `dropped`, and `error` map to
  LEDs in the `USE_LITEDRAM_WRITE_MIRROR` build. Confirm `seen_write` without `error` or
  `dropped` under normal write traffic. (Already simulation-tested.)

## Phase 3 — SDRAM backend swap

- [ ] **3.1** SDRAM address mapping — add function to `calc.sv`:
  ```
  sdram_word_addr = (frame × buffer_words) + (scan_pos × PIXEL_WIDTH × 2) + (col × 2) + half
  ```
  where `scan_pos = y[3:0]`, `half = y[4]`. Mapping is pure bit-slicing; verify by inspection.

- [ ] **3.2** SDRAM arbiter — new module; generic three-client fixed-priority req/grant mux on
  the single LiteDRAM native port. Each client (including the copy engine) is its own requester;
  the arbiter contains no client-specific logic:
  - Priority 1 (highest): row prefetch — interleaved grants, not one monolithic burst, so
    priority-2 stalls stay within a few SPI byte periods (~9 FPGA cycles each)
  - Priority 2: upstream delta writes — backpressure reuses the existing per-command
    `ready_for_data` gate (same pattern as `cmd_fillpanel_rfd`/`cmd_fillrect_rfd`), driven by
    arbiter-busy, instead of new logic in `control_module.sv`'s core FSM
  - Priority 3 (lowest): buffer copy — `control_cmd_copyframe.sv` stays the same standalone
    state machine it is today (front-buffer read / back-buffer write over `mem_copy_if`), just
    requesting grants from the arbiter instead of driving `multimem` ports directly.
    Burst-capped at 256 words/grant (~2.8 µs max block). Full copy ~6144 words → ~24 grants per
    frame.

- [ ] **3.3** Rewrite `row_prefetch.sv` — same module name and ports as 1.1; replace the
  `multimem` burst with a linear burst read of `PIXEL_WIDTH × 2` words from the SDRAM arbiter.
  No change to `main.sv`.

- [ ] **3.4** Remove BRAM framebuffer — once SDRAM path is verified, remove `multimem`,
  `framebuffer_fabric`, `mem_lane` from the build. `litedram_write_mirror` becomes dead code
  (write path now goes directly through the arbiter at priority 2).

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
