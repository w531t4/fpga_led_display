""" Parse linting output from verilator, and emit any items failing to match a denylist filter"""
import sys
from typing import List

KEYWORD = "error"  # <-- Change this to whatever string you want to filter by

in_grouping = False
suppress_current_group = False
grouping_text = list()
issue_summary = list()
issue_items = list()
has_started = False

def print_grouping(data: List[str]) -> None:
    """emit all items in the group"""
    for each in data:
        print(each)
    issue_items.append(data)

def is_suppressed(line_from_file: str) -> bool:
    """determine if suppression should occur (based on components from the header line)"""
    try:
        atype_param = line_from_file[1:].split(": ")[0]
        file_row_col = line_from_file[1:].split(": ")[1]
        file,row,col = file_row_col.split(":") # pylint: disable=unused-variable
        atype, param = atype_param.split("-")
    except IndexError:
        return False

    filter_files = ["src/platform/tiny_ecp5_sim.v","src/platform/tiny_cells_sim.v", "src/new_pll.v"]
    if not file in filter_files:
        issue_summary.append((atype, param, file,))
    return file in filter_files

def print_summary(summary: List[str]) -> None:
    """emit a summary of the observed issues"""
    summary_set = set(summary)
    for each in sorted(list(summary_set), key=lambda x: x[2]):
        print(f"{len([x for x in summary if x == each])}: {each[2]} {each[0]} {each[1]}")


for line in sys.stdin:
    line = line.rstrip()
    if not has_started and len(line) > 0 and line[0] == "%":
        has_started = True
    elif not has_started:
        print(line)
        continue
    # print(f"mine line={line}")
    if "%Error: Exiting due to" in line and "warning(s)" in line:
        continue
    if len(line) > 0 and line[0] == "%":
        has_started = True
        if in_grouping and not suppress_current_group:
            print_grouping(grouping_text)
            grouping_text = list()
            in_grouping = False
        # elif in_grouping and suppress_current_group:
        #     suppress_current_group = False
        in_grouping = True
        suppress_current_group = is_suppressed(line)
        if not suppress_current_group:
            grouping_text.append(line)
    elif in_grouping and suppress_current_group:
        continue
    elif in_grouping and not suppress_current_group:
        grouping_text.append(line)

if in_grouping and len(grouping_text) > 0 and not suppress_current_group:
    print_grouping(grouping_text)
    grouping_text = list()


print_summary(issue_summary)
if len(issue_items) > 0:
    print(f"%Error: Exiting due to {len(issue_items)} warning(s)")
    # sys.exit(1)

sys.exit(0)
