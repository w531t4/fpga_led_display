# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

MAKE_DEPS := Makefile $(wildcard mk/*.mk)

include mk/config.mk

# Ensure depfile includes don't override the default goal.
.DEFAULT_GOAL := all

include mk/sources.mk

include mk/verilator.mk



.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack restore restore-build verilator_argfiles
.DELETE_ON_ERROR:
.SECONDARY: $(SIMBINS)
all: verilator_argfiles simulation lint
#$(warning In a command script $(SIMBINS))


$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)
	mkdir -p $(INTERFACE_DIR)

$(SIMULATION_DIR):
	mkdir -p $(SIMULATION_DIR)

$(SIM_BIN_DIR):
	mkdir -p $(SIM_BIN_DIR)

$(SIM_OBJ_DIR):
	mkdir -p $(SIM_OBJ_DIR)

$(DEPDIR):
	mkdir -p $(DEPDIR)

clean:
	rm -rf $(ARTIFACT_DIR)
ifneq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)),)
	YOSYS_PATH=$(abspath oss-cad-suite) $(MAKE) -C depends/yosys_ecp5_infer_bram_outreg clean
endif

include mk/yosys.mk


include mk/diagram.mk


include mk/ecp5.mk



restore: restore-build
	$(TOOLPATH)/fujprog $(ARTIFACT_DIR)/passthru/ulx3s_passthru_wifi.bit

restore-build:
	$(MAKE) -f $(SRC_DIR)/passthru/Makefile all

gamma_lut: $(GAMMA_INCLUDES)

$(VINCLUDE_DIR)/memory/%.svh: $(VINCLUDE_DIR)/memory/%.mem $(SRC_DIR)/scripts/gen_gamma_svh.py
	python3 $(SRC_DIR)/scripts/gen_gamma_svh.py "$<" "$@"
