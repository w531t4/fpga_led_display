# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
SIM_BIN_DIR:=$(ARTIFACT_DIR)/verilator_bin
SIM_OBJ_DIR:=$(ARTIFACT_DIR)/verilator_obj
SIMULATION_DIR_ABS:=$(abspath $(SIMULATION_DIR))
SIM_BIN_DIR_ABS:=$(abspath $(SIM_BIN_DIR))
# Dependency files for per-testbench rebuilds.
DEPDIR:=$(ARTIFACT_DIR)/deps
SRC_DIR:=src
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints
VINCLUDE_DIR:=$(SRC_DIR)/include
CCACHE_DIR ?= $(abspath .ccache)
export CCACHE_DIR

# Ensure depfile includes don't override the default goal.
.DEFAULT_GOAL := all

# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations
# DEBUGGER - enable UART TX debugger (for use with src/scripts/uart_rx.py)
# W128 - enable 128 pixel width
# FOCUS_TB_MAIN_UART - limit main testbench to include only signals applicable to uart debugging
# SPI - use SPI for data ingress instead of a UART
# SPI_ESP32 - must also specify SPI. Uses esp32 pinout
# CLK_110 - Use 110Mhz clock for clk_root
# CLK_100 - Use 100MHz clock for clk_root
# CLK_90 - Use 90MHz clock for clk_root
# CLK_80 - Use 90MHz clock for clk_root
# CLK_50 - Use 50MHz clock for clk_root
# RGB24 - Use RGB24 instead of RGB565
# GAMMA - Enable Gamma Correction
# USE_BOARDLEDS_BRIGHTNESS - Use development board led's to show brightness levels
# DOUBLE_BUFFER - Allow image to be written to one buffer while displaying the other buffer at led's.
# USE_INFER_BRAM_PLUGIN - Compile and use Yosys plugin to assist with inferring OUTREG for BRAM's
# USE_WATCHDOG - Requires recurring command sequence to be present, otherwise board resets
# SWAP_BLUE_GREEN_CHAN - Swaps the pins for blue/green channels (see Adafruit note about "...green and blue channels are swapped..
#				         .with the 2.5mm pitch 64x32 display..." https://www.adafruit.com/product/5036)

BUILD_FLAGS ?=-DSPI -DGAMMA -DCLK_90 -DW128 -DRGB24 -DSPI_ESP32 -DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN -DSWAP_BLUE_GREEN_CHAN
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=depends/netlistsvg/node_modules/netlistsvg/bin/netlistsvg.js
PKG_SOURCES := $(SRC_DIR)/params.sv $(SRC_DIR)/calc.sv $(SRC_DIR)/cmd.sv $(SRC_DIR)/types.sv
VSOURCES := $(sort $(shell find $(SRC_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
VSOURCES := $(PKG_SOURCES) $(filter-out $(PKG_SOURCES), $(VSOURCES))
VSOURCES_WITHOUT_PKGS := $(filter-out $(PKG_SOURCES),$(VSOURCES))
TBSRCS := $(sort $(shell find $(TB_DIR) -name '*.sv' -or -name '*.v'))
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
VERILATOR_FILEPARAM_ARGS = $(SIM_FLAGS) \
						   $(VERILATOR_ADDITIONAL_ARGS) \
						   $(abspath $(PKG_SOURCES)) \
						   -y $(abspath $(SRC_DIR)) \
						   $(abspath $(VSOURCES_WITHOUT_PKGS)) \
						   $(abspath $(TBSRCS))

VERILATOR_SIM_SRC_FILES:=$(abspath $(PKG_SOURCES)) \
						 $(abspath $(VSOURCES_WITHOUT_PKGS))

VERILATOR_SIMONLY_FLAGS:=--binary --trace-fst --trace-structs \
						 -j $(SIM_JOBS) \
					 	 -MAKEFLAGS "-j $(SIM_JOBS) $(VERILATOR_SIM_MAKEFLAGS)"
VERILATOR_LINTONLY_FLAGS:=--lint-only

VERILATOR_SIM_FLAGS:= $(VERILATOR_SIMONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -I$(VINCLUDE_DIR) \
 					  $(SIM_FLAGS) \
					  $(VERILATOR_ADDITIONAL_ARGS)

VERILATOR_LINT_FLAGS:=$(VERILATOR_LINTONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -I$(VINCLUDE_DIR) \
					  -f $(ARTIFACT_DIR)/verilator_args


VERILATOR_SIM_CMD := $(VERILATOR_BIN) $(VERILATOR_SIM_FLAGS)
VERILATOR_LINT_CMD := $(VERILATOR_BIN) $(VERILATOR_LINT_FLAGS)
INCLUDESRCS := $(sort $(shell find $(VINCLUDE_DIR) -name '*.vh' -or -name '*.svh'))
GAMMA_MEMS := $(SRC_DIR)/memory/gamma_5bit.mem $(SRC_DIR)/memory/gamma_6bit.mem $(SRC_DIR)/memory/gamma_8bit.mem
GAMMA_INCLUDES := $(patsubst $(SRC_DIR)/memory/%.mem,$(VINCLUDE_DIR)/%.svh,$(GAMMA_MEMS))
SIMBINS:=$(subst tb_,, $(subst $(TB_DIR), $(SIM_BIN_DIR), $(TBSRCS:%.sv=%)))
FSTOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.fst)))
TB_ARGS_FILES := $(wildcard $(TB_DIR)/tb_*.args)
SIM_RUN_ARGS ?= +verilator+quiet
SIM_JOBS ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
ifneq ($(filter --jobserver%,$(MAKEFLAGS)),)
SIM_MAKEFLAGS :=
else
SIM_MAKEFLAGS := -j $(SIM_JOBS)
endif

ifneq ($(findstring -DSPI,$(BUILD_FLAGS)), -DSPI)
VSOURCES := $(filter-out $(SRC_DIR)/spi_master.sv, $(VSOURCES))
VSOURCES := $(filter-out $(SRC_DIR)/spi_slave.sv, $(VSOURCES))
endif

ifneq ($(findstring -DUSE_WATCHDOG,$(BUILD_FLAGS)), -DUSE_WATCHDOG)
VSOURCES := $(filter-out $(SRC_DIR)/control_cmd_watchdog.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_control_cmd_watchdog.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/control_cmd_watchdog, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/control_cmd_watchdog.fst, $(FSTOBJS))
endif

ifneq ($(findstring -DUSE_FM6126A,$(BUILD_FLAGS)), -DUSE_FM6126A)
VSOURCES := $(filter-out $(SRC_DIR)/fm6126init.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_fm6126init.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/fm6126init, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.fst, $(FSTOBJS))
endif

.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack restore restore-build
.DELETE_ON_ERROR:
.SECONDARY: $(SIMBINS)
all: $(ARTIFACT_DIR)/verilator_args simulation lint
#$(warning In a command script $(SIMBINS))

$(SIMULATION_DIR)/%.fst: $(SIM_BIN_DIR)/% Makefile | $(SIMULATION_DIR)
	@set -o pipefail; stdbuf -oL -eL $< $(SIM_RUN_ARGS) 2>&1 | sed -u 's/^/[$*] /'

$(SIM_BIN_DIR)/%: $(TB_DIR)/tb_%.sv $(PKG_SOURCES) $(VSOURCES_WITHOUT_PKGS) $(INCLUDESRCS) Makefile | $(SIM_BIN_DIR) $(SIM_OBJ_DIR)
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

$(ARTIFACT_DIR)/verilator_args: $(ARTIFACT_DIR) $(PKG_SOURCES) Makefile
	@printf '%s' '$(VERILATOR_FILEPARAM_ARGS)' > $@

lint: $(ARTIFACT_DIR) $(ARTIFACT_DIR)/verilator_args
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
	(cd depends/yosys_ecp5_infer_bram_outreg/;  YOSYS_PATH=../../oss-cad-suite/ make)

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

YOSYS_READSLANG_ARGS:=$(BUILD_FLAGS) -I$(VINCLUDE_DIR) ${VSOURCES}
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_READSLANG_ARGS:=--diag-source --diag-location --diag-include-stack $(YOSYS_READSLANG_ARGS)
endif
YOSYS_READSLANG_CMD:=read_slang $(YOSYS_READSLANG_ARGS)

YOSYS_SYNTHECP5_CMD:=synth_ecp5 -top main -json $(ARTIFACT_DIR)/mydesign.json

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

compile: lint $(ARTIFACT_DIR)/mydesign.json
$(YOSYS_TARGETS): $(GAMMA_INCLUDES) ${VSOURCES} $(INCLUDESRCS) Makefile  $(if $(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)),depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so) | $(ARTIFACT_DIR)
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

simulation:
	+@$(MAKE) --no-print-directory $(SIM_MAKEFLAGS) $(FSTOBJS)

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
	$(TOOLPATH)/fujprog $(ARTIFACT_DIR)/passthru/ulx3s_esp32_passthru.bit

restore-build:
	$(MAKE) -f $(SRC_DIR)/passthru/Makefile all

gamma_lut: $(GAMMA_INCLUDES)

$(VINCLUDE_DIR)/%.svh: $(SRC_DIR)/memory/%.mem $(SRC_DIR)/scripts/gen_gamma_svh.py
	python3 $(SRC_DIR)/scripts/gen_gamma_svh.py "$<" "$@"
