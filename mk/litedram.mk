# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

LITEDRAM_DIR := $(ARTIFACT_DIR)/litedram
LITEDRAM_CONFIG := $(SRC_DIR)/litedram/ulx3s_sdram.yml
LITEDRAM_NAME := ulx3s_litedram
LITEDRAM_GATEWARE := $(LITEDRAM_DIR)/gateware/$(LITEDRAM_NAME).v
LITEDRAM_SMOKE_JSON := $(LITEDRAM_DIR)/$(LITEDRAM_NAME).json
LITEDRAM_DEPS := $(LITEDRAM_CONFIG) .python-requirements .python-version $(MAKE_DEPS)

.PHONY: litedram litedram-smoke
litedram: $(LITEDRAM_GATEWARE) ## Generate LiteDRAM standalone gateware

$(LITEDRAM_DIR):
	mkdir -p $@

# Keep generated RTL under build/. The YAML and dependency pins are the stable inputs;
# this rule should be cheap enough to run during devcontainer bootstrap.
$(LITEDRAM_GATEWARE): $(LITEDRAM_DEPS) | $(LITEDRAM_DIR)
	timeout 30s litedram_gen --no-compile \
		--name $(LITEDRAM_NAME) \
		--output-dir $(LITEDRAM_DIR) \
		$(LITEDRAM_CONFIG)

litedram-smoke: $(LITEDRAM_SMOKE_JSON) ## Check generated LiteDRAM gateware with Yosys

$(LITEDRAM_SMOKE_JSON): $(LITEDRAM_GATEWARE) $(MAKE_DEPS) | $(LITEDRAM_DIR)
	timeout 30s $(TOOLPATH)/yosys -q -L $(LITEDRAM_DIR)/yosys_litedram.log \
		-p "read_verilog -lib +/ecp5/cells_sim.v; read_verilog -sv $<; hierarchy -check -top $(LITEDRAM_NAME); synth_ecp5 -top $(LITEDRAM_NAME); write_json $@"
