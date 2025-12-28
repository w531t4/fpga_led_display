# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

import os
from pathlib import Path
import pytest
from cocotb_test import simulator

ROOT_DIR = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT_DIR / "src"
TEST_RTL_DIR = ROOT_DIR / "tests" / "cocotb" / "rtl"
OSS_CAD_LIBEXEC = ROOT_DIR / "oss-cad-suite" / "libexec"
DEFAULT_BUILD_FLAGS = (
    "-DSPI -DGAMMA -DCLK_90 -DW128 -DRGB24 -DSPI_ESP32 "
    "-DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN"
)

TESTS: list[tuple[str, str]] = [
    ("brightness_timeout", "test_brightness_timeout"),
    ("clock_divider", "test_clock_divider"),
    ("control_cmd_readpixel", "test_control_cmd_readpixel"),
    ("control_cmd_readrow", "test_control_cmd_readrow"),
    ("cocotb_watchdog_wrapper", "test_control_cmd_watchdog"),
    ("control_module", "test_control_module"),
    ("control_subcmd_fillarea", "test_control_subcmd_fillarea"),
    ("cocotb_debugger_wrapper", "test_debugger"),
    ("ff_sync", "test_ff_sync"),
    ("fm6126init", "test_fm6126init"),
    ("cocotb_main_wrapper", "test_main"),
    ("matrix_scan", "test_matrix_scan"),
    ("multimem", "test_multimem"),
    ("cocotb_spi_wrapper", "test_spi"),
]


def _parse_defines(build_flags: str) -> list[str]:
    defines: list[str] = []
    for token in build_flags.split():
        if token.startswith("-D"):
            defines.append(token[2:])
    return defines


def _verilog_sources() -> list[str]:
    params_pkg = SRC_DIR / "params_pkg.sv"
    sources: list[Path] = [params_pkg]
    candidates: list[Path] = []
    for ext in (".sv", ".v"):
        candidates.extend(SRC_DIR.rglob(f"*{ext}"))
    for path in sorted(candidates):
        if path == params_pkg:
            continue
        if "testbenches" in path.parts:
            continue
        sources.append(path)
    if TEST_RTL_DIR.is_dir():
        sources.extend(sorted(TEST_RTL_DIR.rglob("*.sv")))
    return [str(path) for path in sources]


def _ensure_oss_cad_on_path() -> None:
    if not OSS_CAD_LIBEXEC.is_dir():
        return
    path = os.environ.get("PATH", "")
    oss_path = str(OSS_CAD_LIBEXEC)
    if oss_path not in path.split(os.pathsep):
        os.environ["PATH"] = os.pathsep.join([oss_path, path])


@pytest.mark.parametrize(("toplevel", "module"), TESTS)
def test_cocotb_module(toplevel: str, module: str) -> None:
    build_flags = os.environ.get("BUILD_FLAGS", DEFAULT_BUILD_FLAGS)
    os.environ.setdefault("BUILD_FLAGS", build_flags)
    _ensure_oss_cad_on_path()

    compile_args: list[str] = []
    vvp_path = OSS_CAD_LIBEXEC / "vvp"
    if vvp_path.is_file():
        compile_args.extend(["-p", f"VVP_EXECUTABLE={vvp_path}"])

    simulator.run(
        toplevel=toplevel,
        module=module,
        work_dir=str(ROOT_DIR),
        toplevel_lang="verilog",
        verilog_sources=_verilog_sources(),
        includes=[str(SRC_DIR / "include"), str(SRC_DIR)],
        defines=["SIM", *_parse_defines(build_flags)],
        compile_args=compile_args,
        verilog_compile_args=["-y", str(SRC_DIR), "-Y", ".sv", "-Y", ".v"],
        python_search=[str(ROOT_DIR / "tests" / "cocotb")],
        sim_build=str(ROOT_DIR / "tests" / "cocotb" / "sim_build" / toplevel),
        timescale="1ns/1ps",
        force_compile=True,
    )
