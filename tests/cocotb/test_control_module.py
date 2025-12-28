# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb

from common import sim_half_period_ns, start_clock, wait_cycles
from dut_types import ControlModuleDut


async def _drive_bytes(dut: ControlModuleDut, payload: bytes) -> None:
    for byte in payload:
        while True:
            await dut.clk_in.rising_edge
            if int(dut.ready_for_data.value):
                break
        dut.data_rx.value = int(byte)
        dut.data_ready_n.value = 0
        await dut.clk_in.rising_edge
        dut.data_ready_n.value = 1


@cocotb.test()
async def control_module_smoke(dut: ControlModuleDut) -> None:
    await start_clock(dut.clk_in, sim_half_period_ns() * 2)

    dut.reset.value = 0
    dut.data_rx.value = 0
    dut.data_ready_n.value = 1

    await dut.clk_in.rising_edge
    dut.reset.value = 1
    await dut.clk_in.rising_edge
    dut.reset.value = 0

    payload = b"brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110"
    await _drive_bytes(dut, payload)

    await wait_cycles(dut.clk_in, 300)
