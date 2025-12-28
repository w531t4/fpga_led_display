# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb

from common import sim_half_period_ns, start_clock, wait_assert, wait_cycles
from dut_types import ControlCmdWatchdogDut


@cocotb.test()
async def control_cmd_watchdog_smoke(dut: ControlCmdWatchdogDut) -> None:
    await start_clock(dut.clk, sim_half_period_ns() * 2)

    dut.reset.value = 1
    dut.data_in.value = 0
    dut.enable.value = 0

    await dut.clk.rising_edge
    dut.reset.value = 0

    signature = 0xDEADBEEFFEEBDAED
    payload = signature.to_bytes(8, "big")
    slow_cycles = 16

    for byte in payload:
        await wait_cycles(dut.clk, slow_cycles)
        dut.data_in.value = int(byte)
        dut.enable.value = 1
        await dut.clk.rising_edge
        dut.enable.value = 0

    await wait_assert(
        dut.clk,
        lambda: int(dut.sys_reset.value) == 1,
        128 * 4,
        "sys_reset not asserted",
    )

    await wait_cycles(dut.clk, slow_cycles * 25)
