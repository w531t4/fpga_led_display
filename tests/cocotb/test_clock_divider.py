# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import sim_half_period_ns, start_clock
from dut_types import ClockDividerDut


@cocotb.test()
async def clock_divider_smoke(dut: ClockDividerDut) -> None:
    await start_clock(dut.clk_in, sim_half_period_ns() * 2)

    dut.reset.value = 0

    async def periodic_reset() -> None:
        while True:
            await Timer(400, unit="ns")
            dut.reset.value = 0 if int(dut.reset.value) else 1

    cocotb.start_soon(periodic_reset())

    await Timer(2, unit="ns")
    dut.reset.value = 1
    await Timer(1, unit="ns")
    dut.reset.value = 0

    await Timer(10000, unit="ns")
