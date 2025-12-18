# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
import json

with open("build/yosys_pre.json") as f:
    netlist = json.load(f)

mod = netlist["modules"]["clock_divider"]
wires = set(mod["netnames"].keys())
driven = set()

# Look for connects
for conn in mod.get("connections", []):
    driven.update([sig["bits"][0] for sig in conn[:1]])  # LHS only

# Look for cell outputs
for cell in mod.get("cells", {}).values():
    for port, desc in cell["port_directions"].items():
        if desc == "output":
            bits = cell["connections"][port]
            driven.update(bits)

undriven = wires - driven
print("Undriven wires:", undriven)