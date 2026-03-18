# SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
"""Fail when a nextpnr timing report misses any constrained clock target."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

MHZ_TO_NS = 1000.0


def period_ns(freq_mhz: float) -> float:
    """Convert frequency to period in ns."""
    return MHZ_TO_NS / freq_mhz


def shortfall_ns(achieved_mhz: float, constraint_mhz: float) -> float:
    """Return the period miss in ns for a constrained clock."""
    if achieved_mhz <= 0.0 or constraint_mhz <= 0.0:
        return float("inf")
    return period_ns(achieved_mhz) - period_ns(constraint_mhz)


def main() -> int:
    """Parse the timing report and fail if any constrained clock misses timing."""
    parser = argparse.ArgumentParser(
        description="Check a nextpnr timing report for timing violations."
    )
    parser.add_argument(
        "report",
        help="Path to build/nextpnr-report.json.",
    )
    args = parser.parse_args()

    report_path = Path(args.report)
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)

    fmax = report.get("fmax")
    if not isinstance(fmax, dict) or not fmax:
        print(
            f"Timing check failed: no fmax data found in {report_path}.",
            file=sys.stderr,
        )
        return 1

    constrained_clocks = []
    violations = []

    for clock_name, clock_info in sorted(fmax.items()):
        achieved = float(clock_info.get("achieved", 0.0))
        constraint = float(clock_info.get("constraint", 0.0))

        if constraint <= 0.0:
            continue

        constrained_clocks.append(clock_name)

        if achieved < constraint:
            violations.append(
                (
                    clock_name,
                    achieved,
                    constraint,
                    shortfall_ns(achieved, constraint),
                )
            )

    if not constrained_clocks:
        print(
            f"Timing check failed: no constrained clocks found in {report_path}.",
            file=sys.stderr,
        )
        return 1

    if violations:
        print("Timing constraints not met:", file=sys.stderr)
        for clock_name, achieved, constraint, shortfall_ns_value in violations:
            print(
                f"  {clock_name}: achieved {achieved:.6f} MHz, "
                f"constraint {constraint:.6f} MHz, "
                f"shortfall {shortfall_ns_value:.3f} ns",
                file=sys.stderr,
            )
        return 1

    print("Timing constraints met.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
