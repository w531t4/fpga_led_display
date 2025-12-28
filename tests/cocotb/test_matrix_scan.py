# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import sim_half_period_ns, start_clock
from dut_types import MatrixScanDut


@cocotb.test()
async def matrix_scan_smoke(dut: MatrixScanDut) -> None:
    period_ns = sim_half_period_ns() * 2 * 2
    await start_clock(dut.clk_in, period_ns)

    dut.reset.value = 0

    await Timer(2, unit="ns")
    dut.reset.value = 1
    await Timer(1, unit="ns")
    dut.reset.value = 0

    await Timer(10_000_000, unit="ns")
