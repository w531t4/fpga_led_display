# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import First, Timer

from dut_types import SpiDut


@cocotb.test()
async def spi_smoke(dut: SpiDut) -> None:
    dut.rstb.value = 0
    dut.clk.value = 0
    dut.mlb.value = 0
    dut.start.value = 0
    dut.m_tdat.value = 0
    dut.cdiv.value = 0
    dut.ten.value = 0
    dut.s_tdata.value = 0

    async def clock() -> None:
        period = 50
        duty = 0.5
        while True:
            dut.clk.value = 0
            await Timer(period * (1 - duty), unit="ns")
            dut.clk.value = 1
            await Timer(period * duty, unit="ns")

    async def mirror_mrdata() -> None:
        while True:
            await First(dut.mrdata.value_change, dut.rstb.value_change)
            await Timer(10, unit="ns")
            if int(dut.rstb.value) == 0:
                dut.s_tdata.value = 0xAA
            else:
                try:
                    mrdata = int(dut.mrdata.value)
                except ValueError:
                    continue
                dut.s_tdata.value = mrdata

    cocotb.start_soon(clock())
    cocotb.start_soon(mirror_mrdata())

    await Timer(10, unit="ns")
    dut.rstb.value = 0
    await Timer(100, unit="ns")
    dut.rstb.value = 1
    dut.start.value = 0
    dut.m_tdat.value = 0b01111100
    dut.cdiv.value = 0

    await Timer(100, unit="ns")
    dut.start.value = 1
    dut.ten.value = 1
    await Timer(100, unit="ns")
    dut.start.value = 0

    await Timer(1800, unit="ns")
    dut.mlb.value = 1
    dut.cdiv.value = 1
    dut.m_tdat.value = 0b00011100
    await Timer(100, unit="ns")
    dut.start.value = 1
    await Timer(100, unit="ns")
    dut.start.value = 0
    await Timer(2202, unit="ns")

    await Timer(100, unit="ns")
    dut.start.value = 1
    await Timer(100, unit="ns")
    dut.start.value = 0
    await Timer(2000, unit="ns")

    dut.m_tdat.value = int(dut.m_tdat.value) ^ 0xFF
    await Timer(100, unit="ns")
    dut.start.value = 1
    await Timer(100, unit="ns")
    dut.start.value = 0
    await Timer(2000, unit="ns")
