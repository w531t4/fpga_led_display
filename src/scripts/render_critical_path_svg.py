# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
"""
Render a nextpnr critical path as an SVG timeline.

Example:
  python3 src/scripts/render_critical_path_svg.py build/nextpnr-report.json \
      --out build/critical_path.svg
"""

from __future__ import annotations

import argparse
import html
import json
import textwrap
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Configuration constants (avoid magic numbers in the logic below).
# ---------------------------------------------------------------------------
DEFAULT_INPUT_PATH = "build/nextpnr-report.json"
DEFAULT_OUTPUT_PATH = "build/critical_path.svg"

DEFAULT_CLOCK_FILTER = None
DEFAULT_PATH_INDEX = None

DEFAULT_MAX_LABEL_CHARS = None
MHZ_TO_NS = 1000.0

SVG_FONT_FAMILY = (
    "ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace"
)

TITLE_FONT_SIZE = 18
SUBTITLE_FONT_SIZE = 12
TEXT_FONT_SIZE = 11
LEGEND_FONT_SIZE = 11

PADDING_X = 30
PADDING_Y = 30

LABEL_COLUMN_WIDTH = 440

ROW_MIN_HEIGHT = 36
ROW_GAP = 10
BAR_HEIGHT = 18
LABEL_LINE_HEIGHT = 12
ROW_VERTICAL_PADDING = 4
LABEL_TO_BAR_GAP = 12
MONOSPACE_CHAR_WIDTH = 6.8

TITLE_LINE_HEIGHT = 26
SUBTITLE_LINE_HEIGHT = 18
AXIS_HEIGHT = 22
LEGEND_ROW_HEIGHT = 18

AXIS_TICK_COUNT = 5

TARGET_INNER_WIDTH = 1100
MIN_INNER_WIDTH = 700
MAX_INNER_WIDTH = 1600
DEFAULT_PX_PER_NS = 120

BACKGROUND_COLOR = "#f7f5f2"
AXIS_COLOR = "#444444"
TEXT_COLOR = "#222222"
BAR_STROKE_COLOR = "#1b1b1b"

TYPE_COLORS: Dict[str, str] = {
    "clk-to-q": "#2a9d8f",
    "routing": "#e76f51",
    "logic": "#264653",
    "net": "#f4a261",
    "setup": "#6c757d",
    "hold": "#8d6a9f",
}

PathEntry = Tuple[int, Dict]


def load_report(path: Path) -> Dict:
    """Load the nextpnr JSON report into memory."""
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def enumerate_paths(paths: Iterable[Dict]) -> List[PathEntry]:
    """Attach report indices so later filtering still reports the real path index."""
    return list(enumerate(paths))


def path_mentions_clock(path: Dict, clock_name: str) -> bool:
    """Return whether either endpoint mentions the given clock name."""
    return clock_name in path.get("from", "") or clock_name in path.get("to", "")


def path_is_same_domain(path: Dict, clock_name: str) -> bool:
    """Return whether both endpoints belong to the same named clock domain."""
    return clock_name in path.get("from", "") and clock_name in path.get("to", "")


def filter_paths(paths: Iterable[PathEntry], clock_filter: str | None) -> List[PathEntry]:
    """Filter critical paths by clock name substring (if provided)."""
    if clock_filter is None:
        return list(paths)
    return [
        path
        for path in paths
        if path_mentions_clock(path[1], clock_filter)
    ]


def compute_total_delay(path: Dict) -> float:
    """Sum all element delays within a critical path."""
    return sum(elem.get("delay", 0.0) for elem in path.get("path", []))


def clock_period_ns(freq_mhz: float) -> float:
    """Convert MHz to ns."""
    return MHZ_TO_NS / freq_mhz


def compute_clock_shortfall_ns(clock_info: Dict) -> float:
    """
    Compute timing shortfall in ns for a clock entry from nextpnr fmax.

    Positive means the clock misses timing, negative means it meets timing margin.
    """
    achieved_mhz = clock_info.get("achieved", 0.0)
    constraint_mhz = clock_info.get("constraint", 0.0)
    if achieved_mhz <= 0.0 or constraint_mhz <= 0.0:
        return float("-inf")
    return clock_period_ns(achieved_mhz) - clock_period_ns(constraint_mhz)


def find_limiting_clock(fmax: Dict[str, Dict]) -> str | None:
    """Pick the clock with the smallest timing margin (or largest miss)."""
    scored_clocks = [
        (compute_clock_shortfall_ns(clock_info), clock_name)
        for clock_name, clock_info in fmax.items()
    ]
    if not scored_clocks:
        return None
    return max(scored_clocks, key=lambda item: item[0])[1]


def auto_select_default_paths(report: Dict, paths: List[PathEntry]) -> Tuple[List[PathEntry], str | None]:
    """
    Restrict the default view to the same-domain path for the report's limiting clock.

    This avoids defaulting to long async output paths that do not define the clock fmax.
    """
    limiting_clock = find_limiting_clock(report.get("fmax", {}))
    if limiting_clock is None:
        return paths, None

    same_domain_paths = [
        path for path in paths if path_is_same_domain(path[1], limiting_clock)
    ]
    if same_domain_paths:
        return same_domain_paths, limiting_clock

    matching_paths = filter_paths(paths, limiting_clock)
    if matching_paths:
        return matching_paths, limiting_clock

    return paths, None


def prefer_same_domain_paths(paths: List[PathEntry], clock_name: str) -> List[PathEntry]:
    """Prefer same-domain paths for an explicitly selected clock, if available."""
    same_domain_paths = [
        path for path in paths if path_is_same_domain(path[1], clock_name)
    ]
    if same_domain_paths:
        return same_domain_paths
    return paths


def select_path(paths: List[PathEntry], index: int | None) -> Tuple[Dict, int]:
    """Choose a specific path by filtered index, or the path with max total delay."""
    if not paths:
        raise ValueError("No critical paths found after filtering.")

    if index is not None:
        if index < 0 or index >= len(paths):
            raise ValueError(f"Path index {index} is out of range (0..{len(paths)-1}).")
        report_index, path = paths[index]
        return path, report_index

    report_index, path = max(paths, key=lambda item: compute_total_delay(item[1]))
    return path, report_index


def format_endpoint(endpoint: Dict | None) -> str:
    """Convert a path endpoint to a compact string for labels."""
    if not endpoint:
        return "<none>"
    cell = endpoint.get("cell", "<none>")
    port = endpoint.get("port", "<none>")
    loc = endpoint.get("loc")
    if isinstance(loc, list) and len(loc) == 2:
        loc_str = f"@{loc[0]},{loc[1]}"
    else:
        loc_str = ""
    return f"{cell}:{port}{loc_str}"


def segment_label(segment: Dict) -> str:
    """Build the full untruncated label for a path segment."""
    kind = segment.get("type", "unknown")
    delay = segment.get("delay", 0.0)
    from_str = format_endpoint(segment.get("from"))
    to_str = format_endpoint(segment.get("to"))
    net = segment.get("net")

    label = f"{kind} {delay:.3f} ns {from_str} -> {to_str}"
    if net:
        label = f"{label} net={net}"
    return label


def wrap_segment_label(label: str, max_chars: Optional[int]) -> List[str]:
    """Wrap a full segment label without truncating any content."""
    if max_chars is None:
        return [label]
    if max_chars <= 0:
        return [""]

    return textwrap.wrap(
        label,
        width=max_chars,
        break_long_words=True,
        break_on_hyphens=False,
    )


def chars_for_label_width(label_width_px: float, max_label_chars: Optional[int]) -> Optional[int]:
    """Convert the row's available label width from pixels into monospaced characters."""
    chars_per_line = max(1, int(label_width_px / MONOSPACE_CHAR_WIDTH))
    if max_label_chars is None:
        return chars_per_line
    return min(chars_per_line, max_label_chars)


def clamp(value: float, min_value: float, max_value: float) -> float:
    """Clamp a float into the given bounds."""
    return max(min_value, min(max_value, value))


def compute_scale(total_delay: float) -> Tuple[float, float]:
    """
    Determine the pixel scale for the timeline.

    Returns:
        (scale_px_per_ns, inner_width_px)
    """
    if total_delay <= 0:
        inner_width = MIN_INNER_WIDTH
        return DEFAULT_PX_PER_NS, inner_width

    raw_scale = TARGET_INNER_WIDTH / total_delay
    inner_width = raw_scale * total_delay
    inner_width = clamp(inner_width, MIN_INNER_WIDTH, MAX_INNER_WIDTH)
    scale = inner_width / total_delay
    return scale, inner_width


def svg_escape(text: str) -> str:
    """Escape text for safe SVG output."""
    return html.escape(text, quote=True)


def build_svg(path: Dict, path_index: int, max_label_chars: Optional[int]) -> str:
    """Render the SVG for a single critical path."""
    segments = path.get("path", [])
    total_delay = compute_total_delay(path)
    scale, inner_width = compute_scale(total_delay)

    # Anchor points for the timeline.
    timeline_x0 = PADDING_X + LABEL_COLUMN_WIDTH
    timeline_x1 = timeline_x0 + inner_width

    # Precompute row layout because label wrapping width depends on bar position.
    row_layouts = []
    cumulative_delay = 0.0
    rows_height = 0.0
    for segment in segments:
        seg_delay = segment.get("delay", 0.0)
        seg_start_x = timeline_x0 + cumulative_delay * scale
        seg_width = seg_delay * scale

        label_width_px = max(
            1.0,
            seg_start_x - PADDING_X - LABEL_TO_BAR_GAP,
        )
        label_chars = chars_for_label_width(label_width_px, max_label_chars)
        label_lines = wrap_segment_label(segment_label(segment), label_chars)
        label_height = len(label_lines) * LABEL_LINE_HEIGHT
        row_height = max(
            ROW_MIN_HEIGHT,
            label_height + ROW_VERTICAL_PADDING * 2,
        )

        row_layouts.append(
            {
                "segment": segment,
                "start_x": seg_start_x,
                "width": seg_width,
                "label_lines": label_lines,
                "row_height": row_height,
            }
        )

        rows_height += row_height
        cumulative_delay += seg_delay

    if row_layouts:
        rows_height += (len(row_layouts) - 1) * ROW_GAP

    legend_items = sorted({seg.get("type", "unknown") for seg in segments})
    legend_height = len(legend_items) * LEGEND_ROW_HEIGHT

    header_height = TITLE_LINE_HEIGHT + SUBTITLE_LINE_HEIGHT + AXIS_HEIGHT
    total_height = (
        PADDING_Y + header_height + rows_height + legend_height + PADDING_Y
    )
    total_width = PADDING_X * 2 + LABEL_COLUMN_WIDTH + inner_width

    # Compose header strings.
    from_str = path.get("from", "<unknown>")
    to_str = path.get("to", "<unknown>")
    title = f"Critical Path {path_index}  |  Total {total_delay:.3f} ns"
    subtitle = f"from {from_str}  to {to_str}"

    svg_lines: List[str] = []
    svg_lines.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{total_width:.0f}" height="{total_height:.0f}" '
        f'viewBox="0 0 {total_width:.0f} {total_height:.0f}">'
    )
    svg_lines.append(
        f'<rect width="100%" height="100%" fill="{BACKGROUND_COLOR}" />'
    )

    # Title block.
    title_y = PADDING_Y + TITLE_FONT_SIZE
    subtitle_y = PADDING_Y + TITLE_LINE_HEIGHT + SUBTITLE_FONT_SIZE
    svg_lines.append(
        f'<text x="{PADDING_X}" y="{title_y}" '
        f'font-family="{SVG_FONT_FAMILY}" font-size="{TITLE_FONT_SIZE}" '
        f'fill="{TEXT_COLOR}">{svg_escape(title)}</text>'
    )
    svg_lines.append(
        f'<text x="{PADDING_X}" y="{subtitle_y}" '
        f'font-family="{SVG_FONT_FAMILY}" font-size="{SUBTITLE_FONT_SIZE}" '
        f'fill="{TEXT_COLOR}">{svg_escape(subtitle)}</text>'
    )

    # Axis line with ticks.
    axis_y = PADDING_Y + TITLE_LINE_HEIGHT + SUBTITLE_LINE_HEIGHT + AXIS_HEIGHT
    svg_lines.append(
        f'<line x1="{timeline_x0:.2f}" y1="{axis_y:.2f}" '
        f'x2="{timeline_x1:.2f}" y2="{axis_y:.2f}" '
        f'stroke="{AXIS_COLOR}" stroke-width="1" />'
    )

    for i in range(AXIS_TICK_COUNT + 1):
        t_ratio = i / AXIS_TICK_COUNT
        tick_x = timeline_x0 + inner_width * t_ratio
        tick_delay = total_delay * t_ratio
        svg_lines.append(
            f'<line x1="{tick_x:.2f}" y1="{axis_y - 4:.2f}" '
            f'x2="{tick_x:.2f}" y2="{axis_y + 4:.2f}" '
            f'stroke="{AXIS_COLOR}" stroke-width="1" />'
        )
        svg_lines.append(
            f'<text x="{tick_x + 2:.2f}" y="{axis_y - 6:.2f}" '
            f'font-family="{SVG_FONT_FAMILY}" font-size="{TEXT_FONT_SIZE}" '
            f'fill="{TEXT_COLOR}">{tick_delay:.2f} ns</text>'
        )

    # Draw each segment row.
    row_base_y = PADDING_Y + header_height
    row_y = row_base_y

    for row_layout in row_layouts:
        segment = row_layout["segment"]
        row_height = row_layout["row_height"]
        seg_start_x = row_layout["start_x"]
        seg_width = row_layout["width"]
        seg_delay = segment.get("delay", 0.0)
        bar_y = row_y + (row_height - BAR_HEIGHT) / 2

        # Color by segment type (fall back to neutral gray).
        seg_type = segment.get("type", "unknown")
        seg_color = TYPE_COLORS.get(seg_type, "#9aa0a6")

        svg_lines.append(
            f'<rect x="{seg_start_x:.2f}" y="{bar_y:.2f}" '
            f'width="{seg_width:.2f}" height="{BAR_HEIGHT:.2f}" '
            f'fill="{seg_color}" stroke="{BAR_STROKE_COLOR}" stroke-width="0.8" />'
        )

        # Label column text describing the segment.
        label_lines = row_layout["label_lines"]
        label_y = row_y + ROW_VERTICAL_PADDING + TEXT_FONT_SIZE
        for line_index, label_line in enumerate(label_lines):
            line_y = label_y + line_index * LABEL_LINE_HEIGHT
            svg_lines.append(
                f'<text x="{PADDING_X}" y="{line_y:.2f}" '
                f'font-family="{SVG_FONT_FAMILY}" font-size="{TEXT_FONT_SIZE}" '
                f'fill="{TEXT_COLOR}">{svg_escape(label_line)}</text>'
            )

        # Delay annotation at the end of the bar to emphasize ordering.
        delay_text = f"{seg_delay:.3f} ns"
        delay_y = bar_y + BAR_HEIGHT / 2 + TEXT_FONT_SIZE / 2 - 1
        svg_lines.append(
            f'<text x="{seg_start_x + seg_width + 6:.2f}" y="{delay_y:.2f}" '
            f'font-family="{SVG_FONT_FAMILY}" font-size="{TEXT_FONT_SIZE}" '
            f'fill="{TEXT_COLOR}">{delay_text}</text>'
        )

        row_y += row_height + ROW_GAP

    # Legend listing unique segment types.
    legend_start_y = row_base_y + rows_height + LEGEND_ROW_HEIGHT
    for idx, seg_type in enumerate(legend_items):
        legend_y = legend_start_y + idx * LEGEND_ROW_HEIGHT
        color = TYPE_COLORS.get(seg_type, "#9aa0a6")
        svg_lines.append(
            f'<rect x="{PADDING_X}" y="{legend_y - LEGEND_FONT_SIZE + 2:.2f}" '
            f'width="{LEGEND_FONT_SIZE}" height="{LEGEND_FONT_SIZE}" '
            f'fill="{color}" stroke="{BAR_STROKE_COLOR}" stroke-width="0.6" />'
        )
        svg_lines.append(
            f'<text x="{PADDING_X + LEGEND_FONT_SIZE + 6}" y="{legend_y:.2f}" '
            f'font-family="{SVG_FONT_FAMILY}" font-size="{LEGEND_FONT_SIZE}" '
            f'fill="{TEXT_COLOR}">{svg_escape(seg_type)}</text>'
        )

    svg_lines.append("</svg>")
    return "\n".join(svg_lines)


def parse_args() -> argparse.Namespace:
    """Define and parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Render a nextpnr critical path as an SVG timeline."
    )
    parser.add_argument(
        "report",
        nargs="?",
        default=DEFAULT_INPUT_PATH,
        help=f"Path to nextpnr-report.json (default: {DEFAULT_INPUT_PATH}).",
    )
    parser.add_argument(
        "--out",
        default=DEFAULT_OUTPUT_PATH,
        help=f"Output SVG path (default: {DEFAULT_OUTPUT_PATH}).",
    )
    parser.add_argument(
        "--clock-filter",
        default=DEFAULT_CLOCK_FILTER,
        help=(
            "Only consider paths whose from/to fields contain this substring. "
            "Without this option, the script auto-selects the limiting clock domain."
        ),
    )
    parser.add_argument(
        "--index",
        type=int,
        default=DEFAULT_PATH_INDEX,
        help=(
            "Critical path index within the filtered list. Without a filter, this uses "
            "the full report list and bypasses the default limiting-clock auto-selection."
        ),
    )
    parser.add_argument(
        "--max-label-chars",
        type=int,
        default=DEFAULT_MAX_LABEL_CHARS,
        help=(
            "Optional cap on wrapped label characters per line. By default the script "
            "uses the full width available to the left of each bar."
        ),
    )
    return parser.parse_args()


def main() -> None:
    """Main entry point."""
    args = parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        raise FileNotFoundError(f"Report not found: {report_path}")

    report = load_report(report_path)
    paths = enumerate_paths(report.get("critical_paths", []))

    limiting_clock = None
    if args.clock_filter is not None:
        paths = filter_paths(paths, args.clock_filter)
        if args.index is None and args.clock_filter in report.get("fmax", {}):
            paths = prefer_same_domain_paths(paths, args.clock_filter)
    elif args.index is None:
        paths, limiting_clock = auto_select_default_paths(report, paths)

    path, path_index = select_path(paths, args.index)

    svg_text = build_svg(path, path_index, args.max_label_chars)
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(svg_text, encoding="utf-8")

    if limiting_clock is not None:
        print(f"Auto-selected limiting clock: {limiting_clock}")
    print(f"Wrote SVG to: {out_path}")


if __name__ == "__main__":
    main()
