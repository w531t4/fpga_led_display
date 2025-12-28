# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import sim_half_period_ns, start_clock
from dut_types import FfSyncDut


@cocotb.test()
async def ff_sync_smoke(dut: FfSyncDut) -> None:
    await start_clock(dut.clk, sim_half_period_ns() * 2)

    dut.reset.value = 0
    signal_val = 0
    dut.signal.value = signal_val

    async def pulse_reset() -> None:
        await Timer(2, unit="ns")
        dut.reset.value = 1
        await Timer(1, unit="ns")
        dut.reset.value = 0

    cocotb.start_soon(pulse_reset())

    half_ps = int(round(sim_half_period_ns() * 1000))
    signal_val ^= 1
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    signal_val ^= 1
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    signal_val ^= 1
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    signal_val ^= 1
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    signal_val ^= 1
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(half_ps, unit="ps")
    dut.signal.value = signal_val
    await Timer(10, unit="ns")
