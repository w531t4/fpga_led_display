# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

MAKE_DEPS := Makefile $(wildcard mk/*.mk)

include mk/config.mk

# Ensure depfile includes don't override the default goal.
.DEFAULT_GOAL := all

include mk/sources.mk

VERILATOR_BIN:=$(TOOLPATH)/verilator
VERILATOR_SIM_OPTSLOW ?=
VERILATOR_SIM_OBJCACHE ?= ccache
VERILATOR_SIM_MAKEFLAGS :=
VERILATOR_SIM_MAKEFLAGS += $(if $(strip $(VERILATOR_SIM_OPTSLOW)),OPT_SLOW=$(VERILATOR_SIM_OPTSLOW))
VERILATOR_SIM_MAKEFLAGS += $(if $(strip $(VERILATOR_SIM_OBJCACHE)),OBJCACHE=$(VERILATOR_SIM_OBJCACHE))
VERILATOR_ADDITIONAL_ARGS:=-Wall -Wno-fatal -Wno-TIMESCALEMOD -Wno-MULTITOP --timing --quiet-stats

# VERILATOR_FILEPARAM_ARGS
#	- Contents written to $(ARTIFACT_DIR)/verilator_args
#	- full-paths are required by vscode. otherwise vscode assumes they are in /src
VERILATOR_FILEPARAM_ARGS = -I$(VINCLUDE_DIR) \
						   -I$(VINCLUDE_MEM_DIR) \
						   $(SIM_FLAGS) \
						   $(VERILATOR_ADDITIONAL_ARGS)

VERILATOR_SIM_SRC_FILES:=-f $(ARTIFACT_DIR)/verilator_src_args

VERILATOR_SIMONLY_FLAGS:=--binary --trace-fst --trace-structs \
						 -j $(SIM_JOBS) \
					 	 -MAKEFLAGS "-j $(SIM_JOBS) $(VERILATOR_SIM_MAKEFLAGS)"
VERILATOR_LINTONLY_FLAGS:=--lint-only

# -- VERILATOR_SIM_FLAGS: Note: VERILATOR_SIM_SRC_FILES is specified later in the target below. TBSRCS aren't included
#								because the intent is to scope the lint to just that simulation.
VERILATOR_SIM_FLAGS:= $(VERILATOR_SIMONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -f $(ARTIFACT_DIR)/verilator_args

VERILATOR_LINT_FLAGS:=$(VERILATOR_LINTONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -f $(ARTIFACT_DIR)/verilator_args \
					  -f $(ARTIFACT_DIR)/verilator_src_args \
					  -f $(ARTIFACT_DIR)/verilator_tbsrc_args


VERILATOR_SIM_CMD := $(VERILATOR_BIN) $(VERILATOR_SIM_FLAGS)
VERILATOR_LINT_CMD := $(VERILATOR_BIN) $(VERILATOR_LINT_FLAGS)
SIM_RUN_ARGS ?= +verilator+quiet
SIM_JOBS ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
ifneq ($(filter --jobserver%,$(MAKEFLAGS)),)
SIM_MAKEFLAGS :=
else
SIM_MAKEFLAGS := -j $(SIM_JOBS)
endif


.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack restore restore-build verilator_argfiles
.DELETE_ON_ERROR:
.SECONDARY: $(SIMBINS)
all: verilator_argfiles simulation lint
#$(warning In a command script $(SIMBINS))

$(SIMULATION_DIR)/%.fst: $(SIM_BIN_DIR)/% Makefile | $(SIMULATION_DIR)
	@set -o pipefail; stdbuf -oL -eL $< $(SIM_RUN_ARGS) 2>&1 | sed -u 's/^/[$*] /'

$(SIM_BIN_DIR)/%: $(TB_DIR)/tb_%.sv $(VSOURCES) $(INCLUDESRCS) Makefile | $(SIM_BIN_DIR) $(SIM_OBJ_DIR)
	@tb_args_file=$(TB_DIR)/tb_$*.args; \
	tb_args=""; \
	if [ -f $$tb_args_file ]; then \
		tb_args="$$(tr '\n' ' ' < $$tb_args_file)"; \
	fi; \
	$(VERILATOR_SIM_CMD) $$tb_args \
		--top-module tb_$* \
		-Mdir $(SIM_OBJ_DIR)/obj_$* \
		-o $(SIM_BIN_DIR_ABS)/$* \
		-D'DUMP_FILE_NAME="$(SIMULATION_DIR_ABS)/$*.fst"' \
		$(VERILATOR_SIM_SRC_FILES) $<

verilator_argfiles: $(ARTIFACT_DIR)/verilator_args $(ARTIFACT_DIR)/verilator_src_args $(ARTIFACT_DIR)/verilator_tbsrc_args

$(ARTIFACT_DIR)/verilator_args: $(INCLUDESRCS) Makefile | $(ARTIFACT_DIR)
	@printf '%s' '$(VERILATOR_FILEPARAM_ARGS)' > $@

$(ARTIFACT_DIR)/verilator_src_args: $(ARTIFACT_DIR) $(VSOURCES) Makefile | $(ARTIFACT_DIR)
	@printf '%s' '$(abspath $(VSOURCES))' > $@

$(ARTIFACT_DIR)/verilator_tbsrc_args: $(ARTIFACT_DIR) $(TBSRCS) Makefile | $(ARTIFACT_DIR)
	@printf '%s' '$(abspath $(TBSRCS))' > $@

lint: $(ARTIFACT_DIR) verilator_argfiles
	cat $(ARTIFACT_DIR)/verilator_args; printf "\n";
	set -o pipefail; \
	{ \
		$(VERILATOR_LINT_CMD); \
		for tb_args_file in $(TB_ARGS_FILES); do \
			tb_args="$$(tr '\n' ' ' < $$tb_args_file)"; \
			$(VERILATOR_LINT_CMD) $$tb_args; \
		done; \
	} |& python3 $(SRC_DIR)/scripts/parse_lint.py | tee $(ARTIFACT_DIR)/verilator.lint

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

# This plugin is necessary to infer OUTREG in blockram correctly in yosys.
depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so:
	YOSYS_PATH=$(abspath oss-cad-suite) $(MAKE) -C depends/yosys_ecp5_infer_bram_outreg

YOSYS_DEBUG ?= false
YOSYS_INCLUDE_EXTRA ?= false

YOSYS_TARGETS:=$(ARTIFACT_DIR)/mydesign.json \
			   $(ARTIFACT_DIR)/mydesign.il \
			   $(ARTIFACT_DIR)/mydesign_show.dot
YOSYS_EXTRA:=hierarchy -check -top main;
ifeq ($(YOSYS_INCLUDE_EXTRA),true)
	YOSYS_EXTRA += show -format dot -prefix $(ARTIFACT_DIR)/mydesign_show_pre main;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/mydesign_show_pre.dot
	YOSYS_EXTRA += ls;
	YOSYS_EXTRA += proc -noopt;
	YOSYS_EXTRA += write_rtlil $(ARTIFACT_DIR)/mydesign_pre.il;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/mydesign_pre.il
	YOSYS_EXTRA += write_json $(ARTIFACT_DIR)/mydesign_pre.json;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/mydesign_pre.json
	YOSYS_EXTRA += write_verilog $(ARTIFACT_DIR)/code_preopt.sv;
	YOSYS_TARGETS +=  $(ARTIFACT_DIR)/code_preopt.sv
	YOSYS_EXTRA += write_verilog -selected $(ARTIFACT_DIR)/code_preopt_selected.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_preopt_selected.sv
	YOSYS_EXTRA += opt_expr -full;
	YOSYS_EXTRA += write_verilog $(ARTIFACT_DIR)/code_postopt.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_postopt.sv
	YOSYS_EXTRA += write_verilog -selected $(ARTIFACT_DIR)/code_postopt_selected.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_postopt_selected.sv
endif

YOSYS_READSLANG_ARGS:=$(BUILD_FLAGS) -I$(VINCLUDE_DIR) -I$(VINCLUDE_MEM_DIR) ${VSOURCES}
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_READSLANG_ARGS:=--diag-source --diag-location --diag-include-stack $(YOSYS_READSLANG_ARGS)
endif
YOSYS_READSLANG_CMD:=read_slang $(YOSYS_READSLANG_ARGS)

YOSYS_SYNTHECP5_CMD:=synth_ecp5 -top main

YOSYS_SCRIPT:=
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_SCRIPT +=echo on;
endif
YOSYS_SCRIPT +=$(YOSYS_READSLANG_CMD);
YOSYS_SCRIPT +=$(YOSYS_EXTRA);
YOSYS_SCRIPT +=$(YOSYS_SYNTHECP5_CMD);
ifeq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)), -DUSE_INFER_BRAM_PLUGIN)
	# YOSYS_SCRIPT +=write_verilog -noattr -noexpr $(ARTIFACT_DIR)/code_preblah.sv;
	YOSYS_SCRIPT +=ecp5_infer_bram_outreg;
	# YOSYS_SCRIPT +=write_verilog -noattr -noexpr $(ARTIFACT_DIR)/code_postblah.sv;
endif
# Write JSON after optional BRAM outreg packing so nextpnr sees OUTREG.
YOSYS_SCRIPT +=write_json $(ARTIFACT_DIR)/mydesign.json;
YOSYS_SCRIPT +=show -format dot -prefix $(ARTIFACT_DIR)/mydesign_show;
YOSYS_SCRIPT +=write_rtlil $(ARTIFACT_DIR)/mydesign.il;
YOSYS_SCRIPT +=write_verilog -selected $(ARTIFACT_DIR)/mydesign_final.sv;

YOSYS_CMD_ARGS:=-L $(ARTIFACT_DIR)/yosys.log -p "$(YOSYS_SCRIPT)"
YOSYS_CMD_ARGS += -m slang
ifeq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)), -DUSE_INFER_BRAM_PLUGIN)
YOSYS_CMD_ARGS += -m depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so
endif
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_CMD_ARGS :=-d -v9 -g $(YOSYS_CMD_ARGS)
endif

compile: lint gamma_lut $(ARTIFACT_DIR)/mydesign.json
$(YOSYS_TARGETS): ${VSOURCES} $(INCLUDESRCS) Makefile  $(if $(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)),depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so) | $(ARTIFACT_DIR)
	echo "$(YOSYS_SCRIPT)" > $(ARTIFACT_DIR)/mydesign.ys
	$(TOOLPATH)/yosys $(YOSYS_CMD_ARGS)

loopviz: $(ARTIFACT_DIR)/mydesign_show.svg
$(ARTIFACT_DIR)/mydesign_show.svg: $(ARTIFACT_DIR)/mydesign_show.dot | $(ARTIFACT_DIR)
	$(TOOLPATH)/dot -Kdot -o $@ -Tsvg $<

loopviz_pre: $(ARTIFACT_DIR)/mydesign_show_pre.svg
$(ARTIFACT_DIR)/mydesign_show_pre.svg: $(ARTIFACT_DIR)/mydesign_show_pre.dot | $(ARTIFACT_DIR)
	$(TOOLPATH)/dot -Kdot -o $@ -Tsvg $<

route: $(ARTIFACT_DIR)/ulx3s_out.config
$(ARTIFACT_DIR)/ulx3s_out.config: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	$(TOOLPATH)/nextpnr-ecp5 --85k --json $< \
		--lpf $(CONSTRAINTS_DIR)/ulx3s_v316.lpf \
		--log $(ARTIFACT_DIR)/nextpnr.log \
		--package CABGA381 \
		--randomize-seed \
		--report $(ARTIFACT_DIR)/nextpnr-report.json \
		--placer-heap-critexp 3 --placer-heap-timingweight 20 \
		--detailed-timing-report \
		--textcfg $@
	python3 -m json.tool $(ARTIFACT_DIR)/nextpnr-report.json > $(ARTIFACT_DIR)/nextpnr-report.pretty.json
pack: $(ARTIFACT_DIR)/ulx3s.bit | $(ARTIFACT_DIR)
$(ARTIFACT_DIR)/ulx3s.bit: $(ARTIFACT_DIR)/ulx3s_out.config | $(ARTIFACT_DIR)
	$(TOOLPATH)/ecppack $< $@

memprog: $(ARTIFACT_DIR)/ulx3s.bit
	@echo ====YOSYS WARNINGS/ERRORS==== | tee $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i -e warning -e error $(ARTIFACT_DIR)/yosys.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====YOSYS Removed Unused Modules==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep "Removing unused module" $(ARTIFACT_DIR)/yosys.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====NEXTPNR WARNINGS/ERRORS==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i -e warning -e error $(ARTIFACT_DIR)/nextpnr.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====CLOCKS==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i "Info: Max frequency for clock" $(ARTIFACT_DIR)/nextpnr.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt


	$(TOOLPATH)/fujprog $<

simulation: $(ARTIFACT_DIR) verilator_argfiles
	@# Capture simulation output so errors can be summarized at the end on failure.
	@set -o pipefail; \
	log="$(ARTIFACT_DIR)/simulation.log"; \
	$(MAKE) --no-print-directory $(SIM_MAKEFLAGS) $(FSTOBJS) 2>&1 | tee $$log; \
	status=$${PIPESTATUS[0]}; \
	if [ $$status -ne 0 ]; then \
		echo; \
		echo "==== SIMULATION ERRORS (summary) ===="; \
		grep -n -E "%Error|%Warning|^make(\\[[0-9]+\\])?: \\*\\*\\*" $$log || true; \
		exit $$status; \
	fi

$(ARTIFACT_DIR)/mydesign_vizclean.json: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@

$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/mydesign_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@

ifeq ($(YOSYS_INCLUDE_EXTRA),true)
$(ARTIFACT_DIR)/mydesign_pre_vizclean.json: $(ARTIFACT_DIR)/mydesign_pre.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@

$(ARTIFACT_DIR)/netlist_pre.svg: $(ARTIFACT_DIR)/mydesign_pre_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@
endif

DIAGRAM_TARGETS:=$(ARTIFACT_DIR)/netlist.svg
DIAGRAM_TARGETS += $(if $(filter true,$(YOSYS_INCLUDE_EXTRA)),$(ARTIFACT_DIR)/netlist_pre.svg)

diagram: $(DIAGRAM_TARGETS)

restore: restore-build
	$(TOOLPATH)/fujprog $(ARTIFACT_DIR)/passthru/ulx3s_passthru_wifi.bit

restore-build:
	$(MAKE) -f $(SRC_DIR)/passthru/Makefile all

gamma_lut: $(GAMMA_INCLUDES)

$(VINCLUDE_DIR)/memory/%.svh: $(VINCLUDE_DIR)/memory/%.mem $(SRC_DIR)/scripts/gen_gamma_svh.py
	python3 $(SRC_DIR)/scripts/gen_gamma_svh.py "$<" "$@"
