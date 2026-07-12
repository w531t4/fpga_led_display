#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
#
# Emit git-derived version `-D` flags (one per line) for a Verilator/yosys `-f`
# command file; reg_version.sv packs them into a READSTATUS register so the host
# can read the running gateware's version. The version comes from the latest
# semantic-release tag (setup.cfg: tag_format = "v{version}"); dev builds also
# carry commits-since-tag, the short HEAD sha, and a dirty flag. Values are kept
# apostrophe-free (bare hex for the sha) so they survive make/shell/yosys -p.
# Output goes to stdout; mk/version.mk captures it into build/version_args.
set -euo pipefail

# Fail nicely when git is unavailable or this isn't a repo (e.g. an extracted
# tarball): warn once and stamp a clean version 0 so the build still proceeds
# (reg_version.sv would fall back to the same values anyway).
if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gen_version_defines.sh: git unavailable / not a repo; stamping version 0.0.0" >&2
    cat <<EOF
-DVERSION_MAJOR=0
-DVERSION_MINOR=0
-DVERSION_PATCH=0
-DVERSION_GIT_SHA=00000000
-DVERSION_COMMITS=0
-DVERSION_DIRTY=0
EOF
    exit 0
fi

tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
if [ -n "$tag" ]; then
    ver="${tag#v}"
    major="${ver%%.*}"; rest="${ver#*.}"
    minor="${rest%%.*}"; patch="${rest#*.}"
    patch="${patch%%[-+]*}"   # drop any -prerelease / +build suffix
    commits="$(git rev-list "${tag}..HEAD" --count 2>/dev/null || echo 0)"
else
    # No release tag yet: report 0.0.0 and count all commits as "since".
    major=0; minor=0; patch=0
    commits="$(git rev-list HEAD --count 2>/dev/null || echo 0)"
fi

full="$(git rev-parse HEAD 2>/dev/null || echo 0000000000000000000000000000000000000000)"
sha="${full:0:8}"

if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    dirty=0
else
    dirty=1
fi

# Clamp each field to its register width (see reg_version.sv encoding).
clamp() { # <value> <max> -> non-negative integer, clamped
    local v="$1" max="$2"
    case "$v" in *[!0-9]*|'') v=0 ;; esac
    if [ "$v" -gt "$max" ]; then echo "$max"; else echo "$v"; fi
}
major="$(clamp "${major:-0}" 127)"
minor="$(clamp "${minor:-0}" 127)"
patch="$(clamp "${patch:-0}" 127)"
commits="$(clamp "${commits:-0}" 1023)"

cat <<EOF
-DVERSION_MAJOR=${major}
-DVERSION_MINOR=${minor}
-DVERSION_PATCH=${patch}
-DVERSION_GIT_SHA=${sha}
-DVERSION_COMMITS=${commits}
-DVERSION_DIRTY=${dirty}
EOF
