<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# SDRAM Framebuffer Migration Plan

## Goal

Move full-frame storage out of ECP5 BRAM and into the ULX3S-attached RAM, while preserving:

- deterministic LED scan timing
- existing host command semantics
- current testbench-driven development style
- the ability to support double buffering and `COPY_FRAME`

This note intentionally refines the approach several times before settling on the recommended plan.

## Current Architecture Summary

Today the design stores framebuffer contents in on-chip BRAM via:

- `main.sv`
- `framebuffer_fabric.sv`
- `multimem.sv`
- `mem_lane.sv`
- `framebuffer_fetch.sv`

Important current properties:

- writes are byte-granular
- scanout reads a column at a time from all lanes in parallel
- the storage layout is optimized for BRAM banking, not for off-chip burst traffic
- `DOUBLE_BUFFER` is already a first-class concept
- `COPY_FRAME` currently relies on a Port-A style readback path (`QA`)

The ULX3S constraints file already contains SDRAM pin mappings in [src/constraints/ulx3s_v316.lpf](/workspaces/fpga_led_display/src/constraints/ulx3s_v316.lpf:254), so the board-level routing hook already exists.

## Why Migrate

The current default build is already large enough that BRAM pressure matters.

For the default non-sim build flags in [Makefile](/workspaces/fpga_led_display/Makefile:46):

- `PIXEL_WIDTH = 64 * 12 = 768`
- `PIXEL_HEIGHT = 32`
- `BYTES_PER_PIXEL = 3` for `RGB24`
- `NUM_FRAMEBUFFERS = 2` when `DOUBLE_BUFFER` is enabled

That implies:

- one packed frame = `768 * 32 * 3 = 73,728 bytes`
- two packed frames = `147,456 bytes`

That is a good fit for external SDRAM and a poor long-term fit for BRAM if we want larger geometries, deeper buffering, overlays, or future effects.

## Design Constraint That Changes The Plan

The scan path does **not** need random full-frame bandwidth every pixel forever. It needs:

- deterministic access during active scan
- the same row pair reused across several brightness bitplanes
- enough slack to prefetch the next row pair before it is needed

That means the best plan is not "replace BRAM with SDRAM 1:1".

The best plan is:

- external RAM holds full frames
- small BRAM caches hold the row data currently being displayed or about to be displayed

This keeps timing-sensitive scan logic on-chip while moving bulk capacity off-chip.

## Iteration 1: Direct Replacement

### Idea

Replace `multimem.sv` with an SDRAM-backed module that keeps the same visible behavior:

- controller still emits byte writes
- fetcher still asks for column-oriented data
- copy engine still reads one byte back through a `QA`-like path

### Advantages

- smallest surface-area change to `control_module.sv`
- easiest conceptual substitution
- preserves most existing tests

### Problems

- preserves a BRAM-friendly lane layout that is unfriendly to SDRAM bursts
- requires low-latency pseudo-random reads during scanout
- makes timing depend on SDRAM arbitration during display
- complicates `COPY_FRAME`, because the current design assumes tight read-after-address behavior
- likely turns every row fetch into many tiny off-chip accesses

### Verdict

Not recommended, except as a temporary spike to validate controller pinout and SDRAM bring-up.

## Iteration 2: Full-Frame SDRAM With No On-Chip Cache

### Idea

Store frames in SDRAM using a new linear frame layout and read pixels directly from SDRAM during scanout.

### Advantages

- storage layout can be optimized for burst reads
- breaks the design free from the current `multimem` lane organization
- simpler long-term memory image

### Problems

- scan timing becomes coupled to SDRAM latency and refresh pauses
- every brightness pass may re-read the same row data unless we add state to avoid it
- output timing becomes harder to prove
- any arbitration bug can manifest as visible display corruption

### Verdict

Better than Iteration 1, but still not the best architecture. It moves capacity off-chip without adequately protecting the timing-critical scan path.

## Iteration 3: Hybrid SDRAM + BRAM Row Cache

### Idea

Keep the current command/control behavior mostly intact, but split framebuffer responsibilities:

- SDRAM stores complete frames
- BRAM caches one or more row pairs for active scan
- scanout consumes from BRAM cache only
- a prefetch engine refills cache from SDRAM ahead of use

### Why This Matches The Existing Design

`matrix_scan.sv` already exposes:

- `row_address`
- `row_address_active`
- `column_address`
- `clk_pixel_load`
- `brightness_mask`

The key observation is that a row pair is reused across the full PWM brightness sequence. We should fetch that row pair once, keep it on-chip, and reuse it until `row_address_active` advances.

### Advantages

- protects deterministic scan timing
- makes off-chip access burst-friendly
- reduces repeated off-chip reads of the same row data
- preserves room for future geometries
- fits naturally with `DOUBLE_BUFFER`

### Problems

- larger initial refactor than Iteration 1
- needs a real SDRAM controller and a cache/prefetch policy
- requires explicit coherency rules in single-buffer mode

### Verdict

This is the best overall architecture and should be the target plan.

## Recommended Final Architecture

### 1. Introduce A Storage-Agnostic Framebuffer Interface

Create a new interface layer between control/fetch logic and the physical storage implementation.

Suggested split:

- `fb_store_if.sv`
- `fb_store_bram.sv`
- `fb_store_sdram.sv`

The point is to stop letting `multimem` shape the whole design.

The generic store interface should support:

- byte write requests for command handlers
- burst row-pair read requests for scan prefetch
- frame copy requests
- frame-select or front/back base address selection

The existing BRAM implementation should become one backend for this interface so we can A/B test behavior before fully switching to SDRAM.

### 2. Change The External Frame Layout

Do **not** preserve the current lane-oriented `multimem` storage image in SDRAM.

Recommended SDRAM frame layout:

- linear row-major pixels in host order
- contiguous bytes per pixel
- frame base address per framebuffer

For the default build:

- frame byte offset = `((row * PIXEL_WIDTH) + col) * BYTES_PER_PIXEL`

Why:

- `READFRAME` and `COPY_FRAME` become naturally sequential
- host command semantics already think in row-major pixels
- burst reads for full rows become straightforward
- address math becomes easier to reason about than lane-packing

### 3. Add A Scan Cache Layer

Replace the current `framebuffer_fetch.sv` role with two pieces:

- `scan_prefetch.sv`
- `scan_row_cache.sv`

Responsibilities:

- `scan_prefetch.sv`
  - watches row transitions
  - issues SDRAM bursts for the next row pair
  - fills a BRAM cache before the row becomes active

- `scan_row_cache.sv`
  - exposes deterministic per-column data to `pixel_split.sv`
  - returns top/bottom subpanel pixel fields without off-chip timing dependency

Recommended cache structure:

- ping-pong row-pair caches
- one cache active for scanout
- one cache refilling for the next row pair

For the current 32-high design with `PIXEL_HALFHEIGHT = 16`, one row pair means:

- one top row and one bottom row for the same `row_address`

For the default `RGB24` build:

- row pair payload = `PIXEL_WIDTH * 2 * BYTES_PER_PIXEL`
- `768 * 2 * 3 = 4,608 bytes`

If we choose a cache format aligned to the current padded 4-byte slot style, it becomes:

- `768 * 2 * 4 = 6,144 bytes`

Recommendation:

- store SDRAM in compact packed pixels
- expand only inside the BRAM row cache if the existing downstream logic benefits from the padded slot format

This keeps SDRAM traffic lower while letting the scan side stay close to current logic.

### 4. Prefer Double-Buffered Bring-Up First

Initial SDRAM migration should target `DOUBLE_BUFFER` builds first.

Why:

- writes go to the back buffer
- active front-buffer row cache remains coherent during most writes
- on frame toggle we can invalidate all row caches and refill from the new front buffer

That avoids the trickiest early coherency problem: command writes hitting the same rows currently being scanned.

Single-buffer support can come later with explicit invalidation or write-through patching of cached rows.

### 5. Rework `COPY_FRAME`

Do not preserve the current `QA`-style copy implementation as-is.

Instead, implement `COPY_FRAME` as an SDRAM-side bulk copy engine:

- sequential read burst from front frame base
- sequential write burst to back frame base

This is a much better fit for external RAM than the current one-byte pipeline.

The existing `mem_copy_if.sv` can inspire the command/control contract, but the storage backend should own the copy execution details.

### 6. Keep Scan Timing Independent Of SDRAM Arbitration

This is the most important rule in the whole migration.

The matrix output path must never stall waiting for SDRAM during active display of a cached row.

If prefetch misses its deadline, the system should fail in a controlled way:

- blank output for that row
- repeat previous cached row
- latch a debug/status error

It should not produce undefined combinational timing behavior.

## Recommended Execution Plan

### Phase 0: Capture Current Behavior

Before functional migration:

- document current framebuffer semantics from `framebuffer_fabric.sv`, `multimem.sv`, and `framebuffer_fetch.sv`
- add or strengthen tests around:
  - row fetch ordering
  - frame toggle behavior
  - `COPY_FRAME`
  - `READFRAME`
  - `READRECT`

Goal:

- lock down behavioral expectations before changing storage architecture

### Phase 1: Introduce A Backend-Neutral API

Refactor without changing behavior yet.

Steps:

1. create a generic framebuffer store interface
2. wrap existing BRAM logic behind `fb_store_bram`
3. adjust `main.sv` to instantiate the store backend through a thin selection layer
4. keep all current tests passing with the BRAM backend

Goal:

- separate architectural refactor from SDRAM bring-up

### Phase 2: Add SDRAM PHY/Controller In Isolation

Build the SDRAM side as a self-contained subsystem first.

Needed blocks:

- SDRAM init/state machine
- refresh scheduler
- burst read/write engine
- simple command interface suitable for simulation

Do this before wiring it into scanout.

Verification:

- a dedicated SDRAM controller testbench
- memory march tests
- burst write/readback tests
- address wrap tests

Goal:

- prove memory correctness independently of the display pipeline

### Phase 3: Implement Linear Frame Store In SDRAM

Create `fb_store_sdram` with:

- frame base addresses
- linear row-major address mapping
- byte-write support
- sequential burst-read support
- bulk copyframe support

At this stage, scanout can still use the BRAM backend if that helps de-risk integration.

Goal:

- prove command-side storage correctness first

### Phase 4: Add Row-Pair Prefetch Cache

Build the hybrid display path:

- `scan_prefetch.sv`
- `scan_row_cache.sv`

Behavior:

- when a frame becomes active, prefetch row pair 0
- while row pair N is being displayed, fetch row pair N+1
- swap active/prefetch caches at row transition

Goal:

- preserve deterministic display timing while using SDRAM for capacity

### Phase 5: Integrate `DOUBLE_BUFFER`

Rules:

- command writes target back frame
- scan prefetch reads front frame
- `TOGGLE_FRAME` swaps active base addresses
- cache validity clears on frame toggle

Goal:

- get the common deployment mode stable first

### Phase 6: Reintroduce Advanced Commands

Once scanout is stable:

- `COPY_FRAME`
- `READFRAME`
- `READRECT`
- watchdog interaction
- debugger visibility

Goal:

- restore feature parity after the memory architecture lands

### Phase 7: Optional Single-Buffer Coherency

If single-buffer builds still matter after SDRAM migration:

- add row-cache invalidation on writes
- optionally patch cached bytes when writes hit active/prefetched rows

This should be deliberately postponed until double-buffer SDRAM mode is solid.

## Verification Strategy

### New Testbenches

Add focused tests for:

- SDRAM controller initialization
- SDRAM burst read/write correctness
- `fb_store_sdram` byte writes and readback
- row-cache prefetch handoff
- frame toggle invalidation
- copyframe correctness across large frames

### Reuse Existing Tests

Try to keep these green against both BRAM and SDRAM backends:

- [src/testbenches/tb_framebuffer_fabric.sv](/workspaces/fpga_led_display/src/testbenches/tb_framebuffer_fabric.sv:1)
- [src/testbenches/tb_control_module.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_module.sv:1)
- [src/testbenches/tb_control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_cmd_copyframe.sv:1)
- [src/testbenches/tb_main.sv](/workspaces/fpga_led_display/src/testbenches/tb_main.sv:1)

### Hardware Bring-Up Sequence

1. verify SDRAM init only
2. verify simple march/readback over UART/SPI debug hooks
3. verify one static frame fetched through row cache
4. verify repeated frame toggles
5. verify sustained streaming updates

## Risks And Mitigations

### Risk: Scan Underflow

Cause:

- prefetch misses the row deadline

Mitigation:

- cache at least one full row pair
- prefetch one row ahead
- expose underflow status in debugger signals
- fail blank, not metastable

### Risk: SDRAM Controller Complexity

Cause:

- refresh, initialization, burst termination, timing closure

Mitigation:

- isolate SDRAM controller work in its own testbench first
- keep top-level interface narrow
- avoid mixing controller bring-up with scan refactors in the same step

### Risk: Coherency In Single-Buffer Mode

Cause:

- writes may hit rows currently cached for display

Mitigation:

- bring up SDRAM under `DOUBLE_BUFFER` first
- defer single-buffer coherency until later

### Risk: Preserving Existing Host Semantics

Cause:

- storage layout change may accidentally affect command ordering or readback shape

Mitigation:

- keep command protocol unchanged
- enforce compatibility with existing command testbenches
- use row-major linear frame layout because it matches host mental model

## Resolved Implementation Decisions

### SDRAM Part On The Target Board

For the ULX3S 85F, the public board documentation identifies the onboard RAM as a 16-bit Micron `MT48LC32M16` SDRAM, and Crowd Supply lists the board as having `32 MB SDRAM 166 MHz`.

Practical conclusion:

- treat the target as a 32 MB, 16-bit SDR SDRAM device in the `MT48LC32M16` family
- assume a 4-bank SDR SDRAM with enough capacity for multiple full frames plus scratch space

Important nuance:

- the public sources I checked clearly identify the family and capacity, but they do not conclusively prove the full assembly suffix on your exact board from software alone
- for implementation planning, `MT48LC32M16` family behavior is the right target
- if we later need exact timing register values for a specific speed grade suffix, we should confirm the chip top-marking or the assembly BOM for your board revision

### Recommended SDRAM Controller Clock

Recommended answer:

- target `100 MHz` as the primary SDRAM controller clock
- accept `90 MHz` as a conservative bring-up fallback
- do **not** plan around `133 MHz` for the first implementation, even though the memory family is documented in the PC100/PC133 class and the board is marketed with `166 MHz` SDRAM

Why `100 MHz` is the best planning target:

- your existing design already targets `90/100/110 MHz` root-clock variants in [src/packages/params.sv](/workspaces/fpga_led_display/src/packages/params.sv:6)
- you already report successful display operation at `100 MHz` in [README.md](/workspaces/fpga_led_display/README.md:77)
- `100 MHz` is fast enough to make row-pair prefetch bandwidth comfortable if we adopt the recommended hybrid SDRAM + BRAM-cache architecture
- it is much more believable for first-pass timing closure than trying to jump straight to the memory's headline rate

Back-of-the-envelope bandwidth check for the current default full build:

- frame size = `768 * 32 * 3 = 73,728 bytes`
- at `188 Hz`, one full front-buffer scan consumes about `13.9 MB/s` of source pixel data if each pixel is fetched once per displayed frame
- a 16-bit SDR SDRAM running at `100 MHz` has a raw peak of about `200 MB/s`

Even after allowing for:

- activate/precharge overhead
- refresh
- arbitration
- imperfect burst efficiency
- cache refill margin

there is still ample bandwidth for:

- row-pair prefetch
- back-buffer writes
- explicit `COPY_FRAME`

So the gating factor is much more likely to be controller complexity and FPGA timing closure than raw memory bandwidth.

Recommended implementation posture:

- first working target: `clk_sdram = 100 MHz`
- fallback if timing is stubborn: `90 MHz`
- only explore `>100 MHz` after the architecture is proven and timing reports justify it

### Double Buffering

Decision:

- yes, `DOUBLE_BUFFER` should be treated as effectively mandatory for the SDRAM migration

Implication:

- single-buffer SDRAM support can be deprecated or at least postponed indefinitely
- this materially simplifies cache coherency and row-prefetch correctness

### Row Cache Format

Decision:

- still open, but the leading recommendation is:
  - compact packed pixels in SDRAM
  - padded scan-friendly format in BRAM row cache, if that keeps the downstream scan logic simpler

Reasoning:

- compact SDRAM storage reduces burst traffic and keeps frame layout intuitive
- scan-side padding is relatively cheap if confined to a small row-pair cache
- this avoids forcing BRAM-era packing constraints onto the off-chip memory image

If we want the most conservative migration path:

- keep the BRAM row cache shape close to today’s `pixel_split`/`framebuffer_fetch` expectations
- do format expansion during prefetch rather than during active scan

### Copy Frame

Decision:

- `COPY_FRAME` remains an explicit command

Recommended implementation detail:

- reimplement it as a bulk SDRAM copy operation
- do not preserve the current BRAM-style byte-lane `QA` semantics internally

That keeps the host-visible protocol stable while letting the backend use a storage-native implementation.

## Final Recommendation

The best plan is:

1. abstract the framebuffer backend first
2. add an SDRAM-backed linear frame store
3. keep scanout deterministic by introducing BRAM row-pair caches
4. bring up SDRAM first in `DOUBLE_BUFFER` mode
5. rewrite `COPY_FRAME` as a bulk SDRAM operation rather than preserving the current BRAM-style readback path

If we try to preserve the current `multimem` access pattern too literally, we will carry BRAM-era assumptions into a part of the design where burst behavior and arbitration matter far more. The migration should treat external SDRAM as a storage tier and BRAM as a timing/cache tier.
