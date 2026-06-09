# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

$(ARTIFACT_DIR)/netlist_hier.svg: $(ARTIFACT_DIR)/mydesign_hier.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@

diagram_hier: $(ARTIFACT_DIR)/netlist_hier.svg
diagram: diagram_hier ## Render default usable netlistsvg diagram
