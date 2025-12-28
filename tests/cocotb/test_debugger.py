# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import cocotb
from cocotb.triggers import Timer

from common import sim_half_period_ns, start_clock, wait_cycles
from dut_types import DebuggerDut


@cocotb.test()
async def debugger_smoke(dut: DebuggerDut) -> None:
    await start_clock(dut.clk_in, sim_half_period_ns() * 2)

    dut.reset.value = 0
    dut.debug_uart_rx_in.value = 0
    dut.data_in.value = 0b111100001010101000001101

    async def drive_rx_line() -> None:
        mystring = (
            b"0111223344556677881122334455667788112233445566778811223344556677"
            b"8811223344556677881122334455667788112233445566778811223344556677"
            b"-L Rrb"
        )
        value = int.from_bytes(mystring, "big")
        bit_count = len(mystring) * 8
        i = 0
        j = 0
        baud_period_cycles = 600 * 2
        while True:
            await wait_cycles(dut.clk_in, baud_period_cycles)
            if i == 10:
                dut.debug_uart_rx_in.value = 0
                j = 0 if j >= (bit_count - 8) else j + 8
                i = 0
            elif i in (9, 8):
                dut.debug_uart_rx_in.value = 1
                i += 1
            else:
                bit = (value >> (i + j)) & 1
                dut.debug_uart_rx_in.value = bit
                i += 1

    cocotb.start_soon(drive_rx_line())

    await Timer(2, unit="ns")
    dut.reset.value = 1
    await Timer(1, unit="ns")
    dut.reset.value = 0

    await Timer(1_000_000, unit="ns")
