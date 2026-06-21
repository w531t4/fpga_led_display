# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

LITEDRAM_DIR := $(ARTIFACT_DIR)/litedram
LITEDRAM_CONFIG := $(SRC_DIR)/litedram/ulx3s_sdram.yml
LITEDRAM_NAME := ulx3s_litedram
LITEDRAM_GATEWARE := $(LITEDRAM_DIR)/gateware/$(LITEDRAM_NAME).v
# Simulation variant of the core (`litedram_gen --sim`): the real ECP5 PHY is
# swapped for a behavioral SDRAMPHYModel, so this RTL has no vendor primitives
# and is what Verilator compiles. Same wb_ctrl + native port as the real core.
LITEDRAM_SIM_NAME := ulx3s_litedram_sim
LITEDRAM_SIM_GATEWARE := $(LITEDRAM_DIR)/gateware/$(LITEDRAM_SIM_NAME).v
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
LITEDRAM_MAIN_SMOKE_FLAGS ?= -DUSE_LITEDRAM_BIST

ifeq ($(findstring -DUSE_LITEDRAM,$(BUILD_FLAGS)),-DUSE_LITEDRAM)
# Synthesis (yosys/nextpnr, no -DSIM) sees the wrapper + REAL core.
VSOURCES += $(SRC_DIR)/litedram/ulx3s_litedram_wrapper.sv $(LITEDRAM_GATEWARE)
# Verilator (lint/simulation, -DSIM) can't model the real core's ECP5
# primitives, so swap it for the SIM core there. The wrapper's `ifdef SIM`
# already selects ulx3s_litedram_sim, so this just makes the right .v available
# to Verilator and keeps the vendor RTL out of its reach (no MODMISSING).
VERILATOR_EXCLUDE_SOURCES += $(LITEDRAM_GATEWARE)
VERILATOR_EXTRA_SOURCES   += $(LITEDRAM_SIM_GATEWARE)
else
# The sim-core bring-up tb only makes sense when the wrapper is in the build.
TBSRCS  := $(filter-out $(TB_DIR)/tb_litedram_wrapper_sim.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/litedram_wrapper_sim, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/litedram_wrapper_sim.fst, $(FSTOBJS))
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

# `litedram_gen --sim` pulls in litex_sim (liteeth/tapcfg) and trips on a
# software-side import *after* the gateware Verilog is already written -- with
# --no-compile that step is irrelevant, so tolerate the non-zero exit and fail
# only if the .v didn't appear. rm-first so a real early failure can't leave a
# stale core looking valid.
$(LITEDRAM_SIM_GATEWARE): $(LITEDRAM_DEPS) | $(LITEDRAM_DIR)
	rm -f $@
	-timeout 60s litedram_gen --no-compile --sim \
		--name $(LITEDRAM_SIM_NAME) \
		--output-dir $(LITEDRAM_DIR) \
		$(LITEDRAM_CONFIG)
	@test -s $@ || { echo "litedram_gen --sim did not produce $@ (is liteeth installed?)"; exit 1; }

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
		-p "read_verilog -lib +/ecp5/cells_sim.v; read_verilog -sv $(LITEDRAM_GATEWARE); read_slang --top main $(BUILD_FLAGS) -DUSE_LITEDRAM $(LITEDRAM_MAIN_SMOKE_FLAGS) -I$(VINCLUDE_DIR) -I$(VINCLUDE_MEM_DIR) $(LITEDRAM_MAIN_READSLANG_SOURCES); hierarchy -check -top main" \
		-m slang
	touch $@
