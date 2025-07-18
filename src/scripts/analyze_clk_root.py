import json
import sys

def load_timing_report(filename):
    with open(filename, 'r') as f:
        data = json.load(f)
        print("Top-level keys in timing report:", list(data.keys()))
        return data

def find_paths_by_clock_name(timing_data, clk_name):
    """
    Return all critical paths where the 'from' or 'to' strings mention the given clock name.
    """
    matches = []
    for path in timing_data.get('critical_paths', []):
        from_str = path.get('from', '')
        to_str = path.get('to', '')
        if clk_name in from_str or clk_name in to_str:
            matches.append(path)
    return matches

def print_critical_path(path, index=0):
    print(f"\n[{index}] Critical path")
    print(f"  From: {path.get('from')}")
    print(f"  To:   {path.get('to')}")
    print(f"  Total delay: {path.get('delay', 0):.2f} ns")
    print("  Path elements (sorted by delay):")

    sorted_elements = sorted(path['path'], key=lambda x: -x['delay'])
    for elem in sorted_elements:
        delay = elem.get('delay', 0)
        kind = elem.get('type', 'UNKNOWN')
        from_cell = elem.get('from', {}).get('cell', '<none>')
        to_cell = elem.get('to', {}).get('cell', '<none>')
        print(f"    {kind:6} {delay:6.2f} ns  {from_cell} → {to_cell}")

def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: python analyze_clk_paths.py timing_report.json [clock_name]")
        sys.exit(1)

    filename = sys.argv[1]
    clk_name = sys.argv[2] if len(sys.argv) == 3 else "$glbnet$clk_root"

    timing_data = load_timing_report(filename)
    paths = find_paths_by_clock_name(timing_data, clk_name)

    if not paths:
        print(f"No critical paths found mentioning clock name '{clk_name}' in 'from' or 'to' fields.")
        return

    for i, path in enumerate(paths[:5]):
        print_critical_path(path, i)

if __name__ == "__main__":
    main()
