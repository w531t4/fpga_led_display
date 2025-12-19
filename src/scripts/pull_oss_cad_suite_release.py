#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-FileComment: Generated using ChatGPT (OpenAI)
# SPDX-License-Identifier: MIT

from __future__ import annotations

import argparse
import os
import platform
import tarfile
from pathlib import Path
from typing import Any, Dict, Iterable, Optional

import requests


DEFAULT_OWNER = "YosysHQ"
DEFAULT_REPO = "oss-cad-suite-build"
API_BASE = "https://api.github.com"


class GitHubError(RuntimeError):
    pass


def _headers() -> Dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "oss-cad-suite-downloader/2.2",
    }
    token = os.getenv("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _gh_get_json(url: str) -> Dict[str, Any]:
    r = requests.get(url, headers=_headers(), timeout=60)
    if r.status_code >= 400:
        raise GitHubError(f"GitHub API error {r.status_code}: {r.text[:500]}")
    return r.json()


def get_release(
    owner: str,
    repo: str,
    tag: Optional[str],
    latest: bool,
) -> Dict[str, Any]:
    if latest:
        url = f"{API_BASE}/repos/{owner}/{repo}/releases/latest"
    else:
        if not tag:
            raise ValueError("tag required unless --latest is used")
        url = f"{API_BASE}/repos/{owner}/{repo}/releases/tags/{tag}"
    return _gh_get_json(url)


def iter_assets(release: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    return release.get("assets") or []


def normalize_os_arch() -> tuple[str, str]:
    os_name = platform.system().lower()
    arch = platform.machine().lower()

    if os_name.startswith("linux"):
        os_name = "linux"
    elif os_name.startswith("darwin"):
        os_name = "darwin"
    elif os_name.startswith("windows"):
        os_name = "windows"

    if arch in {"x86_64", "amd64"}:
        arch = "x64"
    elif arch in {"aarch64", "arm64"}:
        arch = "arm64"

    return os_name, arch


def is_auxiliary(name: str) -> bool:
    return any(
        name.endswith(s)
        for s in (
            ".sha256",
            ".sha1",
            ".md5",
            ".sig",
            ".asc",
            ".txt",
            ".json",
        )
    )


def is_tarball(name: str) -> bool:
    return name.endswith(".tgz") or name.endswith(".tar.gz")


def auto_pick_tarball(assets: list[Dict[str, Any]]) -> Dict[str, Any]:
    os_name, arch = normalize_os_arch()

    def eligible(a: Dict[str, Any]) -> bool:
        name = (a.get("name") or "").lower()
        return name and is_tarball(name) and not is_auxiliary(name)

    # 1) OS + arch match
    candidates = []
    for a in assets:
        name = (a.get("name") or "").lower()
        if eligible(a) and os_name in name and arch in name:
            candidates.append(a)

    # 2) OS-only match
    if not candidates:
        for a in assets:
            name = (a.get("name") or "").lower()
            if eligible(a) and os_name in name:
                candidates.append(a)

    # 3) Fallback: any tarball
    if not candidates:
        candidates = [a for a in assets if eligible(a)]

    if not candidates:
        raise GitHubError("No suitable tarball assets found")

    # Prefer largest (main bundle)
    return max(candidates, key=lambda a: int(a.get("size") or 0))


def download(url: str, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_suffix(dst.suffix + ".part")

    with requests.get(url, headers=_headers(), stream=True, timeout=300) as r:
        if r.status_code >= 400:
            raise GitHubError(f"Download failed: {r.status_code}")
        with tmp.open("wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)

    tmp.replace(dst)


def safe_extract(tar: tarfile.TarFile, path: Path) -> None:
    base = path.resolve()

    for member in tar.getmembers():
        target = (path / member.name).resolve()

        # Prevent ../ path traversal
        if not target.is_relative_to(base):
            raise GitHubError(f"Unsafe tar path: {member.name}")

        # Optional hardening: refuse device files
        if member.isdev():
            raise GitHubError(f"Refusing to extract device file: {member.name}")

    tar.extractall(path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--latest", action="store_true")
    ap.add_argument("--tag")
    ap.add_argument("--outdir", default="downloads")
    ap.add_argument("--tarball", action="store_true")
    ap.add_argument("--extract", action="store_true")

    args = ap.parse_args()

    if not (args.latest or args.tag):
        ap.error("Must specify --latest or --tag")

    if args.extract:
        args.tarball = True

    if not args.tarball:
        ap.error("This script only supports tarball workflows (--tarball or --extract)")

    release = get_release(DEFAULT_OWNER, DEFAULT_REPO, args.tag, args.latest)
    assets = list(iter_assets(release))

    asset = auto_pick_tarball(assets)
    name = asset["name"]
    url = asset["browser_download_url"]

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    tar_path = outdir / name

    print(f"Downloading {name}")
    download(url, tar_path)

    if args.extract:
        print(f"Extracting into {outdir}")
        with tarfile.open(tar_path, "r:*") as tf:
            safe_extract(tf, outdir)
        tar_path.unlink()

    print("Done.")


if __name__ == "__main__":
    main()
