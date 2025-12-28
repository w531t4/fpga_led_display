# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
from __future__ import annotations

import argparse
import ast
import difflib
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


ACCESSORS = {"value", "rising_edge", "falling_edge", "value_change"}
EDGE_ACCESSORS = {"rising_edge", "falling_edge"}


@dataclass
class ModuleInfo:
    name: str
    path: Path
    ports: set[str] = field(default_factory=set)
    signals: set[str] = field(default_factory=set)
    instances: dict[str, str] = field(default_factory=dict)


def _find_iverilog(root: Path) -> Path:
    env_path = os.environ.get("IVERILOG_BIN")
    if env_path:
        return Path(env_path)
    which = shutil.which("iverilog")
    if which:
        return Path(which)
    fallback = root / "oss-cad-suite" / "libexec" / "iverilog"
    return fallback


def _load_build_flags(root: Path) -> str:
    env_flags = os.environ.get("BUILD_FLAGS")
    if env_flags:
        return env_flags
    makefile_path = root / "tests" / "cocotb" / "Makefile"
    if not makefile_path.is_file():
        return ""
    lines = makefile_path.read_text(encoding="utf-8").splitlines()
    collecting = False
    collected: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("BUILD_FLAGS"):
            collecting = True
            _, _, value = line.partition("=")
            collected.append(value.rstrip("\\").strip())
            if not line.rstrip().endswith("\\"):
                break
            continue
        if collecting:
            collected.append(stripped.rstrip("\\").strip())
            if not line.rstrip().endswith("\\"):
                break
    return " ".join(part for part in collected if part)


def _parse_defines(build_flags: str) -> list[str]:
    defines: list[str] = []
    for token in build_flags.split():
        if token.startswith("-D"):
            defines.append(token)
    if "-DSIM" not in defines:
        defines.insert(0, "-DSIM")
    return defines


def _preprocess_file(path: Path, root: Path, defines: list[str]) -> Path:
    iverilog = _find_iverilog(root)
    if not iverilog.is_file():
        raise RuntimeError("iverilog not found; set IVERILOG_BIN or add it to PATH")
    include_dirs = [
        root / "src" / "include",
        root / "src",
        root / "tests" / "cocotb" / "rtl",
    ]
    with tempfile.NamedTemporaryFile(delete=False, suffix=".sv") as tmp:
        output_path = Path(tmp.name)
    cmd = [
        str(iverilog),
        "-E",
        "-g2012",
        *defines,
        "-o",
        str(output_path),
    ]
    for include_dir in include_dirs:
        if include_dir.is_dir():
            cmd.extend(["-I", str(include_dir)])
    cmd.append(str(path))
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        output_path.unlink(missing_ok=True)
        raise RuntimeError(f"iverilog preprocess failed for {path}:\n{result.stderr}")
    return output_path


def _load_verible_tree(path: Path, root: Path, defines: list[str]) -> dict:
    preprocessed = _preprocess_file(path, root, defines)
    cmd = [
        "verible-verilog-syntax",
        "--export_json",
        "--printtree",
        str(preprocessed),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    preprocessed.unlink(missing_ok=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"verible-verilog-syntax failed for {path}:\n{result.stderr}"
        )
    data = json.loads(result.stdout)
    entry = data.get(str(preprocessed))
    if not isinstance(entry, dict) or "tree" not in entry:
        raise RuntimeError(f"verible-verilog-syntax returned no tree for {path}")
    return entry["tree"]


def _walk_tree(node: dict) -> Iterable[dict]:
    stack = [node]
    while stack:
        current = stack.pop()
        if not isinstance(current, dict):
            continue
        yield current
        children = current.get("children", [])
        for child in reversed(children):
            if isinstance(child, dict):
                stack.append(child)


def _find_children(node: dict, tag: str) -> list[dict]:
    children: list[dict] = []
    for child in node.get("children", []):
        if isinstance(child, dict) and child.get("tag") == tag:
            children.append(child)
    return children


def _find_symbol(node: dict) -> str | None:
    for child in _walk_tree(node):
        if child.get("tag") == "SymbolIdentifier":
            return child.get("text")
    return None


def _module_name(module_decl: dict) -> str | None:
    for header in _walk_tree(module_decl):
        if header.get("tag") == "kModuleHeader":
            for child in header.get("children", []):
                if isinstance(child, dict) and child.get("tag") == "SymbolIdentifier":
                    return child.get("text")
    return None


def _module_ports(module_decl: dict) -> set[str]:
    ports: set[str] = set()
    for node in _walk_tree(module_decl):
        if node.get("tag") != "kPortDeclaration":
            continue
        for child in _find_children(node, "kUnqualifiedId"):
            name = _find_symbol(child)
            if name:
                ports.add(name)
    return ports


def _module_signals(module_decl: dict) -> set[str]:
    signals: set[str] = set()
    for node in _walk_tree(module_decl):
        if node.get("tag") == "kRegisterVariable":
            name = _find_symbol(node)
            if name:
                signals.add(name)
        if node.get("tag") == "kNetVariable":
            name = _find_symbol(node)
            if name:
                signals.add(name)
    return signals


def _module_instances(module_decl: dict) -> dict[str, str]:
    instances: dict[str, str] = {}
    for node in _walk_tree(module_decl):
        if node.get("tag") != "kInstantiationBase":
            continue
        gate_instances = [
            inst for inst in _walk_tree(node) if inst.get("tag") == "kGateInstance"
        ]
        if not gate_instances:
            continue
        inst_type: str | None = None
        for child in _walk_tree(node):
            if child.get("tag") == "kInstantiationType":
                inst_type = _find_symbol(child)
                break
        if not inst_type:
            continue
        for inst in gate_instances:
            name = _find_symbol(inst)
            if name:
                instances[name] = inst_type
    return instances


def _parse_modules(
    paths: Iterable[Path], root: Path, defines: list[str]
) -> dict[str, ModuleInfo]:
    modules: dict[str, ModuleInfo] = {}
    for path in paths:
        tree = _load_verible_tree(path, root, defines)
        for node in _walk_tree(tree):
            if node.get("tag") != "kModuleDeclaration":
                continue
            name = _module_name(node)
            if not name:
                continue
            if name in modules:
                continue
            info = ModuleInfo(
                name=name,
                path=path,
                ports=_module_ports(node),
                signals=_module_signals(node),
                instances=_module_instances(node),
            )
            modules[name] = info
    module_names = set(modules.keys())
    for info in modules.values():
        info.instances = {
            inst: mod for inst, mod in info.instances.items() if mod in module_names
        }
    return modules


def _verilog_sources(root: Path) -> list[Path]:
    src_dir = root / "src"
    rtl_dir = root / "tests" / "cocotb" / "rtl"
    sources: list[Path] = []
    for ext in (".sv", ".v"):
        sources.extend(src_dir.rglob(f"*{ext}"))
    if rtl_dir.is_dir():
        sources.extend(rtl_dir.rglob("*.sv"))
    return sorted({path.resolve() for path in sources})


def _load_test_mapping(root: Path) -> dict[str, str]:
    runner_path = root / "tests" / "cocotb" / "test_cocotb_runner.py"
    run_all_path = root / "tests" / "cocotb" / "run_all.py"
    for path in (runner_path, run_all_path):
        if not path.is_file():
            continue
        tree = ast.parse(path.read_text(encoding="utf-8"))
        for node in tree.body:
            assign_value = None
            targets: list[ast.AST] = []
            if isinstance(node, ast.Assign):
                assign_value = node.value
                targets = node.targets
            elif isinstance(node, ast.AnnAssign):
                assign_value = node.value
                targets = [node.target]
            if assign_value is None:
                continue
            for target in targets:
                if isinstance(target, ast.Name) and target.id in {"TESTS", "_tests"}:
                    value = ast.literal_eval(assign_value)
                    mapping: dict[str, str] = {}
                    for item in value:
                        toplevel, module = item
                        mapping[module] = toplevel
                    if mapping:
                        return mapping
    return {}


def _dut_annotation(tree: ast.AST) -> str | None:
    for node in ast.walk(tree):
        if isinstance(node, (ast.AsyncFunctionDef, ast.FunctionDef)):
            for arg in node.args.args:
                if arg.arg != "dut" or arg.annotation is None:
                    continue
                annotation = arg.annotation
                if isinstance(annotation, ast.Name):
                    return annotation.id
                if isinstance(annotation, ast.Attribute):
                    return annotation.attr
    return None


def _imported_dut_types(tree: ast.AST) -> list[str]:
    names: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module == "dut_types":
            for alias in node.names:
                names.append(alias.name)
    return names


def _attr_chain(node: ast.AST) -> list[str] | None:
    if not isinstance(node, ast.Attribute):
        return None
    chain: list[str] = []
    current: ast.AST = node
    while isinstance(current, ast.Attribute):
        chain.append(current.attr)
        current = current.value
    if isinstance(current, ast.Name) and current.id == "dut":
        return list(reversed(chain))
    return None


@dataclass
class DutUsage:
    ordered: list[tuple[str, ...]] = field(default_factory=list)
    scalar_signals: set[tuple[str, ...]] = field(default_factory=set)
    value_signals: set[tuple[str, ...]] = field(default_factory=set)
    _seen: set[tuple[str, ...]] = field(default_factory=set, init=False, repr=False)

    def mark_scalar(self, path: tuple[str, ...]) -> None:
        if not path:
            return
        if path not in self._seen:
            self.ordered.append(path)
            self._seen.add(path)
        self.value_signals.discard(path)
        self.scalar_signals.add(path)

    def mark_value(self, path: tuple[str, ...]) -> None:
        if not path or path in self.scalar_signals:
            return
        if path not in self._seen:
            self.ordered.append(path)
            self._seen.add(path)
        self.value_signals.add(path)


class _DutVisitor(ast.NodeVisitor):
    def __init__(self) -> None:
        self.chains: list[tuple[int, int, list[str]]] = []
        self.start_clock_chains: list[tuple[int, int, list[str]]] = []

    def visit_Attribute(self, node: ast.Attribute) -> None:
        chain = _attr_chain(node)
        if chain:
            lineno = getattr(node, "lineno", 0)
            col = getattr(node, "col_offset", 0)
            self.chains.append((lineno, col, chain))
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if isinstance(node.func, ast.Name) and node.func.id == "start_clock":
            if node.args:
                chain = _attr_chain(node.args[0])
                if chain:
                    lineno = getattr(node, "lineno", 0)
                    col = getattr(node, "col_offset", 0)
                    self.start_clock_chains.append((lineno, col, chain))
        self.generic_visit(node)


def _collect_usage(path: Path) -> tuple[str, DutUsage] | None:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    dut_name = _dut_annotation(tree)
    if dut_name is None:
        imported = _imported_dut_types(tree)
        if len(imported) == 1:
            dut_name = imported[0]
    if dut_name is None:
        return None
    usage = DutUsage()
    visitor = _DutVisitor()
    visitor.visit(tree)
    ordered_chains = sorted(visitor.chains)
    module_paths: set[tuple[str, ...]] = set()
    for _lineno, _col, chain in ordered_chains:
        for idx in range(1, len(chain)):
            if chain[idx] in ACCESSORS:
                continue
            module_paths.add(tuple(chain[:idx]))
    for _lineno, _col, chain in ordered_chains:
        if chain[-1] in ACCESSORS:
            signal_path = tuple(chain[:-1])
            if chain[-1] in EDGE_ACCESSORS:
                usage.mark_scalar(signal_path)
            else:
                usage.mark_value(signal_path)
        else:
            if len(chain) == 1:
                if tuple(chain) not in module_paths:
                    usage.mark_value(tuple(chain))
    for _lineno, _col, chain in sorted(visitor.start_clock_chains):
        if chain:
            if tuple(chain) not in module_paths:
                usage.mark_scalar(tuple(chain))
    return dut_name, usage


def _camel(name: str) -> str:
    parts = [part for part in name.split("_") if part]
    return "".join(part[:1].upper() + part[1:] for part in parts)


@dataclass
class TreeNode:
    signals: dict[str, str] = field(default_factory=dict)
    children: dict[str, "TreeNode"] = field(default_factory=dict)


def _build_tree(usage: DutUsage) -> TreeNode:
    root = TreeNode()
    for signal_path in usage.ordered:
        cursor = root
        for part in signal_path[:-1]:
            cursor = cursor.children.setdefault(part, TreeNode())
        signal_name = signal_path[-1]
        signal_type = (
            "ScalarSignal" if signal_path in usage.scalar_signals else "ValueSignal"
        )
        if signal_name not in cursor.signals:
            cursor.signals[signal_name] = signal_type
        elif signal_type == "ScalarSignal":
            cursor.signals[signal_name] = signal_type
    return root


def _nested_class_name(
    parent_class: str,
    parent_module: str | None,
    attr: str,
    modules: dict[str, ModuleInfo],
    class_modules: dict[str, str | None],
) -> str:
    if parent_module and parent_module in modules:
        module_info = modules[parent_module]
        nested_module = module_info.instances.get(attr)
        if nested_module:
            nested_name = f"{_camel(nested_module)}Dut"
            class_modules.setdefault(nested_name, nested_module)
            return nested_name
    base = parent_class[:-3] if parent_class.endswith("Dut") else parent_class
    nested_name = f"{base}{_camel(attr)}Dut"
    class_modules.setdefault(nested_name, None)
    return nested_name


def _render_class(
    name: str,
    node: TreeNode,
    definitions: dict[str, list[str]],
    existing_order: dict[str, list[str]],
    existing_types: dict[str, dict[str, str]],
    modules: dict[str, ModuleInfo],
    class_modules: dict[str, str | None],
) -> None:
    parent_module = class_modules.get(name)
    child_classes: dict[str, str] = {}
    for child_name, child_node in node.children.items():
        nested_name = _nested_class_name(
            name, parent_module, child_name, modules, class_modules
        )
        child_classes[child_name] = nested_name
        if nested_name not in definitions:
            _render_class(
                nested_name,
                child_node,
                definitions,
                existing_order,
                existing_types,
                modules,
                class_modules,
            )
    lines = [f"class {name}(Protocol):"]
    ordered_names: list[str] = []
    if name in existing_order:
        ordered_names.extend(existing_order[name])
    extra_names = [*node.signals.keys(), *node.children.keys()]
    for item in extra_names:
        if item not in ordered_names:
            ordered_names.append(item)
    for attr_name in ordered_names:
        if attr_name in node.signals:
            existing = existing_types.get(name, {}).get(attr_name)
            if existing:
                lines.append(f"    {attr_name}: {existing}")
            else:
                lines.append(f"    {attr_name}: {node.signals[attr_name]}")
            continue
        if attr_name in node.children:
            nested_name = child_classes[attr_name]
            lines.append(f"    {attr_name}: {nested_name}")
            continue
        existing = existing_types.get(name, {}).get(attr_name)
        if existing:
            lines.append(f"    {attr_name}: {existing}")
            continue
        lines.append(f"    {attr_name}: ValueSignal")
    if len(lines) == 1:
        lines.append("    pass")
    definitions[name] = lines


def _render_dut_types(
    usages: dict[str, DutUsage],
    existing_order: dict[str, list[str]],
    existing_types: dict[str, dict[str, str]],
    modules: dict[str, ModuleInfo],
    class_modules: dict[str, str | None],
) -> str:
    definitions: dict[str, list[str]] = {}
    for root in sorted(usages.keys()):
        _render_class(
            root,
            _build_tree(usages[root]),
            definitions,
            existing_order,
            existing_types,
            modules,
            class_modules,
        )
    ordered_defs: list[str] = []
    for name in sorted(definitions.keys()):
        ordered_defs.append("\n".join(definitions[name]))

    # TODO: FIX SPDX Headers
    header = [
        "from __future__ import annotations",
        "",
        "from typing import Any, Protocol",
        "",
        "",
        "class ScalarSignal(Protocol):",
        "    value: Any",
        "    rising_edge: Any",
        "    falling_edge: Any",
        "    value_change: Any",
        "",
        "",
        "class ValueSignal(Protocol):",
        "    value: Any",
        "    value_change: Any",
        "    def __len__(self) -> int: ...",
        "",
        "",
    ]
    body = "\n\n\n".join(ordered_defs)
    return "\n".join(header) + "\n" + body + "\n"


def _resolve_class_usages(root: Path) -> tuple[dict[str, DutUsage], dict[str, str]]:
    usages: dict[str, DutUsage] = {}
    dut_to_test_module: dict[str, str] = {}
    for path in sorted((root / "tests" / "cocotb").glob("test_*.py")):
        if path.name == "test_cocotb_runner.py":
            continue
        result = _collect_usage(path)
        if result is None:
            continue
        dut_name, usage = result
        usages[dut_name] = usage
        dut_to_test_module[dut_name] = path.stem
    return usages, dut_to_test_module


def _verify_signals(
    usages: dict[str, DutUsage],
    modules: dict[str, ModuleInfo],
    test_mapping: dict[str, str],
    dut_to_test_module: dict[str, str],
) -> list[str]:
    warnings: list[str] = []
    for dut_name, usage in usages.items():
        test_module = dut_to_test_module.get(dut_name)
        if test_module is None:
            continue
        toplevel = test_mapping.get(test_module)
        if not toplevel or toplevel not in modules:
            continue
        for signal_path in sorted(usage.scalar_signals | usage.value_signals):
            module_name = toplevel
            for segment in signal_path[:-1]:
                info = modules.get(module_name)
                if info is None:
                    break
                module_name = info.instances.get(segment, module_name)
            info = modules.get(module_name)
            if info is None:
                continue
            if (
                signal_path[-1] not in info.ports
                and signal_path[-1] not in info.signals
            ):
                warnings.append(
                    f"{dut_name}: {'.'.join(signal_path)} not found in {info.path}"
                )
    return warnings


def _load_existing_layout(
    path: Path,
) -> tuple[dict[str, list[str]], dict[str, dict[str, str]]]:
    if not path.is_file():
        return ({}, {})
    tree = ast.parse(path.read_text(encoding="utf-8"))
    order: dict[str, list[str]] = {}
    types: dict[str, dict[str, str]] = {}
    for node in tree.body:
        if not isinstance(node, ast.ClassDef):
            continue
        if node.name in {"ScalarSignal", "ValueSignal"}:
            continue
        attrs: list[str] = []
        attr_types: dict[str, str] = {}
        for stmt in node.body:
            if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                attrs.append(stmt.target.id)
                annotation = stmt.annotation
                if isinstance(annotation, ast.Name):
                    attr_types[stmt.target.id] = annotation.id
                elif isinstance(annotation, ast.Attribute):
                    attr_types[stmt.target.id] = annotation.attr
        order[node.name] = attrs
        types[node.name] = attr_types
    return (order, types)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate dut_types.py from tests and HDL."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify generated output matches tests/cocotb/dut_types.py",
    )
    parser.add_argument(
        "--output",
        default="tests/cocotb/dut_types.py",
        help="Output path for generated dut_types.py",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    build_flags = _load_build_flags(root)
    defines = _parse_defines(build_flags)
    usages, dut_to_test_module = _resolve_class_usages(root)
    existing_order, existing_types = _load_existing_layout(
        root / "tests" / "cocotb" / "dut_types.py"
    )
    modules = _parse_modules(_verilog_sources(root), root, defines)
    test_mapping = _load_test_mapping(root)
    warnings = _verify_signals(usages, modules, test_mapping, dut_to_test_module)
    for warning in warnings:
        print(f"Warning: {warning}")
    class_modules: dict[str, str | None] = {}
    for dut_name, test_module in dut_to_test_module.items():
        toplevel = test_mapping.get(test_module)
        if toplevel:
            class_modules[dut_name] = toplevel
    content = _render_dut_types(
        usages, existing_order, existing_types, modules, class_modules
    )
    output_path = (root / args.output).resolve()
    if args.check:
        existing = output_path.read_text(encoding="utf-8")
        if existing != content:
            diff = "\n".join(
                difflib.unified_diff(
                    existing.splitlines(),
                    content.splitlines(),
                    fromfile=str(output_path),
                    tofile="generated",
                    lineterm="",
                )
            )
            print(diff)
            return 1
        return 0
    output_path.write_text(content, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
