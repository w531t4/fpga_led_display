# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb

from common import sim_half_period_ns, start_clock, wait_cycles
from dut_types import ControlCmdReadpixelDut
from row4 import myled_row_pixel_local


@cocotb.test()
async def control_cmd_readpixel_smoke(dut: ControlCmdReadpixelDut) -> None:
    await start_clock(dut.clk, sim_half_period_ns() * 2)

    dut.reset.value = 1
    dut.data_in.value = 0
    dut.enable.value = 0

    await dut.clk.rising_edge
    await dut.clk.rising_edge
    dut.reset.value = 0

    slow_cycles = 32
    payload = myled_row_pixel_local()
    for _ in range(2):
        for byte in payload:
            await wait_cycles(dut.clk, slow_cycles)
            dut.data_in.value = int(byte)
            dut.enable.value = 1
            await dut.clk.rising_edge
            dut.enable.value = 0

    await wait_cycles(dut.clk, slow_cycles * 25)
