<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# Framebuffer Current Semantics

This note captures the current meanings of framebuffer-related terms in the BRAM-backed design.

Its purpose is to preserve the existing behavioral contract while the storage backend is refactored.

## Front/Back Buffer Overview

Front/Back Buffers represent a set of two buffers. The labels of front/back are mutually exclusive to the two buffers. A swap happens when the back-buffer is finished being written to in order to display the next frame to a user.

## Current BRAM Contract

This section captures the BRAM-backed behavior that the rest of the design currently depends on.

### Command-Side Write Contract

- Command-side writes are byte-granular.
- One write targets one lane selected by `types::mem_write_addr_t`.
- `types::mem_write_addr_t` is composed of:
  - `subpanel`
  - `row`
  - `col`
  - `pixel`
- `types::mem_write_data_t` is one byte wide.
- In double-buffer mode, controller writes target the back buffer.

Relevant references:

- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:112)
- [src/multimem.sv](/workspaces/fpga_led_display/src/multimem.sv:4)
- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:79)

### Scan-Side Read Contract

- Scan-side reads use `types::mem_read_addr_t`, which is composed of:
  - `row`
  - `col`
- The BRAM fabric returns `types::mem_read_data_t`.
- That read result contains packed data for all subpanels and byte lanes at the requested row/column body address.
- `framebuffer_fetch.sv` mirrors the column before issuing the read:
  - `column_address_mirrored = PIXEL_WIDTH - 1 - column_address`
- `framebuffer_fetch.sv` then extracts `ram_data_in.subpanel[subpanel_idx].field`, preserving subpanel ordering from memory.
- The current delay between issuing the BRAM-side read and sampling `ram_data_in` inside `framebuffer_fetch.sv` exists to make the BRAM-backed implementation work correctly.
- That delay is a BRAM implementation detail, not the long-term abstraction contract that a future SDRAM-backed store must preserve verbatim.
- The real contract is correct scanout behavior, not preservation of the exact BRAM read latency.
- The real user-visible contract is that the image appears in the correct left-to-right order.
- The current mirrored-column read is one way the BRAM implementation achieves that ordering; the exact place where reversal/mirroring happens is not the long-term contract.

Relevant references:

- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:124)
- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:137)
- [src/multimem.sv](/workspaces/fpga_led_display/src/multimem.sv:6)
- [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:38)
- [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:56)

### Copy-Engine Ownership Contract

- When copy is inactive, the controller owns the write-side BRAM path.
- When copy is active, the copy engine takes over the Port-A-side access pattern.
- Once `COPY_FRAME` begins, it must not release control of `control_module` until the copy is fully complete.
- The command stream must not advance to the next command until the back buffer fully reflects the copied front buffer.
- During copy:
  - the copy engine reads from the front buffer
  - the copy engine writes to the back buffer
- Scan-side Port-B reads continue to come from the front buffer.
- The current copy implementation depends on the BRAM `QA` readback latency and aligns writes to the delayed read data.
- The current `READ_LATENCY = 5` value is an implementation-alignment detail of the BRAM-backed design, not the real long-term contract.
- The more important contract is performance:
  - `COPY_FRAME` must remain substantially faster than sending a full replacement frame from upstream
  - `COPY_FRAME` is expected to remain an internal bulk-copy operation rather than being replaced by host-side rewrite traffic

Relevant references:

- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:62)
- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:65)
- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:84)
- [src/control_module.sv](/workspaces/fpga_led_display/src/control_module.sv:378)
- [src/control_module.sv](/workspaces/fpga_led_display/src/control_module.sv:380)
- [src/control_module.sv](/workspaces/fpga_led_display/src/control_module.sv:412)
- [src/control_module.sv](/workspaces/fpga_led_display/src/control_module.sv:536)
- [src/control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/control_cmd_copyframe.sv:18)

## Terms

### `front buffer`

Precise wording:

- The framebuffer currently being scanned out to the display.
- In the current design, scan-side reads always come from the front buffer.

User wording:

- Describes the buffer currently being displayed to the world

Relevant references:

- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:83)
- [src/testbenches/tb_framebuffer_fabric.sv](/workspaces/fpga_led_display/src/testbenches/tb_framebuffer_fabric.sv:130)

### `back buffer`

Precise wording:

- The framebuffer currently receiving writes for the next image.
- In the current design, command-side writes target the back buffer.

User wording:

- Describes the buffer meant to receive the next picture to display to the world

Relevant references:

- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:79)
- [src/testbenches/tb_framebuffer_fabric.sv](/workspaces/fpga_led_display/src/testbenches/tb_framebuffer_fabric.sv:118)

### `frame_select`

Precise wording:

- Selects which physical framebuffer instance is acting as front vs back.
- It does not just mean "reference either front or back" abstractly; it controls the concrete mapping between frame RAM instances and the front/back roles.
- Current mapping in [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:84):
  - `frame_select=0` means `frame0=front`, `frame1=back`
  - `frame_select=1` means `frame0=back`, `frame1=front`
- The long-term contract is role-based:
  - there is always one front buffer and one back buffer
  - toggling swaps those roles
- The exact physical mapping of `frame0` vs `frame1` is a current implementation detail rather than the more important long-term contract.
- The current implementation uses `frame_select` plus physical frame instances rather than symbolic front/back labels.

User wording:

- Means to reference either the front or back buffer

Relevant references:

- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:84)
- [src/control_module.sv](/workspaces/fpga_led_display/src/control_module.sv:534)

### copy-engine read/write ordering

Precise wording:

- The copy engine copies the current front buffer into the current back buffer.
- It walks the frame in row-major order, while `pixel` counts down from `BYTES_PER_PIXEL-1` to `0` for each pixel.
- Reads are issued first from the front buffer, then after the BRAM `QA` latency, the returned bytes are written into the back buffer.
- This behavior is implemented in [src/control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/control_cmd_copyframe.sv:18).

User wording:

- The Copy-engine's responsibility is to make the back_buffer be equivalent to the front buffer. We can safely read from the front_buffer at any time, so reads here are safe. This capability required so that our upstream data source for frames can send us delta frames.

Relevant references:

- [src/control_cmd_copyframe.sv](/workspaces/fpga_led_display/src/control_cmd_copyframe.sv:18)
- [src/framebuffer_fabric.sv](/workspaces/fpga_led_display/src/framebuffer_fabric.sv:65)

### row fetch ordering

Precise wording:

- This refers to the order the scan path reads pixel columns from framebuffer memory for a given display row.
- In the current design, `framebuffer_fetch` requests memory using a mirrored column address:
  - `column_address_mirrored = PIXEL_WIDTH - 1 - column_address`
- That means scan logic advances left-to-right logically, but memory is addressed right-to-left so the fetched packed data appears in the intended visual order.
- In other words, row fetch ordering covers:
  - which row is being fetched
  - which column sequence within that row is used
  - whether memory order matches or is mirrored relative to display order
- The long-term contract is that logical display coordinates appear in the correct left-to-right order to the user.
- The exact place where address mirroring occurs can change as long as that visible ordering remains correct.

User wording:

- We only care that the image appears in the correct left-to-right order.

Relevant references:

- [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:24)
- [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:38)

### per-pixel byte ordering

Precise wording:

- This is the order of bytes within one pixel when written to and read from memory.
- For `RGB24`, a pixel is logically `red, green, blue`, but the stored and traversed byte order depends on how `color.bytes[...]`, `pixel`, and the packed structs are used.
- In the current codebase, byte-lane traversal for writes commonly counts `pixel` downward, so this should be documented explicitly rather than assumed.
- The current packing also reflects the format in which upstream libraries send data into this design.
- Future internal storage may change, but compatibility with the upstream data format should be preserved.

User wording:

- A pixel (for example, rgb24) consists of three bytes (red, green, blue). This is talking about the order in which those are stored/read from memory.

Relevant references:

- [src/control_subcmd_fillarea.sv](/workspaces/fpga_led_display/src/control_subcmd_fillarea.sv:70)
- [src/framebuffer_fetch.sv](/workspaces/fpga_led_display/src/framebuffer_fetch.sv:24)
- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:88)
