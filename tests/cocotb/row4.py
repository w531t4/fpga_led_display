# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

import ast
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from common import flag_enabled


@dataclass(frozen=True)
class Constant:
    name: str
    width_bits: int
    value: int

    def as_bytes(self) -> bytes:
        byte_count = (self.width_bits + 7) // 8
        return self.value.to_bytes(byte_count, "big")


_LOCALPARAM_RE = re.compile(
    r"localparam\s+\[(?P<range>[^\]]+)\]\s+(?P<name>\w+)\s*=\s*'h(?P<hex>[0-9a-fA-F_]+)\s*;",
)
_MYLED_ROW_START_RE = re.compile(r"\bmyled_row\b\s*=\s*\{")


def _safe_eval(expr: str) -> int:
    expr = expr.replace("_", "")
    if not re.fullmatch(r"[0-9+\-*/() \t]+", expr):
        raise ValueError(f"Unsupported expression: {expr}")
    tree = ast.parse(expr, mode="eval")
    for node in ast.walk(tree):
        if not isinstance(
            node,
            (
                ast.Expression,
                ast.BinOp,
                ast.UnaryOp,
                ast.Constant,
                ast.Add,
                ast.Sub,
                ast.Mult,
                ast.Div,
                ast.FloorDiv,
            ),
        ):
            raise ValueError(f"Unsupported node in expression: {expr}")
    return int(eval(compile(tree, "<expr>", "eval"), {"__builtins__": {}}, {}))


def _range_width(range_text: str) -> int:
    msb_expr = range_text.split(":", 1)[0].strip()
    msb_val = _safe_eval(msb_expr)
    return msb_val + 1


def _active_blocks(lines: Iterable[str]) -> Iterable[str]:
    stack: list[tuple[bool, bool]] = []
    active = True
    for raw in lines:
        line = raw.strip()
        if line.startswith("`ifdef"):
            macro = line.split()[1]
            cond = flag_enabled(macro)
            stack.append((active, cond))
            active = active and cond
            continue
        if line.startswith("`ifndef"):
            macro = line.split()[1]
            cond = not flag_enabled(macro)
            stack.append((active, cond))
            active = active and cond
            continue
        if line.startswith("`else"):
            parent_active, cond = stack.pop()
            cond = not cond
            stack.append((parent_active, cond))
            active = parent_active and cond
            continue
        if line.startswith("`endif"):
            stack.pop()
            if stack:
                parent_active, cond = stack[-1]
                active = parent_active and cond
            else:
                active = True
            continue
        if not active:
            continue
        yield raw


def _strip_comments(line: str) -> str:
    if "//" in line:
        return line.split("//", 1)[0]
    return line


def _parse_row4_constants() -> dict[str, Constant]:
    path = Path(__file__).resolve().parents[2] / "src" / "include" / "row4.vh"
    constants: dict[str, Constant] = {}
    myled_row_items: list[str] = []
    in_myled_row = False

    for raw in _active_blocks(path.read_text(encoding="utf-8").splitlines()):
        line = _strip_comments(raw).strip()
        if not line:
            continue

        match = _LOCALPARAM_RE.search(line)
        if match:
            width_bits = _range_width(match.group("range"))
            hex_value = match.group("hex").replace("_", "")
            value = int(hex_value, 16)
            constants[match.group("name")] = Constant(
                name=match.group("name"),
                width_bits=width_bits,
                value=value,
            )
            continue

        if _MYLED_ROW_START_RE.search(line):
            in_myled_row = True
            line = line.split("{", 1)[1]

        if in_myled_row:
            if "};" in line:
                line = line.split("};", 1)[0]
                in_myled_row = False
            items = [part.strip() for part in line.split(",") if part.strip()]
            myled_row_items.extend(items)

    if myled_row_items:
        value = 0
        width = 0
        for name in myled_row_items:
            if name.endswith("}"):
                name = name.rstrip("}")
            const = constants.get(name)
            if const is None:
                raise ValueError(f"Missing constant {name} for myled_row")
            value = (value << const.width_bits) | const.value
            width += const.width_bits
        constants["myled_row"] = Constant(
            name="myled_row", width_bits=width, value=value
        )

    return constants


_CONSTANTS = _parse_row4_constants()


def constant(name: str) -> Constant:
    return _CONSTANTS[name]


def myled_row_basic_local() -> bytes:
    base = constant("myled_row_basic").as_bytes()
    return base[1:]


def myled_row_pixel_local() -> bytes:
    base = constant("myled_row_pixel").as_bytes()
    return base[1:]


def myled_row_bytes() -> bytes:
    return constant("myled_row").as_bytes()
