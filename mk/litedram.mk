# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

LITEDRAM_DIR := $(ARTIFACT_DIR)/litedram
LITEDRAM_CONFIG := $(SRC_DIR)/litedram/ulx3s_sdram.yml
LITEDRAM_NAME := ulx3s_litedram
LITEDRAM_GATEWARE := $(LITEDRAM_DIR)/gateware/$(LITEDRAM_NAME).v
LITEDRAM_SMOKE_JSON := $(LITEDRAM_DIR)/$(LITEDRAM_NAME).json
LITEDRAM_WRAPPER_JSON := $(LITEDRAM_DIR)/ulx3s_litedram_wrapper.json
LITEDRAM_MAIN_SMOKE_STAMP := $(LITEDRAM_DIR)/main_litedram.ok
LITEDRAM_WRAPPER_SOURCES := $(SRC_DIR)/litedram/litedram_init.sv \
                           $(SRC_DIR)/litedram/ulx3s_litedram_wrapper.sv
LITEDRAM_MAIN_SOURCES := $(filter-out $(SRC_DIR)/litedram/ulx3s_litedram_wrapper.sv $(LITEDRAM_GATEWARE),$(VSOURCES)) \
                        $(SRC_DIR)/litedram/ulx3s_litedram_wrapper.sv \
                        $(LITEDRAM_GATEWARE)
# Generated LiteDRAM RTL is Verilog; keep read_slang focused on project SystemVerilog.
LITEDRAM_MAIN_READSLANG_SOURCES := $(filter-out $(LITEDRAM_GATEWARE),$(LITEDRAM_MAIN_SOURCES))
LITEDRAM_DEPS := $(LITEDRAM_CONFIG) .python-requirements .python-version $(MAKE_DEPS)

ifeq ($(findstring -DUSE_LITEDRAM,$(BUILD_FLAGS)),-DUSE_LITEDRAM)
VSOURCES += $(SRC_DIR)/litedram/ulx3s_litedram_wrapper.sv $(LITEDRAM_GATEWARE)
endif

.PHONY: litedram litedram-smoke litedram-wrapper-smoke litedram-main-smoke
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

litedram-wrapper-smoke: $(LITEDRAM_WRAPPER_JSON) ## Check project LiteDRAM wrapper with Yosys

$(LITEDRAM_WRAPPER_JSON): $(LITEDRAM_GATEWARE) $(LITEDRAM_WRAPPER_SOURCES) $(MAKE_DEPS) | $(LITEDRAM_DIR)
	timeout 30s $(TOOLPATH)/yosys -q -L $(LITEDRAM_DIR)/yosys_litedram_wrapper.log \
		-p "read_verilog -lib +/ecp5/cells_sim.v; read_verilog -sv $(LITEDRAM_GATEWARE) $(LITEDRAM_WRAPPER_SOURCES); hierarchy -check -top ulx3s_litedram_wrapper; synth_ecp5 -top ulx3s_litedram_wrapper; write_json $@"


litedram-main-smoke: $(LITEDRAM_MAIN_SMOKE_STAMP) ## Check main elaborates with guarded LiteDRAM wrapper

$(LITEDRAM_MAIN_SMOKE_STAMP): $(LITEDRAM_MAIN_SOURCES) $(INCLUDESRCS) $(MAKE_DEPS) | $(LITEDRAM_DIR)
	timeout 30s $(TOOLPATH)/yosys -q -L $(LITEDRAM_DIR)/yosys_main_litedram.log \
		-p "read_verilog -lib +/ecp5/cells_sim.v; read_verilog -sv $(LITEDRAM_GATEWARE); read_slang $(BUILD_FLAGS) -DUSE_LITEDRAM -I$(VINCLUDE_DIR) -I$(VINCLUDE_MEM_DIR) $(LITEDRAM_MAIN_READSLANG_SOURCES); hierarchy -check -top main" \
		-m slang
	touch $@
