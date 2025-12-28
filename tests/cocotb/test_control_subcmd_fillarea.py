# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb

from common import (
    bytes_per_pixel,
    pixel_height,
    pixel_width,
    sim_half_period_ns,
    start_clock,
    wait_assert,
    wait_cycles,
)
from dut_types import ControlSubcmdFillareaDut


@cocotb.test()
async def control_subcmd_fillarea_smoke(dut: ControlSubcmdFillareaDut) -> None:
    await start_clock(dut.clk, sim_half_period_ns() * 2)

    num_row_bits = len(dut.row)
    num_col_bits = len(dut.column)
    num_pixel_bits = len(dut.pixel)
    mem_num_bytes = 1 << (num_row_bits + num_col_bits + num_pixel_bits)

    def addr_from_fields(row: int, col: int, pixel: int) -> int:
        return (
            (row << (num_col_bits + num_pixel_bits)) | (col << num_pixel_bits) | pixel
        )

    valid_mask = [0] * mem_num_bytes
    remaining_valid_bytes = 0
    for idx in range(mem_num_bytes):
        pixel = idx & ((1 << num_pixel_bits) - 1)
        col = (idx >> num_pixel_bits) & ((1 << num_col_bits) - 1)
        row = idx >> (num_pixel_bits + num_col_bits)
        if pixel < bytes_per_pixel() and col < pixel_width() and row < pixel_height():
            valid_mask[idx] = 1
            remaining_valid_bytes += 1

    mem = [1] * mem_num_bytes

    async def monitor_writes() -> None:
        nonlocal remaining_valid_bytes
        while True:
            await dut.clk.rising_edge
            try:
                ram_we = int(dut.ram_write_enable.value)
                enable = int(dut.enable.value)
            except ValueError:
                continue
            if ram_we and enable:
                row = int(dut.row.value)
                col = int(dut.column.value)
                pixel = int(dut.pixel.value)
                if (
                    row >= pixel_height()
                    or col >= pixel_width()
                    or pixel >= bytes_per_pixel()
                ):
                    raise AssertionError(
                        f"out-of-range write: row={row} col={col} pixel={pixel}"
                    )
                if int(dut.data_out.value) != 0:
                    raise AssertionError(
                        f"expected clear data_out==0, got {int(dut.data_out.value)}"
                    )
                addr = addr_from_fields(row, col, pixel)
                if mem[addr] == 0:
                    raise AssertionError(
                        f"duplicate clear write at row={row} col={col} pixel={pixel}"
                    )
                mem[addr] = 0
                if valid_mask[addr]:
                    remaining_valid_bytes -= 1

    cocotb.start_soon(monitor_writes())

    dut.reset.value = 1
    dut.enable.value = 0
    dut.ack.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.width.value = pixel_width() & ((1 << len(dut.width)) - 1)
    dut.height.value = pixel_height() & ((1 << len(dut.height)) - 1)
    dut.color.value = 0

    await dut.clk.rising_edge
    dut.reset.value = 0

    await dut.clk.rising_edge
    dut.enable.value = 1

    row_advance_max_cycles = (pixel_width() * bytes_per_pixel()) + 2
    for r in range(pixel_height() - 1, -1, -1):
        await wait_assert(
            dut.clk,
            lambda r=r: int(dut.row.value) == r,
            row_advance_max_cycles,
            f"row did not reach {r}",
        )

    done_max_cycles = (pixel_width() * bytes_per_pixel()) + 1
    await wait_assert(
        dut.clk,
        lambda: int(dut.done.value) == 1,
        done_max_cycles,
        "done not asserted",
    )

    await dut.clk.rising_edge
    dut.ack.value = 1
    await dut.clk.rising_edge
    dut.ack.value = 0
    dut.enable.value = 0

    await wait_assert(
        dut.clk,
        lambda: int(dut.state.value) == 0,
        2,
        "FSM did not return to idle",
    )

    mem_clear_max_cycles = (pixel_width() * pixel_height() * bytes_per_pixel()) + 2
    await wait_assert(
        dut.clk,
        lambda: remaining_valid_bytes == 0,
        mem_clear_max_cycles,
        "memory not fully cleared",
    )

    if any(mem[idx] and valid_mask[idx] for idx in range(mem_num_bytes)):
        raise AssertionError(
            "expected all valid bytes cleared, but found non-zero data"
        )

    await wait_cycles(dut.clk, 5)
