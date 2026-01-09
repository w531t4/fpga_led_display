#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
"""Run verible formatter checks on staged files for pre-commit."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


# Keep flags centralized to avoid scatter and ease future maintenance.
FORMATTER = "verible-verilog-format"
FORMATTER_FLAGS_FILE = ".rules.verible_format"
FORMATTER_FAILSAFE = "--failsafe_success=false"
FORMATTER_FLAGFILE = f"--flagfile={FORMATTER_FLAGS_FILE}"

# Only attempt formatting checks for supported HDL suffixes.
SUPPORTED_SUFFIXES = {".sv", ".svh", ".v", ".vh"}


def iter_verilog_files(args: Sequence[str]) -> Iterable[Path]:
    """Yield verilog-related files from CLI args."""
    for raw in args:
        path = Path(raw)
        if path.suffix in SUPPORTED_SUFFIXES:
            yield path


def run_format_check(path: Path) -> Tuple[int, str]:
    """Run verible format check and return (rc, combined_output)."""
    try:
        result = subprocess.run(
            [FORMATTER, FORMATTER_FLAGFILE, FORMATTER_FAILSAFE, str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return 127, f"{FORMATTER} not found on PATH."

    combined = ""
    if result.stdout:
        combined += result.stdout
    if result.stderr:
        if combined:
            combined += "\n"
        combined += result.stderr
    return result.returncode, combined.strip()


def extract_relevant_errors(output: str, path: Path) -> List[str]:
    """Extract useful error lines from formatter output."""
    path_str = str(path)
    lines = [line for line in output.splitlines() if line.strip()]
    relevant = [
        line
        for line in lines
        if "syntax error" in line
        or path_str in line
        or "Error:" in line
        or "ERROR" in line
    ]
    if relevant:
        return relevant
    return lines[:1]


def main() -> int:
    """Entry point for pre-commit hook usage."""
    args = sys.argv[1:]
    verilog_files = list(iter_verilog_files(args))
    if not verilog_files:
        return 0

    failed: List[Path] = []
    for path in verilog_files:
        if not path.exists():
            # Pre-commit can pass deleted paths; keep output helpful.
            print(f"warning: file not found: {path}", file=sys.stderr)
            continue

        rc, output = run_format_check(path)
        if rc != 0:
            failed.append(path)
            print(f"verible format check failed: {path}")
            if output:
                for line in extract_relevant_errors(output, path):
                    print(line)

    if failed:
        print(
            f"hint: run `verible-verilog-format {FORMATTER_FAILSAFE} {FORMATTER_FLAGFILE} FILE` "
            "to run this check yourself."
        )
        print("formatting failures detected:")
        for path in failed:
            print(f"- {path}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
