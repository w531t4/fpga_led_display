# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb

from common import brightness_levels, sim_half_period_ns, start_clock, wait_cycles
from dut_types import BrightnessTimeoutDut


@cocotb.test()
async def brightness_timeout_smoke(dut: BrightnessTimeoutDut) -> None:
    await start_clock(dut.clk_in, sim_half_period_ns() * 2)

    dut.reset.value = 1
    dut.row_latch.value = 0
    dut.brightness_mask_active.value = 1 << (brightness_levels() - 1)

    await dut.clk_in.rising_edge
    dut.reset.value = 0

    for _ in range(brightness_levels() * 2):
        await dut.clk_in.rising_edge
        dut.brightness_mask_active.value = int(dut.brightness_mask_active.value) >> 1

    await dut.clk_in.rising_edge
    dut.brightness_mask_active.value = 1 << 1

    await dut.clk_in.rising_edge
    dut.row_latch.value = 1
    await dut.clk_in.rising_edge
    dut.row_latch.value = 0

    await wait_cycles(dut.clk_in, brightness_levels() * 8)
