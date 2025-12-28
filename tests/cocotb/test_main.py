# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import os

import cocotb
from cocotb.triggers import Event, Timer

from common import (
    root_clock_hz,
    sim_half_period_ns,
    start_clock,
    wait_assert,
)
from dut_types import MainWrapperDut
from row4 import myled_row_bytes


@cocotb.test()
async def main_smoke(dut: MainWrapperDut) -> None:
    await start_clock(dut.clk, sim_half_period_ns() * 2)

    dut.reset.value = 1
    dut.spi_start.value = 0
    dut.spi_clk_en.value = 1
    dut.thebyte.value = 0

    tb_main_wait_cycles = int(
        os.environ.get("TB_MAIN_WAIT_CYCLES", max(1, root_clock_hz() // 100))
    )

    cmd_line_state_seq_done = Event()
    expected_states = [3, 0, 8, 0, 4, 0, 5, 0, 6, 0, 6, 0, 2, 0, 2, 0, 1, 0]
    cmd_line_state_step_cycles = int(root_clock_hz() * (500_000 / 1_000_000_000))

    async def assert_cmd_line_state_sequence() -> None:
        for expected in expected_states:
            await wait_assert(
                dut.clk,
                lambda exp=expected: int(dut.u_main.ctrl.cmd_line_state.value) == exp,
                cmd_line_state_step_cycles,
                f"cmd_line_state not {expected}",
            )
        cmd_line_state_seq_done.set()

    cocotb.start_soon(assert_cmd_line_state_sequence())

    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.global_reset.value) == 1,
        tb_main_wait_cycles,
        "global_reset never asserted",
    )
    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.global_reset.value) == 0,
        tb_main_wait_cycles,
        "global_reset never deasserted",
    )

    await dut.clk.rising_edge
    dut.reset.value = 0

    clk_root_high = False
    for _ in range(tb_main_wait_cycles):
        try:
            if int(dut.u_main.clk_root.value) == 1:
                clk_root_high = True
                break
        except ValueError:
            pass
        await dut.clk.value_change
    if not clk_root_high:
        raise AssertionError(
            "Timeout after %d cycles: clk_root did not go high" % tb_main_wait_cycles
        )

    payload = myled_row_bytes()

    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.ctrl.ready_for_data.value) == 1,
        tb_main_wait_cycles,
        "ctrl.ready_for_data not asserted",
    )
    await dut.clk.rising_edge
    dut.spi_start.value = 1

    async def feed_spi() -> None:
        idx = 0
        while True:
            await dut.spi_master_txdone.rising_edge
            if int(dut.u_main.ctrl.ready_for_data.value):
                if idx < len(payload):
                    dut.thebyte.value = payload[idx]
                    idx += 1
                elif idx == len(payload):
                    dut.spi_clk_en.value = 0
                    idx += 1

    cocotb.start_soon(feed_spi())

    delay_ps = int(
        round((len(payload) * 8 + 1000) * sim_half_period_ns() * 2 * 4 * 1000)
    )
    await Timer(delay_ps, unit="ps")

    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.row_address_active.value) == 0b0101,
        tb_main_wait_cycles,
        "row_address_active never reached 0101",
    )
    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.row_address_active.value) != 0b0101,
        tb_main_wait_cycles,
        "row_address_active never left 0101",
    )

    if hasattr(dut.u_main.ctrl, "frame_select_temp"):
        dut.u_main.ctrl.frame_select_temp.value = (
            0 if int(dut.u_main.ctrl.frame_select_temp.value) else 1
        )
    if hasattr(dut.u_main.ctrl, "frame_select"):
        dut.u_main.ctrl.frame_select.value = (
            0 if int(dut.u_main.ctrl.frame_select.value) else 1
        )

    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.row_address_active.value) == 0b0101,
        tb_main_wait_cycles,
        "row_address_active never reached 0101 after flip",
    )
    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.row_address_active.value) != 0b0101,
        tb_main_wait_cycles,
        "row_address_active never left 0101 after flip",
    )
    await wait_assert(
        dut.clk,
        lambda: int(dut.u_main.row_address_active.value) == 0b0101,
        tb_main_wait_cycles,
        "row_address_active never reached final 0101",
    )

    await cmd_line_state_seq_done.wait()
