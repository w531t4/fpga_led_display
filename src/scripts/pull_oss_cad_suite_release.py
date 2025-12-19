#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-FileComment: Generated using ChatGPT (OpenAI)
# SPDX-License-Identifier: MIT
from __future__ import annotations

import argparse
import json
import os
import platform
import sys
import tarfile
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

import requests


DEFAULT_OWNER = "YosysHQ"
DEFAULT_REPO = "oss-cad-suite-build"
API_BASE = "https://api.github.com"


class GitHubError(RuntimeError):
    pass


# ───────────────────────────────────────────────────────────────
# GitHub helpers
# ───────────────────────────────────────────────────────────────

def _headers() -> Dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "oss-cad-suite-downloader/2.1",
    }
    token = os.getenv("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _gh_get_json(url: str) -> Dict[str, Any]:
    r = requests.get(url, headers=_headers(), timeout=60)
    if r.status_code == 403 and "rate limit" in r.text.lower():
        raise GitHubError("GitHub API rate limit hit (403). Set GITHUB_TOKEN.")
    if r.status_code >= 400:
        raise GitHubError(f"GitHub API error {r.status_code} for {url}: {r.text[:500]}")
    return r.json()


def get_release(owner: str, repo: str, tag: Optional[str], latest: bool) -> Dict[str, Any]:
    if latest:
        url = f"{API_BASE}/repos/{owner}/{repo}/releases/latest"
    else:
        if not tag:
            raise ValueError("tag must be provided when --latest is not used")
        url = f"{API_BASE}/repos/{owner}/{repo}/releases/tags/{tag}"
    return _gh_get_json(url)


def iter_assets(release: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    yield from (release.get("assets") or [])


# ───────────────────────────────────────────────────────────────
# Platform / asset selection
# ───────────────────────────────────────────────────────────────

def normalize_os_arch() -> tuple[str, str]:
    sys_os = platform.system().lower()
    mach = platform.machine().lower()

    os_norm = (
        "linux" if sys_os.startswith("linux")
        else "darwin" if sys_os.startswith("darwin")
        else "windows" if sys_os.startswith("windows")
        else sys_os
    )

    arch_norm = (
        "x64" if mach in {"x86_64", "amd64"}
        else "arm64" if mach in {"aarch64", "arm64"}
        else mach
    )

    return os_norm, arch_norm


def is_tarball(name: str) -> bool:
    return name.lower().endswith((".tgz", ".tar.gz", ".tar", ".tar.xz"))


def is_auxiliary_asset(name: str) -> bool:
    return name.lower().endswith((
        ".sha256", ".sha256sum", ".sha1", ".md5",
        ".sig", ".asc", ".txt", ".json"
    ))


def archive_score(name: str, prefer_tarball: bool) -> int:
    score = 0
    if is_tarball(name):
        score += 40 if prefer_tarball else 30
    if name.endswith(".zip"):
        score += 25
    if "debug" in name or "symbols" in name:
        score -= 5
    return score


def auto_pick_asset(assets: list[Dict[str, Any]], prefer_tarball: bool) -> Dict[str, Any]:
    os_norm, arch_norm = normalize_os_arch()

    def eligible(a: Dict[str, Any]) -> bool:
        n = a.get("name")
        return bool(n and not is_auxiliary_asset(n) and (not prefer_tarball or is_tarball(n)))

    candidates = [
        a for a in assets
        if eligible(a)
        and os_norm in a["name"].lower()
        and arch_norm in a["name"].lower()
    ] or [a for a in assets if eligible(a)]

    if not candidates:
        raise GitHubError("No suitable asset found")

    return max(
        candidates,
        key=lambda a: (archive_score(a["name"], prefer_tarball), int(a.get("size", 0)))
    )


# ───────────────────────────────────────────────────────────────
# Cache helpers
# ───────────────────────────────────────────────────────────────

def resolve_cache_root(cli_cache_dir: Optional[str]) -> Path:
    if cli_cache_dir:
        return Path(cli_cache_dir)

    env = os.getenv("OSS_CAD_SUITE_CACHE_DIR")
    if env:
        return Path(env)

    if Path("/workspaces").exists():
        return Path("/workspaces/.cache/oss-cad-suite")

    return Path(os.getenv("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "oss-cad-suite"


def _rm_tree(path: Path) -> None:
    # Minimal recursive delete to avoid shutil dependency/behavior surprises.
    for child in sorted(path.rglob("*"), reverse=True):
        if child.is_file() or child.is_symlink():
            child.unlink()
        elif child.is_dir():
            child.rmdir()
    path.rmdir()


def prune_other_versions(root: Path, keep_tag: str, dry_run: bool) -> bool:
    """Prune tag subdirectories under `root` except `keep_tag`.

    Returns True if anything would be pruned (or was pruned).
    """
    if not root.exists():
        return False

    to_prune: list[Path] = []
    for p in sorted(root.iterdir()):
        if p.is_dir() and p.name != keep_tag:
            to_prune.append(p)

    if not to_prune:
        return False

    for p in to_prune:
        if dry_run:
            print(f"[dry-run] Would prune: {p}")
        else:
            print(f"Pruning cached version: {p}")
            _rm_tree(p)

    return True


# ───────────────────────────────────────────────────────────────
# Download + extract
# ───────────────────────────────────────────────────────────────

def _meta_path_for(asset_path: Path) -> Path:
    return asset_path.with_suffix(asset_path.suffix + ".meta.json")


def load_meta(asset_path: Path) -> Optional[Dict[str, Any]]:
    try:
        return json.loads(_meta_path_for(asset_path).read_text(encoding="utf-8"))
    except Exception:
        return None


def save_meta(asset_path: Path, meta: Dict[str, Any]) -> None:
    _meta_path_for(asset_path).write_text(json.dumps(meta, indent=2, sort_keys=True), encoding="utf-8")


def download_file_with_dedupe(asset: Dict[str, Any], out_path: Path) -> None:
    expected_size = int(asset.get("size") or 0)
    expected_updated = asset.get("updated_at")

    if out_path.exists():
        meta = load_meta(out_path)
        try:
            size_ok = out_path.stat().st_size == expected_size
        except FileNotFoundError:
            size_ok = False

        if meta and size_ok and meta.get("updated_at") == expected_updated:
            print(f"  {out_path.name}: already downloaded")
            return

    headers = _headers()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".part")

    with requests.get(asset["browser_download_url"], headers=headers, stream=True, timeout=300) as r:
        if r.status_code >= 400:
            raise GitHubError(f"Download failed: {r.status_code}")

        with tmp.open("wb") as f:
            for chunk in r.iter_content(1024 * 1024):
                if chunk:
                    f.write(chunk)

        tmp.replace(out_path)

        save_meta(out_path, {
            "updated_at": expected_updated,
            "size": expected_size,
            "etag": r.headers.get("ETag"),
        })


def safe_extract_tar(tar_path: Path, dest_dir: Path) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_resolved = dest_dir.resolve()

    with tarfile.open(tar_path, "r:*") as tf:
        for m in tf.getmembers():
            target = (dest_dir / m.name).resolve()
            try:
                target.relative_to(dest_resolved)
            except ValueError:
                raise GitHubError(f"Unsafe tar member path: {m.name}")
        tf.extractall(dest_dir)


# ───────────────────────────────────────────────────────────────
# Extraction sentinel
# ───────────────────────────────────────────────────────────────

def extract_ok_path(extracted_dir: Path) -> Path:
    return extracted_dir / ".extract.ok"


def extract_meta_path(asset: Dict[str, Any], extracted_dir: Path) -> Path:
    return extracted_dir / f"{asset['name']}.extract.meta.json"


def extraction_is_current(asset: Dict[str, Any], extracted_dir: Path) -> bool:
    if not extract_ok_path(extracted_dir).exists():
        return False

    mp = extract_meta_path(asset, extracted_dir)
    if not mp.exists():
        return False

    meta = json.loads(mp.read_text(encoding="utf-8"))
    if meta.get("updated_at") != asset.get("updated_at"):
        return False
    if meta.get("size") != asset.get("size"):
        return False

    # Must have some non-dot content
    return any(p for p in extracted_dir.iterdir() if not p.name.startswith("."))


def write_extract_meta(asset: Dict[str, Any], extracted_dir: Path) -> None:
    extract_meta_path(asset, extracted_dir).write_text(json.dumps({
        "name": asset["name"],
        "size": asset["size"],
        "updated_at": asset["updated_at"],
    }, indent=2, sort_keys=True), encoding="utf-8")
    extract_ok_path(extracted_dir).write_text("ok\n", encoding="utf-8")


# ───────────────────────────────────────────────────────────────
# Symlink helper
# ───────────────────────────────────────────────────────────────

def ensure_symlink(link_path: Path, target_path: Path, force: bool) -> None:
    """Create a symlink at `link_path` pointing to `target_path`.

    If `link_path` already points to `target_path`, this is a no-op.
    If `force` is True, remove any existing file/dir/symlink at `link_path` first.
    """
    link_path = link_path.expanduser()
    target_path = target_path.resolve()

    if link_path.is_symlink():
        # If it's already correct, do nothing (idempotent).
        try:
            if link_path.resolve() == target_path:
                return
        except FileNotFoundError:
            # Broken symlink; treat as replaceable below.
            pass

    if link_path.exists() or link_path.is_symlink():
        if not force:
            raise GitHubError(
                f"Symlink path already exists: {link_path} (use --force-symlink to replace)"
            )
        if link_path.is_symlink() or link_path.is_file():
            link_path.unlink()
        else:
            _rm_tree(link_path)

    link_path.parent.mkdir(parents=True, exist_ok=True)

    # Prefer relative symlink when possible (more portable within a workspace)
    try:
        rel_target = target_path.relative_to(link_path.parent.resolve())
        link_path.symlink_to(rel_target)
    except Exception:
        link_path.symlink_to(target_path)


# ───────────────────────────────────────────────────────────────
# Main
# ───────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--latest", action="store_true")
    ap.add_argument("--tag")
    ap.add_argument("--auto", action="store_true", help="Auto-pick best asset for this OS/arch")
    ap.add_argument("--tarball", action="store_true", help="Download the tarball")
    ap.add_argument("--extract", action="store_true", help="Extract the tarball into cache")
    ap.add_argument("--cache-dir")

    ap.add_argument("--prune-other-versions", action="store_true")
    ap.add_argument("--dry-run-prune", action="store_true")

    ap.add_argument("--symlink", help="Create a symlink at this path pointing into the extracted release")
    ap.add_argument(
        "--symlink-subdir",
        default=".",
        help="Subdirectory (relative to extracted/<tag>) that the symlink should point to (default: '.')",
    )
    ap.add_argument("--force-symlink", action="store_true", help="Replace existing symlink/path at --symlink")

    args = ap.parse_args()

    if not args.latest and not args.tag:
        ap.error("Must specify --latest or --tag")

    if args.symlink and not args.extract:
        raise GitHubError("--symlink requires --extract (symlink points into extracted/<tag>)")

    cache_root = resolve_cache_root(args.cache_dir)
    downloads = cache_root / "downloads"
    extracted = cache_root / "extracted"

    release = get_release(DEFAULT_OWNER, DEFAULT_REPO, args.tag, args.latest)
    assets = list(iter_assets(release))

    # If you later add non-auto selection, do it here. For now, always auto tarball.
    asset = auto_pick_asset(assets, prefer_tarball=True)

    tag = release["tag_name"]
    tar_path = downloads / tag / asset["name"]
    extract_dir = extracted / tag

    print(f"Cache root: {cache_root}")
    print(f"Release tag: {tag}")
    print(f"Selected asset: {asset.get('name')}")

    # Prune first (after we know which tag we are keeping), before any download/extract.
    if args.prune_other_versions:
        did_prune = False
        did_prune |= prune_other_versions(downloads, tag, args.dry_run_prune)
        did_prune |= prune_other_versions(extracted, tag, args.dry_run_prune)
        if args.dry_run_prune and did_prune:
            print("[dry-run] Prune completed (no changes made)")

    # Tarball download if requested or needed for extraction.
    if args.extract or args.tarball or (args.symlink and args.extract):
        download_file_with_dedupe(asset, tar_path)

    if args.extract:
        if extraction_is_current(asset, extract_dir):
            print("Already extracted — no extraction needed")
        else:
            print("Extracting tarball...")
            safe_extract_tar(tar_path, extract_dir)
            write_extract_meta(asset, extract_dir)

        if args.symlink:
            sub = Path(args.symlink_subdir)
            if sub.is_absolute():
                raise GitHubError("--symlink-subdir must be a relative path")
            target = extract_dir / sub
            if not target.exists():
                raise GitHubError(f"Symlink target does not exist: {target}")
            ensure_symlink(Path(args.symlink), target, force=args.force_symlink)
            print(f"Symlinked: {args.symlink} -> {target}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
