# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable


TestSpec = tuple[str, str]


def _tests() -> Iterable[TestSpec]:
    return (
        ("test_brightness_timeout", "brightness_timeout"),
        ("test_clock_divider", "clock_divider"),
        ("test_control_cmd_readpixel", "control_cmd_readpixel"),
        ("test_control_cmd_readrow", "control_cmd_readrow"),
        ("test_control_cmd_watchdog", "cocotb_watchdog_wrapper"),
        ("test_control_module", "control_module"),
        ("test_control_subcmd_fillarea", "control_subcmd_fillarea"),
        ("test_debugger", "cocotb_debugger_wrapper"),
        ("test_ff_sync", "ff_sync"),
        ("test_fm6126init", "fm6126init"),
        ("test_main", "cocotb_main_wrapper"),
        ("test_matrix_scan", "matrix_scan"),
        ("test_multimem", "multimem"),
        ("test_spi", "cocotb_spi_wrapper"),
    )


def _run_test(test_module: str, toplevel: str, cwd: Path) -> int:
    env = os.environ.copy()
    cmd = [
        "make",
        "-C",
        str(cwd),
        "SIM=icarus",
        f"COCOTB_TEST_MODULES={test_module}",
        f"COCOTB_TOPLEVEL={toplevel}",
    ]
    result = subprocess.run(cmd, env=env, check=False)
    return result.returncode


def main() -> int:
    cocotb_dir = Path(__file__).resolve().parent
    failures: list[str] = []
    for test_module, toplevel in _tests():
        rc = _run_test(test_module, toplevel, cocotb_dir)
        if rc != 0:
            failures.append(f"{test_module} ({toplevel})")
            break
    if failures:
        print("Failed:", ", ".join(failures))
        return 1
    print("All cocotb tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
