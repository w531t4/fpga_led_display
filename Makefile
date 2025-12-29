# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
# Dependency files for per-testbench rebuilds (generated via iverilog -M).
DEPDIR:=$(ARTIFACT_DIR)/deps
SRC_DIR:=src
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints
VINCLUDE_DIR:=$(SRC_DIR)/include

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
# CLK_50 - Use 50MHz clock for clk_root
# RGB24 - Use RGB24 instead of RGB565
# GAMMA - Enable Gamma Correction
# USE_BOARDLEDS_BRIGHTNESS - Use development board led's to show brightness levels
# DOUBLE_BUFFER - Allow image to be written to one buffer while displaying the other buffer at led's.
# USE_INFER_BRAM_PLUGIN - Compile and use Yosys plugin to assist with inferring OUTREG for BRAM's
# USE_WATCHDOG - Requires recurring command sequence to be present, otherwise board resets

BUILD_FLAGS ?=-DSPI -DGAMMA -DCLK_90 -DW128 -DRGB24 -DSPI_ESP32 -DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=depends/netlistsvg/node_modules/netlistsvg/bin/netlistsvg.js
IVERILOG_BIN:=$(TOOLPATH)/iverilog
IVERILOG_FLAGS:=-g2012 -Wanachronisms -Wimplicit -Wmacro-redefinition -Wmacro-replacement -Wportbind -Wselect-range -Winfloop -Wsensitivity-entire-vector -Wsensitivity-entire-array -I$(VINCLUDE_DIR) -y $(SRC_DIR) -Y .sv -Y .v
# -y/-Y let iverilog resolve module files under src/, enabling dependency discovery.
VVP_BIN:=$(TOOLPATH)/vvp
VVP_FLAGS:=-n -N
GTKWAVE_BIN:=gtkwave
GTKWAVE_FLAGS:=
VERILATOR_BIN:=$(TOOLPATH)/verilator
VERILATOR_FLAGS:=--lint-only -Wno-fatal -Wall -Wno-TIMESCALEMOD -sv -y $(SRC_DIR) -I$(VINCLUDE_DIR) -f build/verilator_args

VSOURCES := $(sort $(shell find $(SRC_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
PKG_SOURCES := $(SRC_DIR)/params_pkg.sv $(SRC_DIR)/calc_pkg.sv
VSOURCES := $(PKG_SOURCES) $(filter-out $(PKG_SOURCES), $(VSOURCES))

INCLUDESRCS := $(sort $(shell find $(VINCLUDE_DIR) -name '*.vh'))
TBSRCS := $(sort $(shell find $(TB_DIR) -name '*.sv' -or -name '*.v'))
VVPOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vvp)))
VCDOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vcd)))
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
VVPOBJS := $(filter-out $(SIMULATION_DIR)/control_cmd_watchdog.vvp, $(VVPOBJS))
VCDOBJS := $(filter-out $(SIMULATION_DIR)/control_cmd_watchdog.vcd, $(VCDOBJS))
endif

ifneq ($(findstring -DUSE_FM6126A,$(BUILD_FLAGS)), -DUSE_FM6126A)
VSOURCES := $(filter-out $(SRC_DIR)/fm6126init.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_fm6126init.sv, $(TBSRCS))
VVPOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.vvp, $(VVPOBJS))
VCDOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.vcd, $(VCDOBJS))
endif

# Include per-testbench deps so only affected TBs rebuild on source changes.
# Skip dep includes for clean to avoid forcing dep generation.
ifneq ($(filter clean,$(MAKECMDGOALS)),clean)
DEPFILES := $(VVPOBJS:$(SIMULATION_DIR)/%.vvp=$(DEPDIR)/%.d)
# Drop stale depfiles that reference removed sources so make can regenerate them.
#	$$f <-- actualy bash $f
#	the - in front of include makes the depfiles non-fatal
$(shell \
	for f in $(DEPFILES); do \
		[ -f $$f ] || continue; \
		for dep in $$(sed 's/^[^:]*: *//' $$f); do \
			[ -e $$dep ] || { printf 'removing stale depfile: %s\n' $$f; rm -f $$f; break; }; \
		done; \
	done)
-include $(DEPFILES)
endif



.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack esp32 esp32_build esp32_flash restore restore-build
.DELETE_ON_ERROR:
all: $(ARTIFACT_DIR)/verilator_args simulation lint
#$(warning In a command script $(VVPOBJS))

$(SIMULATION_DIR)/%.vcd: $(SIMULATION_DIR)/%.vvp Makefile | $(SIMULATION_DIR)
	@set -o pipefail; stdbuf -oL -eL $(VVP_BIN) $(VVP_FLAGS) $< 2>&1 | sed -u 's/^/[$*] /'

$(SIMULATION_DIR)/%.vvp $(DEPDIR)/%.d: $(TB_DIR)/tb_%.sv Makefile | $(SIMULATION_DIR) $(DEPDIR)
#	$(info In a command script)
# Generate dep list from iverilog and translate it into a Makefile .d file.
	$(IVERILOG_BIN) $(SIM_FLAGS) $(IVERILOG_FLAGS) -s tb_$(*F) -D'DUMP_FILE_NAME="$(SIMULATION_DIR)/$*.vcd"' -M $(DEPDIR)/$*.deps -o $(SIMULATION_DIR)/$*.vvp $(PKG_SOURCES) $<
	@printf '%s: ' '$(SIMULATION_DIR)/$*.vvp' > $(DEPDIR)/$*.d
	@tr '\n' ' ' < $(DEPDIR)/$*.deps >> $(DEPDIR)/$*.d
	@printf '\n' >> $(DEPDIR)/$*.d
	@# Append dummy targets for each dependency so removed files don't break make.
	@for dep in $$(sed 's/^[^:]*: *//' $(DEPDIR)/$*.d); do \
		printf '%s:\n' $$dep >> $(DEPDIR)/$*.d; \
	done

$(ARTIFACT_DIR)/verilator_args: $(ARTIFACT_DIR) $(PKG_SOURCES) Makefile
	@printf '%s %s %s %s\n' '$(SIM_FLAGS)' '$(PKG_SOURCES)' '-y $(SRC_DIR)' '-I$(VINCLUDE_DIR)' > $@

lint: $(ARTIFACT_DIR) $(ARTIFACT_DIR)/verilator_args
	cat $(ARTIFACT_DIR)/verilator_args
	set -o pipefail && $(VERILATOR_BIN) $(VERILATOR_FLAGS) --top main $(SRC_DIR)/main.sv |& python3 $(SRC_DIR)/scripts/parse_lint.py | tee $(ARTIFACT_DIR)/verilator.lint

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(SIMULATION_DIR):
	mkdir -p $(SIMULATION_DIR)

$(DEPDIR):
	mkdir -p $(DEPDIR)

clean:
	rm -rf ${ARTIFACT_DIR}

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

YOSYS_READVERILOG_ARGS:=$(BUILD_FLAGS) -I$(VINCLUDE_DIR) -sv ${VSOURCES}
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_READVERILOG_ARGS:=-debug $(YOSYS_READVERILOG_ARGS)
endif
YOSYS_READVERILOG_CMD:=read_verilog $(YOSYS_READVERILOG_ARGS)

YOSYS_READVERILOGLIB_ARGS:=-lib +/lattice/cells_bb_ecp5.v
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_READVERILOGLIB_ARGS:=-debug $(YOSYS_READVERILOGLIB_ARGS)
endif
YOSYS_READVERILOGLIB_CMD:=read_verilog $(YOSYS_READVERILOGLIB_ARGS)

YOSYS_SYNTHECP5_CMD:=synth_ecp5 -top main -json $(ARTIFACT_DIR)/mydesign.json

YOSYS_SCRIPT:=
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_SCRIPT +=echo on;
endif
YOSYS_SCRIPT +=$(YOSYS_READVERILOGLIB_CMD);
YOSYS_SCRIPT +=$(YOSYS_READVERILOG_CMD);
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
ifeq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)), -DUSE_INFER_BRAM_PLUGIN)
YOSYS_CMD_ARGS += -m depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so
endif
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_CMD_ARGS :=-d -v9 -g $(YOSYS_CMD_ARGS)
endif

compile: lint $(ARTIFACT_DIR)/mydesign.json
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
	@$(MAKE) --no-print-directory $(SIM_MAKEFLAGS) $(VCDOBJS)

DIAGRAM_TARGETS:=$(ARTIFACT_DIR)/netlist.svg
ifeq ($(YOSYS_INCLUDE_EXTRA),true)
	DIAGRAM_TARGETS +=$(ARTIFACT_DIR)/netlist_pre.svg
endif

diagram: $(DIAGRAM_TARGETS)

$(ARTIFACT_DIR)/mydesign_vizclean.json: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@

ifeq ($(YOSYS_INCLUDE_EXTRA),true)
$(ARTIFACT_DIR)/mydesign_pre_vizclean.json: $(ARTIFACT_DIR)/mydesign_pre.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@
endif

$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/mydesign_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@

ifeq ($(YOSYS_INCLUDE_EXTRA),true)
$(ARTIFACT_DIR)/netlist_pre.svg: $(ARTIFACT_DIR)/mydesign_pre_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@
endif

restore: restore-build
	$(TOOLPATH)/fujprog build/passthru/ulx3s_passthru_wifi.bit

restore-build:
	$(MAKE) -f src/passthru/Makefile all

# esp32_build: restore
# 	cd ../ESP32-FPGA-MatrixPanel; . ./setup_env.sh; idf.py build
esp32_flash: restore
	cd ../ESP32-FPGA-MatrixPanel; . ./setup_env.sh; idf.py flash

esp32: esp32_flash memprog
