import re
from typing import List, Optional
import sys
import tempfile
import subprocess
from pathlib import Path
import argparse

def open_sdiff(file1: Path, file2: Path, other_args: Optional[List[str]] = None) -> str:
    if other_args is not None and isinstance(other_args, list):
        args = other_args
    else:
        args = list()
    all_args = ["sdiff", str(file1), str(file2)]
    all_args.extend(args)
    proc = subprocess.Popen(args=all_args,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (stdout, stderr) = proc.communicate()
    # print(stdout)
    data = stdout.decode("utf-8")
    return data

def format_yosys_log(data: str) -> str:
    new_data = []
    rex = re.compile(r"(\s*AST_\S+ <[^>]+> \[)[^\]]+(\].*?)")
    for each in data.split("\n"):
        each = re.sub(rex, r"\1\2", each)
        new_data.append(each)
    return "\n".join(new_data)


def main(left: Path,
         right: Path,
         remainder_args: Optional[List[str]] = None) -> None:
    if not left.is_file():
        print("left must be file. exiting")
        sys.exit(1)
    if not right.is_file():
        print("right must be file. exiting")
        sys.exit(1)
    left_data = left.read_text()
    right_data = right.read_text()

    sanitized_left = format_yosys_log(left_data)
    sanitized_right = format_yosys_log(right_data)

    with tempfile.NamedTemporaryFile() as ntf_left_raw:
        ntf_left = Path(ntf_left_raw.name)
        ntf_left.write_text(sanitized_left, encoding="utf-8")
        with tempfile.NamedTemporaryFile() as ntf_right_raw:
            ntf_right = Path(ntf_right_raw.name)
            ntf_right.write_text(sanitized_right, encoding="utf-8")

            output = open_sdiff(ntf_left, ntf_right, remainder_args)
            print(output)

if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(prog="yosyslog_sdiff",
                                     description="i sdiff yosys log files")

    PARSER.add_argument('left',
                        type=Path,
                        metavar="LEFTFILE",
                        help="Path to left")
    PARSER.add_argument('right',
                        type=Path,
                        metavar="RIGHTFILE",
                        help="Path to right")
    PARSER.add_argument(nargs=argparse.REMAINDER,
                        dest="remainder_args",
                        action="store",
                        type=str,
                        metavar="SDIFF_ARGS",
                        help="remainder_args")
    ARGS = PARSER.parse_args()

    try:
        main(**vars(ARGS))
    except BrokenPipeError:
        pass