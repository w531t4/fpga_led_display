from pathlib import Path
from typing import List
import sys
import re

def get_rows_matching_content_in_termlist(data: List[str], termlist: List[str]) -> List[str]:
    hits: List[str] = list()
    for term in termlist:
        for row in data:
            if term in row:
                hits.append(row)
    return hits

def look_for_tokens_in_row(row: str) -> List[str]:
    matches = re.findall(r'_\d+_', row)
    return matches

def get_matching_terms(data: List[str], termlist: List[str]) -> List[str]:
    rows_matching_string = get_rows_matching_content_in_termlist(data, termlist)
    # print(f"rows_matching_string={rows_matching_string}")
    hidden_wires: List[str] = list()
    for each in rows_matching_string:
        hidden_wires.extend(look_for_tokens_in_row(each))
    # print(f"hidden_wires={hidden_wires}")
    total_terms = set(termlist).union(set(hidden_wires))
    # print(f"total_terms={total_terms}")
    if not total_terms == set(termlist):
        return list(get_matching_terms(data, list(total_terms)))
    else:
        return list(total_terms)

def print_rows_matching_terms(data: List[str], termlist: List[str]) -> List[str]:
    outdata = list()
    for _, item in enumerate(data):
        if any([x for x in termlist if x in item]):
            outdata.append(item)
    return outdata

def main() -> None:
    if len(sys.argv) == 1:
        print("must provide param")
        sys.exit(1)
    file = Path(sys.argv[1])
    data = file.read_text()
    rows = data.split("\n")
    if len(sys.argv) <= 2:
        print("must provide search param")
        sys.exit(1)
    string_to_match = sys.argv[2]

    terms = get_matching_terms(data=rows, termlist=[string_to_match])
    output = print_rows_matching_terms(data=rows, termlist=terms)
    for each in output:
        print(each)
    print(f"reduction:: orig={len(rows)} new={len(output)}")
if __name__ == "__main__":
    main()
