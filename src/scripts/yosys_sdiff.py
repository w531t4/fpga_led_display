import re
from typing import List, Optional, NamedTuple, Sequence, Union
from io import StringIO
import sys
import tempfile
import subprocess
from pathlib import Path
import argparse


class Header(NamedTuple):
    data: str

class Section(NamedTuple):
    command: str
    data: str

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

def format_yosys_log(data: str) -> List[Union[Header,Section]]:
    new_data = []
    rex = re.compile(r"(\s*AST_\S+ <[^>]+> \[)[^\]]+(\].*?)")
    for each in data.split("\n"):
        each = re.sub(rex, r"\1\2", each)
        new_data.append(each)
    total = "\n".join(new_data)
    sectioned = sectionize(total)
    processed_sections: List[Union[Header,Section]] = [sectioned[0]]

    for each in [x for x in sectioned if isinstance(x, Section)]:
        if each.command == "clean":
            # def select_key(d: str) -> str:
            #     result = re.sub(r'(.*?)(\(\d+ -> \d+\))(.*?)', "\1\3", d)
            #     return result[::-1]

            temp_rows = each.data.split("\n")
            sorted_temp_rows = sorted(temp_rows, key=lambda x: x[::-1])
            processed_sections.append(Section(command=each.command, data="\n".join(sorted_temp_rows)))
        # elif each.command == "opt_lut_ins -tech lattice":
        #     def select_key(d: str) -> str:
        #         result = re.sub(r'(.*?)(\(\d+ -> \d+\))(.*?)', "\1\3", d)
        #         return result[::-1]

        #     temp_rows = each.data.split("\n")
        #     sorted_temp_rows = sorted(temp_rows, key=lambda x: select_key(x))
        #     processed_sections.append(Section(command=each.command, data="\n".join(sorted_temp_rows)))
        else:
            processed_sections.append(each)

    return processed_sections

def sectionize(data: str) -> List[Union[Section, Header]]:
    output = list()
    components = data.split("\nyosys> ")
    output.append(Header(data=components[0]))
    for each in components[1:]:
        command = each.split("\n")[0]
        content = "\n".join(each.split("\n")[1:])
        output.append(Section(command=command, data=content))
    return output

def assemble_content(data: List[Union[Header,Section]], masked_sections: Optional[List[str]] = None) -> str:
    if masked_sections is None:
        masked_sections = list()
    out = StringIO()
    if isinstance(data[0], Header):
        out.write(f"{data[0].data}\n")
    for each in [x for x in data if isinstance(x, Section) and x.command not in masked_sections]:
        out.write(f"yosys> {each.command}\n")
        out.write(f"{each.data}\n")
    return out.getvalue()

def main(left: Path,
         right: Path,
         hide_clean: bool,
         remainder_args: Optional[List[str]] = None) -> None:
    if not left.is_file():
        print("left must be file. exiting")
        sys.exit(1)
    if not right.is_file():
        print("right must be file. exiting")
        sys.exit(1)
    left_data = left.read_text()
    right_data = right.read_text()

    masked_sections: List[str] = list()
    if hide_clean:
        masked_sections.append("clean")
    sanitized_left_sections = format_yosys_log(left_data)
    sanitized_right_sections = format_yosys_log(right_data)
    sanitized_left = assemble_content(data=sanitized_left_sections, masked_sections=masked_sections)
    sanitized_right = assemble_content(data=sanitized_right_sections, masked_sections=masked_sections)
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
    PARSER.add_argument('--hide-clean',
                        dest="hide_clean",
                        action="store_true",
                        help="use this to hide clean command")
    ARGS, REMAINDER = PARSER.parse_known_args()

    try:
        main(**vars(ARGS), remainder_args=REMAINDER)
    except BrokenPipeError:
        pass
