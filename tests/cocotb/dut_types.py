# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

from typing import Any, Protocol


class ScalarSignal(Protocol):
    value: Any
    rising_edge: Any
    falling_edge: Any
    value_change: Any


class ValueSignal(Protocol):
    value: Any
    value_change: Any


class BrightnessTimeoutDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal
    row_latch: ValueSignal
    brightness_mask_active: ValueSignal


class ClockDividerDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal


class ControlCmdReadpixelDut(Protocol):
    clk: ScalarSignal
    reset: ValueSignal
    data_in: ValueSignal
    enable: ValueSignal


class ControlCmdReadrowDut(Protocol):
    clk: ScalarSignal
    reset: ValueSignal
    data_in: ValueSignal
    enable: ValueSignal


class ControlCmdWatchdogDut(Protocol):
    clk: ScalarSignal
    reset: ValueSignal
    data_in: ValueSignal
    enable: ValueSignal
    sys_reset: ValueSignal


class ControlModuleDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal
    data_rx: ValueSignal
    data_ready_n: ValueSignal
    ready_for_data: ValueSignal


class ControlSubcmdFillareaDut(Protocol):
    clk: ScalarSignal
    row: ValueSignal
    column: ValueSignal
    pixel: ValueSignal
    ram_write_enable: ValueSignal
    enable: ValueSignal
    data_out: ValueSignal
    reset: ValueSignal
    ack: ValueSignal
    x1: ValueSignal
    y1: ValueSignal
    width: ValueSignal
    height: ValueSignal
    color: ValueSignal
    done: ValueSignal
    state: ValueSignal


class DebuggerDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal
    debug_uart_rx_in: ValueSignal
    data_in: ValueSignal


class FfSyncDut(Protocol):
    clk: ScalarSignal
    reset: ValueSignal
    signal: ValueSignal


class Fm6126InitDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal


class MatrixScanDut(Protocol):
    clk_in: ScalarSignal
    reset: ValueSignal


class MultimemDut(Protocol):
    ClockA: ScalarSignal
    ClockB: ScalarSignal
    AddressA: ValueSignal
    AddressB: ValueSignal
    DataInA: ValueSignal
    DataInB: ValueSignal
    ClockEnA: ValueSignal
    ClockEnB: ValueSignal
    WrA: ValueSignal
    WrB: ValueSignal
    ResetA: ValueSignal
    ResetB: ValueSignal


class SpiDut(Protocol):
    rstb: ValueSignal
    clk: ScalarSignal
    mlb: ValueSignal
    start: ValueSignal
    m_tdat: ValueSignal
    cdiv: ValueSignal
    ten: ValueSignal
    s_tdata: ValueSignal
    mdone: ValueSignal
    mrdata: ValueSignal
    slvdone: ValueSignal
    slvrdata: ValueSignal


class MainCtrlDut(Protocol):
    cmd_line_state: ValueSignal
    ready_for_data: ValueSignal
    frame_select_temp: ValueSignal
    frame_select: ValueSignal


class MainUDut(Protocol):
    global_reset: ValueSignal
    clk_root: ValueSignal
    row_address_active: ValueSignal
    ctrl: MainCtrlDut


class MainWrapperDut(Protocol):
    clk: ScalarSignal
    reset: ValueSignal
    spi_start: ValueSignal
    spi_clk_en: ValueSignal
    thebyte: ValueSignal
    spi_master_txdone: ScalarSignal
    u_main: MainUDut
