<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# SDRAM Address Map

This note defines the one internal SDRAM address model that framebuffer-storage code should use.

The goal is to keep future modules aligned on:

- where each frame begins
- how bytes within a frame are addressed
- how linear byte addresses map onto SDRAM `bank/row/col`

## Guiding Rules

- store framebuffer pixels in compact packed-pixel order
- keep logical addressing row-major in host order
- keep frame bases burst-aligned
- let physical SDRAM row crossings be an implementation detail of the mapping
- keep one optional frame-sized scratch region reserved after the active frame regions

## Frame Layout

Physical frame regions:

- frame 0 base: `params::SDRAM_FRAME0_BASE_BYTES`
- frame 1 base: `params::SDRAM_FRAME1_BASE_BYTES`
- scratch base: `params::SDRAM_SCRATCH_BASE_BYTES`

Derived sizing:

- frame payload bytes: `params::SDRAM_FRAME_BYTES`
- frame stride bytes: `params::SDRAM_FRAME_STRIDE_BYTES`
- scratch bytes reserved: `params::SDRAM_SCRATCH_BYTES`
- total reserved bytes: `params::SDRAM_REQUIRED_BYTES`

The stride is rounded up to `params::SDRAM_BURST_BYTES` so every frame base stays burst-aligned even if a future geometry is not naturally aligned already.

## Logical Pixel Addressing

Logical frame storage uses row-major packed bytes:

- `frame_offset = ((row * PIXEL_WIDTH) + col) * BYTES_PER_PIXEL + pixel`

Where:

- `row` is the full logical display row, not the current BRAM subpanel row
- `col` is the logical display column
- `pixel` is the byte index within the compact pixel payload

For the current default `RGB24` build:

- pixel byte order remains the existing upstream-visible order
- one logical pixel occupies `3` contiguous bytes in SDRAM

## Linear Byte Address To SDRAM Word Address

Framebuffer code should treat SDRAM as a linear byte-addressed space first.

The shared helpers in [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:105) then map that byte address into:

- word index
- byte lane within the SDRAM data word
- physical `bank/row/col`

Current mapping:

1. `word_index = byte_addr / SDRAM_WORD_BYTES`
2. `byte_lane = byte_addr % SDRAM_WORD_BYTES`
3. low `SDRAM_COLUMN_BITS` of `word_index` select `col`
4. next `SDRAM_BANK_BITS` select `bank`
5. remaining high bits select `row`

This means the physical address decomposition is:

- `word_index = {row, bank, col}`

with `col` as the least-significant field.

That ordering keeps short sequential bursts contiguous in the SDRAM column field first, then advances bank, then row as the linear byte address grows.

## Front/Back Ownership

In double-buffer mode:

- the scan side reads the front frame base
- command writes target the back frame base
- `TOGGLE_FRAME` swaps which physical frame base is front versus back

The physical frame regions themselves stay fixed:

- frame 0 always starts at `SDRAM_FRAME0_BASE_BYTES`
- frame 1 always starts at `SDRAM_FRAME1_BASE_BYTES`

Only the logical front/back role changes.

## Shared Code References

The shared constants and helpers for this mapping live in:

- [src/packages/params.sv](/workspaces/fpga_led_display/src/packages/params.sv:120)
- [src/packages/types.sv](/workspaces/fpga_led_display/src/packages/types.sv:105)

New SDRAM-backed modules should use those definitions instead of re-deriving their own address math.
