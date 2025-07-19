""" Parse linting output from verilator, and emit any items failing to match a denylist filter"""
import sys
from typing import List, NamedTuple
from pathlib import Path


class LintTitle(NamedTuple):
    """holder of components of lint title line"""
    severity: str
    category: str
    file: str
    row: int
    col: int

def get_filter_items(path: Path) -> List[str]:
    """ Get list of files to filter from config file"""
    try:
        return [x for x in path.read_text().split("\n") if len(x) > 0]
    except FileNotFoundError:
        return []

def print_grouping(data: List[str]) -> None:
    """emit all items in the group"""
    for each in data:
        print(each)

def parse_lint_title(line: str) -> LintTitle:
    """ parse row into an object"""
    try:
        # selects Warning-UNUSEDSIGNAL
        atype_param = line[1:].split(": ")[0]
        atype, param = atype_param.split("-")

        # selects src/main.v:147:16
        file_row_col = line[1:].split(": ")[1]
        file,row,col = file_row_col.split(":") # pylint: disable=unused-variable
    except ValueError as e:
        print(f"had problem parsing row={line} e={e}")
        raise


    return LintTitle(severity=atype,
                     category=param,
                     file=file,
                     row=int(row),
                     col=int(col),
                     )

def is_suppressed(line_from_file: str, filter_files: List[str]) -> bool:
    """determine if suppression should occur (based on components from the header line)"""
    # Example
    #  '%Warning-UNUSEDSIGNAL: src/main.v:147:16: Signal is not used: 'num_commands_processed''
    obj = parse_lint_title(line_from_file)
    return obj.file in filter_files

def print_summary(summary: List[LintTitle]) -> None:
    """emit a summary of the observed issues"""
    set()
    summary_set = set([(x.severity, x.category, x.file) for x in summary])
    for each in sorted(list(summary_set), key=lambda x: x[2]):
        # atype, param, file
        applicable_rows = sorted(set([x.row for x in summary if (x.severity, x.category, x.file) == each[0:3]]))
        print(f"{len([x for x in summary if (x.severity, x.category, x.file) == each[0:3]])}: "
              f"{each[2]} {each[0]} {each[1]} lines={applicable_rows}")

def main() -> None:
    """ main """
    files_to_filter = get_filter_items(Path(".verilator_lint"))
    has_started = False
    in_grouping = False
    suppress_current_group = False

    issue_summary: List[LintTitle] = list()
    grouping_text = list()
    issue_items = list()

    for line in sys.stdin:
        line = line.rstrip()

        # Emit lines that verilator emits preceeding the lint output section
        if not has_started and len(line) > 0 and line[0] == "%" and "-" in line:
            has_started = True
        elif not has_started:
            print(line)
            continue

        # verilator prints a summary by default - don't emit it, as the output
        # doesn't take into account our filtering.
        if "%Error: Exiting due to" in line and ("warning(s)" in line or "error(s)" in line):
            continue

        if len(line) > 0 and line[0] == "%":
            if in_grouping and not suppress_current_group:
                print_grouping(grouping_text)
                issue_items.append(grouping_text)
                grouping_text = list()
                in_grouping = False
            # elif in_grouping and suppress_current_group:
            #     suppress_current_group = False
            in_grouping = True
            title_obj = parse_lint_title(line)
            suppress_current_group = title_obj.file in files_to_filter
            if not suppress_current_group:
                grouping_text.append(line)
                issue_summary.append(title_obj)
        elif in_grouping and suppress_current_group:
            continue
        elif in_grouping and not suppress_current_group:
            grouping_text.append(line)

    if in_grouping and len(grouping_text) > 0 and not suppress_current_group:
        print_grouping(grouping_text)
        issue_items.append(grouping_text)
        grouping_text = list()

    print_summary(issue_summary)
    if len(issue_items) > 0:
        num_warnings = len([x for x in issue_summary if x.severity == "Warning"])
        num_errors = len([x for x in issue_summary if x.severity == "Error"])
        if num_warnings > 0 and num_errors > 0:
            print(f"%Error: Exiting due to {num_warnings} warning(s) and {num_errors} error(s)")
        elif num_warnings > 0:
            print(f"%Warning: Exiting due to {num_warnings} warning(s)")
        elif num_errors > 0:
            print(f"%Error: Exiting due to {num_errors} errors(s)")
        if num_errors > 0:
            sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
