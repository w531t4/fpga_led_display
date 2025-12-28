# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import start_clock
from dut_types import Fm6126InitDut


@cocotb.test()
async def fm6126init_smoke(dut: Fm6126InitDut) -> None:
    await start_clock(dut.clk_in, 10)

    dut.reset.value = 0

    await Timer(5, unit="ns")
    dut.reset.value = 1
    await Timer(1, unit="ns")
    dut.reset.value = 0

    await Timer(100_000, unit="ns")
