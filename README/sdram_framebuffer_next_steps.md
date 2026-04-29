<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# SDRAM Framebuffer Next Steps

This is the execution checklist for [sdram_framebuffer_migration_plan.md](/workspaces/fpga_led_display/README/sdram_framebuffer_migration_plan.md:1).

The intent here is different from the plan document:

- the plan explains the architecture and tradeoffs
- this file itemizes the concrete implementation work in the order we should do it

## Guiding Rules

- keep `DOUBLE_BUFFER` as the primary target
- preserve existing host-visible command semantics
- keep the active scan path deterministic and BRAM-backed
- do not couple scan timing directly to SDRAM response timing
- keep the BRAM backend alive until the SDRAM backend is proven
- keep the code human-readable
- avoid duplication and magic numbers
- keep the design testable in isolation as modules are refactored

## Immediate Next Steps

### 1. Lock Down Current Framebuffer Behavior (Completed)

- review and document the exact behavior of:
  - [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:1)
  - [src/multimem.sv](/workspaces/fpga_led_display/src/multimem.sv:1)
  - [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:1)
  - [src/control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/control_cmd_copyframe.sv:1)
- write down the current meanings of:
  - front buffer
  - back buffer
  - `frame_select`
  - copy-engine read/write ordering
  - row fetch ordering
  - per-pixel byte ordering
- explicitly record any assumptions that are currently only implied by tests or comments

Resolved step-1 decisions:

- `COPY_FRAME` must not release control of `control_module` until the copy is fully complete.
- `COPY_FRAME` must remain substantially faster than sending a full replacement frame from upstream.
- The current BRAM `QA` latency is an implementation detail, not the long-term contract.
- We only care that the image appears in the correct left-to-right order.
- The exact place where column mirroring/reversal occurs is an implementation detail.
- We only care that there is always one front buffer and one back buffer, and toggling swaps those roles.
- The exact physical mapping of `frame0` versus `frame1` is a current implementation detail.
- The current packing reflects how upstream libraries send data into this design.
- Future storage internals may change, but upstream data-format compatibility must be preserved.

Definition of done:

- we have a short compatibility note that describes the current BRAM store behavior well enough to re-implement it behind a new interface
- status: completed via [framebuffer_current_semantics.md](/workspaces/fpga_led_display/README/framebuffer_current_semantics.md:1)

Reference note:

- capture these semantics in [framebuffer_current_semantics.md](/workspaces/fpga_led_display/README/framebuffer_current_semantics.md:1)
- current BRAM abstraction contract is captured in the `Current BRAM Contract` section of [framebuffer_current_semantics.md](/workspaces/fpga_led_display/README/framebuffer_current_semantics.md:1)

### 2. Strengthen Baseline Tests Before Refactoring (Completed)

- review these testbenches for coverage gaps:
  - [src/testbenches/tb_framebuffer_fabric.sv](/workspaces/fpga_led_display/src/testbenches/tb_framebuffer_fabric.sv:1)
  - [src/testbenches/tb_control_module.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_module.sv:1)
  - [src/testbenches/tb_control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_cmd_copyframe.sv:1)
  - [src/testbenches/tb_main.sv](/workspaces/fpga_led_display/src/testbenches/tb_main.sv:1)
- add or tighten checks for:
  - frame toggle behavior
  - `COPY_FRAME` full-frame correctness
  - `READFRAME` byte ordering
  - `READRECT` ordering and bounds behavior
  - row fetch ordering as seen by scan-side logic

Definition of done:

- current BRAM-backed design has regression tests that will tell us when the migration breaks behavior

Coverage note:

- frame toggle behavior is covered by [src/testbenches/tb_control_module_copyframe_readframe.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_module_copyframe_readframe.sv:1)
- `COPY_FRAME` full-frame correctness is covered by [src/testbenches/tb_control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_cmd_copyframe.sv:1)
- `READFRAME` byte ordering is covered by [src/testbenches/tb_control_cmd_readframe.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_cmd_readframe.sv:1)
- `READRECT` ordering and bounds behavior is covered by [src/testbenches/tb_control_module_readrect.sv](/workspaces/fpga_led_display/src/testbenches/tb_control_module_readrect.sv:1)
- row fetch ordering and subpanel extraction are covered by [src/testbenches/tb_framebuffer_fetch.sv](/workspaces/fpga_led_display/src/testbenches/tb_framebuffer_fetch.sv:1)
- status: completed

### 3. Add Compile-Time Selection For Storage Backend

- introduce a build flag for store backend selection
- keep BRAM as the default backend until SDRAM is proven
- choose names that make intent obvious, for example:
  - `USE_SDRAM_FRAMEBUFFER`
  - or `FRAMEBUFFER_BACKEND_SDRAM`

Definition of done:

- the design can still build exactly as it does today with the default configuration
- we have a clean switch for opting into the new backend later

## Backend Abstraction Work

### 4. Introduce `fb_store_if.sv`

- create a new interface file in `src/interfaces/`
- define the minimum storage operations required by the design:
  - command-side byte write
  - scan-side row-pair prefetch read request
  - copyframe request path
  - frame base / front-back selection
  - status or ready signaling where needed

Recommended constraint:

- do not leak `multimem`-specific lane details into this interface

Definition of done:

- the store interface expresses what the rest of the design needs from storage, not how BRAM happens to implement it today

### 5. Wrap The Existing BRAM Path As `fb_store_bram.sv`

- create a BRAM backend module that internally reuses:
  - `framebuffer_fabric.sv`
  - `multimem.sv`
  - `mem_lane.sv`
- adapt that module to the new `fb_store_if`
- keep behavior unchanged

Definition of done:

- `main.sv` can instantiate `fb_store_bram.sv` through the new interface
- existing tests still pass with the BRAM backend selected

### 6. Refactor `main.sv` To Use The Store Abstraction

- remove direct top-level dependence on the current BRAM fabric wiring
- instantiate the storage backend behind one selection point
- keep the scan and command sides functionally identical in BRAM mode

Definition of done:

- the code path for choosing a storage backend is centralized and easy to reason about

## SDRAM Controller Work

### 7. Create A Standalone SDRAM Controller Subsystem

- add new modules for:
  - SDRAM init sequence
  - refresh scheduler
  - read/write burst engine
  - top-level command/arbitration wrapper
- target a `100 MHz` controller clock first
- preserve a path to fall back to `90 MHz` if timing closure requires it

Definition of done:

- the SDRAM controller can initialize memory and perform isolated burst reads/writes in simulation

### 8. Add SDRAM-Focused Testbenches

- create dedicated controller tests under `src/testbenches/`
- cover:
  - initialization completion
  - refresh activity
  - burst write then burst readback
  - address wrap behavior
  - back-to-back transactions
  - idle periods followed by resumed access

Definition of done:

- SDRAM controller correctness can be verified independently of the display pipeline

### 9. Decide And Document The Internal SDRAM Address Map

- formalize frame memory layout:
  - front frame base
  - back frame base
  - optional scratch/copy area if needed
- formalize pixel addressing:
  - linear row-major
  - compact packed pixels in SDRAM

Recommended formula:

- `frame_offset = ((row * PIXEL_WIDTH) + col) * BYTES_PER_PIXEL`

Definition of done:

- every module that touches external frame storage uses one documented address model

## SDRAM Store Backend Work

### 10. Implement `fb_store_sdram.sv`

- create a storage backend module that translates `fb_store_if` traffic into SDRAM controller commands
- support:
  - byte writes into the back buffer
  - row-pair burst reads for scan prefetch
  - explicit bulk `COPY_FRAME`
  - front/back frame base selection

Definition of done:

- command-side frame storage operations can run entirely through SDRAM in simulation

### 11. Keep `COPY_FRAME` Explicit, But Reimplement It Natively

- keep the command protocol unchanged
- move implementation away from the current `QA`-style per-byte BRAM copy assumptions
- implement `COPY_FRAME` as sequential SDRAM read and write bursts

Definition of done:

- `COPY_FRAME` remains host-visible and correct, but is backend-native under SDRAM

## Scan Cache Work

### 12. Create `scan_row_cache.sv`

- store one active row pair and one prefetched row pair in BRAM
- choose a cache representation that favors simple scan timing
- likely keep the cache format closer to current scan-side expectations than to the compact SDRAM format

Definition of done:

- scan-side logic can fetch pixel data from BRAM cache with deterministic latency and without waiting on SDRAM

### 13. Create `scan_prefetch.sv`

- watch row transitions from `matrix_scan.sv`
- request row-pair fetches from `fb_store_sdram.sv`
- fill the inactive row cache before the next row becomes active
- swap caches at row transitions

Definition of done:

- row-pair prefetch runs one row ahead and keeps the active scan path fed

### 14. Define Underflow Behavior Explicitly

- choose one failure behavior for missed prefetch deadlines:
  - blank the row
  - or repeat the last valid row
- surface the condition in debug/status signals

Recommended choice:

- blank on underflow and latch a sticky debug flag

Definition of done:

- scan failure behavior is deterministic and debuggable

## Double-Buffer Integration

### 15. Make Front/Back Ownership Explicit In SDRAM Mode

- command writes go to back frame only
- scan prefetch reads front frame only
- `TOGGLE_FRAME` swaps active frame bases
- row caches are invalidated on frame toggle

Definition of done:

- the double-buffer policy is enforced structurally, not informally

### 16. Integrate Frame Toggle With Cache Invalidation

- on frame toggle:
  - clear cache-valid bits
  - request row pair 0 of the new front frame
  - suppress stale cached display data

Definition of done:

- toggling frames never displays data from the wrong frame due to stale cache contents

## Top-Level Integration

### 17. Replace Direct Use Of `framebuffer_fetch.sv`

- decide whether to:
  - retire `framebuffer_fetch.sv`
  - or keep a trimmed scan-side helper that reads from `scan_row_cache.sv`
- minimize churn downstream of `pixel_split.sv`

Definition of done:

- scan-side data delivery is cache-based, not direct-from-frame-store based

### 18. Update `main.sv` Wiring For SDRAM Pins

- add the SDRAM signals to the top level if not already present in the active build
- wire them consistently with the existing LPF pin names in:
  - [src/constraints/ulx3s_v316.lpf](/workspaces/fpga_led_display/src/constraints/ulx3s_v316.lpf:254)
- avoid changing unrelated board IO mappings

Definition of done:

- the top-level design exposes the SDRAM interface needed by the controller

### 19. Add Debug Observability

- expose enough status to diagnose SDRAM bring-up and cache behavior:
  - init complete
  - refresh active
  - prefetch in progress
  - cache valid state
  - underflow flag
  - copyframe busy

Definition of done:

- failures in hardware can be distinguished between controller, cache, and command-path issues

## Validation Steps

### 20. Verify BRAM Backend Still Passes

- run lint
- run the existing simulation suite
- confirm the backend abstraction did not change behavior in BRAM mode

Definition of done:

- BRAM remains the known-good baseline

### 21. Verify SDRAM Controller In Isolation

- run dedicated SDRAM tests only
- confirm clean init, read/write, refresh, and burst behavior

Definition of done:

- SDRAM backend work is not blocked on scanout integration

### 22. Verify SDRAM Store Without Live Scan

- test command-side writes and reads against SDRAM
- test `COPY_FRAME`
- test frame toggle bookkeeping

Definition of done:

- storage semantics are correct before the row cache is introduced

### 23. Verify Row Cache In Simulation

- test row 0 prefetch on startup
- test row N to row N+1 handoff
- test cache invalidation on frame toggle
- test underflow signaling

Definition of done:

- scan-side cache behavior is correct under controlled conditions

### 24. Verify Full-System SDRAM Display Path

- run `tb_main.sv` or a dedicated top-level SDRAM testbench in SDRAM mode
- verify:
  - static frame display
  - repeated frame toggles
  - continuous back-buffer updates
  - `COPY_FRAME`

Definition of done:

- the full integrated architecture works in simulation

### 25. Perform Hardware Bring-Up In This Order

1. prove SDRAM init on board
2. prove march/readback over a simple debug path
3. prove one static frame with cached scanout
4. prove frame toggle with cache invalidation
5. prove sustained streaming writes to back buffer
6. prove `COPY_FRAME`

Definition of done:

- the board demonstrates stable SDRAM-backed display operation in its intended mode

## Likely File Additions

- `src/interfaces/fb_store_if.sv`
- `src/fb_store_bram.sv`
- `src/fb_store_sdram.sv`
- `src/scan_prefetch.sv`
- `src/scan_row_cache.sv`
- `src/sdram_controller.sv`
- `src/sdram_init.sv`
- `src/sdram_refresh.sv`
- `src/testbenches/tb_sdram_controller.sv`
- `src/testbenches/tb_fb_store_sdram.sv`
- `src/testbenches/tb_scan_row_cache.sv`

## Likely Existing Files To Modify

- [src/main.sv](/workspaces/fpga_led_display/src/main.sv:1)
- [src/packages/params.sv](/workspaces/fpga_led_display/src/packages/params.sv:1)
- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:1)
- [src/interfaces/mem_copy_if.sv](/workspaces/fpga_led_display/src/interfaces/mem_copy_if.sv:1)
- [Makefile](/workspaces/fpga_led_display/Makefile:1)
- [src/testbenches/tb_main.sv](/workspaces/fpga_led_display/src/testbenches/tb_main.sv:1)

## Suggested First Implementation Slice

If we want the safest first chunk of work, do only this:

1. add `fb_store_if.sv`
2. wrap the current BRAM design as `fb_store_bram.sv`
3. refactor `main.sv` to use the backend abstraction
4. keep all tests green

That gives us a stable seam for the rest of the migration without mixing in SDRAM risk too early.
