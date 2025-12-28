# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import sim_half_period_ns, start_clock
from dut_types import MultimemDut


@cocotb.test()
async def multimem_smoke(dut: MultimemDut) -> None:
    await start_clock(dut.ClockA, sim_half_period_ns() * 2)
    await start_clock(dut.ClockB, sim_half_period_ns() * 2)

    dut.AddressA.value = 0
    dut.AddressB.value = 0
    dut.DataInA.value = 0
    dut.DataInB.value = 0
    dut.ClockEnA.value = 0
    dut.ClockEnB.value = 0
    dut.WrA.value = 0
    dut.WrB.value = 0
    dut.ResetA.value = 0
    dut.ResetB.value = 0

    await dut.ClockA.rising_edge
    dut.ResetA.value = int(dut.ResetA.value) ^ 1
    dut.ResetB.value = int(dut.ResetB.value) ^ 1

    await dut.ClockA.rising_edge
    dut.ResetA.value = int(dut.ResetA.value) ^ 1
    dut.ResetB.value = int(dut.ResetB.value) ^ 1

    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFF, ord("A"))
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_end(dut)

    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFE, ord("B"))
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_end(dut)

    await dut.ClockA.falling_edge
    dut.ClockEnB.value = 1
    await _do_read_start(dut, 0x7FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.rising_edge
    await _do_read_end(dut)

    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFF, ord("C"))
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_end(dut)

    await dut.ClockA.falling_edge
    await _do_read_start(dut, 0x7FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_read_end(dut)

    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFF, ord("D"))
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFE, ord("E"))
    await _do_read_start(dut, 0x7FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0xFFE, ord("F"))
    await _do_read_start(dut, 0x7FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_read_start(dut, 0x7FF)
    await _do_write_end(dut)
    await dut.ClockA.rising_edge
    await _do_read_end(dut)

    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0x7FF, ord("Z"))
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0x7FE, ord("Y"))
    await _do_read_start(dut, 0x3FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_write_start(dut, 0x7FE, ord("R"))
    await _do_read_start(dut, 0x3FF)
    await dut.ClockA.rising_edge
    await dut.ClockA.falling_edge
    await _do_read_start(dut, 0x3FF)
    await _do_write_end(dut)
    await dut.ClockA.rising_edge
    await _do_read_end(dut)

    await Timer(400, unit="ns")


async def _do_write_start(dut: MultimemDut, address: int, data: int) -> None:
    dut.AddressA.value = address
    dut.DataInA.value = data
    dut.ClockEnA.value = 1
    dut.WrA.value = 1


async def _do_write_end(dut: MultimemDut) -> None:
    dut.ClockEnA.value = 0
    dut.WrA.value = 0


async def _do_read_start(dut: MultimemDut, address: int) -> None:
    dut.ClockEnB.value = 1
    dut.AddressB.value = address


async def _do_read_end(dut: MultimemDut) -> None:
    dut.ClockEnB.value = 0
