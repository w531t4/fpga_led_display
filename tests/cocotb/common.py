# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

import os
from typing import Callable, Iterable

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import Timer

from dut_types import ScalarSignal, ValueSignal


def _parse_build_flags() -> dict[str, str | None]:
    raw = os.environ.get("BUILD_FLAGS", "")
    flags: dict[str, str | None] = {}
    for token in raw.split():
        if not token.startswith("-D"):
            continue
        macro = token[2:]
        if "=" in macro:
            name, value = macro.split("=", 1)
            flags[name] = value
        else:
            flags[macro] = None
    return flags


def flag_enabled(name: str) -> bool:
    return name in _parse_build_flags()


def flag_value(name: str) -> str | None:
    return _parse_build_flags().get(name)


def root_clock_hz() -> int:
    flags = _parse_build_flags()
    if "CLK_110" in flags:
        return 110_000_000
    if "CLK_100" in flags:
        return 100_000_000
    if "CLK_90" in flags:
        return 90_000_000
    if "CLK_50" in flags:
        return 50_000_000
    return 16_000_000


def sim_half_period_ns() -> float:
    return (1.0 / root_clock_hz()) * 1_000_000_000 / 2.0


def bytes_per_pixel() -> int:
    return 3 if flag_enabled("RGB24") else 2


def brightness_levels() -> int:
    return 8 if flag_enabled("RGB24") else 6


def pixel_width() -> int:
    override = flag_value("PIXEL_WIDTH_OVERRIDE")
    if override is not None:
        return int(override, 0)
    if flag_enabled("W128"):
        return 64 * 6
    return 64


def pixel_height() -> int:
    override = flag_value("PIXEL_HEIGHT_OVERRIDE")
    if override is not None:
        return int(override, 0)
    return 32


def pixel_halfheight() -> int:
    override = flag_value("PIXEL_HALFHEIGHT_OVERRIDE")
    if override is not None:
        return int(override, 0)
    return pixel_height() // 2


async def start_clock(sig: SimHandleBase, period_ns: float | int) -> None:
    if isinstance(period_ns, float) and not period_ns.is_integer():
        period_ps = int(round(period_ns * 1000))
        if period_ps % 2:
            high = period_ps // 2
            cocotb.start_soon(
                Clock(sig, period_ps, unit="ps", period_high=high).start()
            )
        else:
            cocotb.start_soon(Clock(sig, period_ps, unit="ps").start())
        return
    cocotb.start_soon(Clock(sig, int(period_ns), unit="ns").start())


async def wait_cycles(clk: ScalarSignal, cycles: int) -> None:
    for _ in range(cycles):
        await clk.rising_edge


async def wait_assert(
    clk: ScalarSignal,
    cond: Callable[[], bool],
    max_cycles: int,
    message: str,
) -> None:
    for cycle in range(max_cycles):
        try:
            if cond():
                return
        except ValueError:
            # Treat X/Z conversion errors as "not yet".
            pass
        await clk.rising_edge
    raise AssertionError(f"Timeout after {max_cycles} cycles: {message}")


def int_to_bytes_msb(value: int, bit_count: int) -> bytes:
    byte_count = (bit_count + 7) // 8
    return value.to_bytes(byte_count, "big")


async def drive_bytes_msb(
    clk: ScalarSignal,
    data_sig: ValueSignal,
    payload: bytes,
) -> None:
    for byte in payload:
        await clk.rising_edge
        data_sig.value = int(byte)


def iter_bits_msb(value: int, bit_count: int) -> Iterable[int]:
    for idx in range(bit_count - 1, -1, -1):
        yield (value >> idx) & 1


async def pulse_signal(sig: ValueSignal, clk: ScalarSignal, cycles: int = 1) -> None:
    sig.value = 1
    for _ in range(cycles):
        await clk.rising_edge
    sig.value = 0
