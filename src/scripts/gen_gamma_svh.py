#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: gen_gamma_svh.py <input.mem> <output.svh>", file=sys.stderr)
        return 2

    in_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])
    values = [line.strip() for line in in_path.read_text().splitlines() if line.strip()]
    base = in_path.stem.upper().replace("-", "_")
    macro = f"{base}_LUT"
    guard = f"{base}_SVH"

    lines = [f"// Auto-generated from {in_path.name}. Do not edit by hand."]
    lines.append(f"`ifndef {guard}")
    lines.append(f"`define {guard}")
    lines.append(f"`define {macro} \\")
    lines.append("  '{ \\")
    row = []
    for i, val in enumerate(values):
        suffix = "," if i < len(values) - 1 else ""
        row.append(f"8'h{val}{suffix}")
        if (i + 1) % 16 == 0:
            lines.append(f"    {' '.join(row)} \\")
            row = []
    if row:
        lines.append(f"    {' '.join(row)} \\")
    lines.append("  }")
    lines.append("`endif")

    out_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
