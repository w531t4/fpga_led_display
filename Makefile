PROJ:=this

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
SRC_DIR:=src
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints
VINCLUDE_DIR:=$(SRC_DIR)/include

# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations
# DEBUGGER - enable UART TX debugger (for use with src/scripts/uart_rx.py)
# W128 - enable 128 pixel width

BUILD_FLAGS ?=
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=nenv/node_modules/.bin/netlistsvg
IVERILOG_BIN:=$(TOOLPATH)/iverilog
IVERILOG_FLAGS:=-g2012 -Wanachronisms -Wimplicit -Wmacro-redefinition -Wmacro-replacement -Wportbind -Wselect-range -Winfloop -Wsensitivity-entire-vector -Wsensitivity-entire-array -I$(VINCLUDE_DIR) # -g2012 solves issue where platform/tiny_cell_sim.v is detected as systemverilog | tells iVerilog to read the source files as SystemVerilog (specifically the SystemVerilog defined in IEEE 1800-2012)
VVP_BIN:=$(TOOLPATH)/vvp
VVP_FLAGS:=-n
GTKWAVE_BIN:=gtkwave
GTKWAVE_FLAGS:=
VERILATOR_BIN:=$(TOOLPATH)/verilator
VERILATOR_FLAGS:=--lint-only $(SIM_FLAGS) -Wno-fatal -Wall -Wno-TIMESCALEMOD -sv -y $(SRC_DIR) -v $(SRC_DIR)/platform/tiny_ecp5_sim.v -I$(VINCLUDE_DIR)

SRCS := $(shell find $(SRC_DIR) -name '*.sv' -or -name '*.v')

VSOURCES:=$(SRC_DIR)/brightness.sv \
		  $(SRC_DIR)/clock_divider.sv \
		  $(SRC_DIR)/control_module.sv \
		  $(SRC_DIR)/framebuffer_fetch.sv \
		  $(SRC_DIR)/main.sv \
		  $(SRC_DIR)/matrix_scan.sv \
		  $(SRC_DIR)/pixel_split.sv \
		  $(SRC_DIR)/rgb565.sv \
		  $(SRC_DIR)/timeout.sv \
		  $(SRC_DIR)/uart_tx.sv \
		  $(SRC_DIR)/timeout_sync.sv \
		  $(SRC_DIR)/uart_rx.sv \
		  $(SRC_DIR)/new_pll.sv \
		  $(SRC_DIR)/reset_on_start.sv \
		  $(SRC_DIR)/multimem.sv \
		  $(SRC_DIR)/platform/tiny_ecp5_sim.v



INCLUDESRCS=$(shell find $(VINCLUDE_DIR) -name '*.vh')
TBSRCS:=$(shell find $(TB_DIR) -name '*.sv' -or -name '*.v')
VVPOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vvp)))
VCDOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vcd)))

ifeq ($(findstring -DUSE_FM6126A,$(BUILD_FLAGS)), -DUSE_FM6126A)
VSOURCES += $(SRC_DIR)/fm6126init.sv
else
TBSRCS := $(filter-out $(TB_DIR)/tb_fm6126init.sv, $(TBSRCS))
VVPOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.vvp, $(VVPOBJS))
VCDOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.vcd, $(VCDOBJS))
endif

# ifeq ($(findstring -DDEBUGGER,$(BUILD_FLAGS)), -DDEBUGGER)
VSOURCES += $(SRC_DIR)/debugger.sv
# endif



.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack
all: simulation lint
#$(warning In a command script $(VVPOBJS))

$(SIMULATION_DIR)/%.vcd: $(SIMULATION_DIR)/%.vvp | $(SIMULATION_DIR)
	$(VVP_BIN) $(VVP_FLAGS) $<

$(SIMULATION_DIR)/%.vvp: $(TB_DIR)/tb_%.sv $(SRC_DIR)/%.sv $(INCLUDESRCS) | $(SIMULATION_DIR)
#	$(info In a command script)
	$(shell mkdir -p $(SIMULATION_DIR))
	$(IVERILOG_BIN) $(SIM_FLAGS) $(IVERILOG_FLAGS) -s tb_$(*F) -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $(VSOURCES) $<

$(SIMULATION_DIR)/main_uart.vvp: $(TB_DIR)/tb_main_uart.sv $(SRC_DIR)/main.sv $(INCLUDESRCS) | $(SIMULATION_DIR)
	$(IVERILOG_BIN) $(SIM_FLAGS) $(IVERILOG_FLAGS) -s tb_main_uart -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $(VSOURCES) $<

lint:
	mkdir -p $(ARTIFACT_DIR)
	@set -o pipefail && $(TOOLPATH)/verilator $(VERILATOR_FLAGS) --top main $(SRC_DIR)/main.sv |& python3 $(SRC_DIR)/scripts/parse_lint.py | tee $(ARTIFACT_DIR)/verilator.lint

$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)

$(SIMULATION_DIR):
	mkdir -p $(SIMULATION_DIR)

clean:
	rm -rf ${ARTIFACT_DIR}

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
YOSYS_SYNTHECP5_CMD:=synth_ecp5 -top main -json $(ARTIFACT_DIR)/mydesign.json

YOSYS_SCRIPT:=
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_SCRIPT +=echo on;
endif
YOSYS_SCRIPT +=$(YOSYS_READVERILOG_CMD);
YOSYS_SCRIPT +=$(YOSYS_EXTRA);
YOSYS_SCRIPT +=$(YOSYS_SYNTHECP5_CMD);
YOSYS_SCRIPT +=show -format dot -prefix $(ARTIFACT_DIR)/mydesign_show;
YOSYS_SCRIPT +=write_rtlil $(ARTIFACT_DIR)/mydesign.il;
YOSYS_SCRIPT +=write_verilog -selected $(ARTIFACT_DIR)/mydesign_final.sv;

YOSYS_CMD_ARGS:=-L $(ARTIFACT_DIR)/yosys.log -p "$(YOSYS_SCRIPT)"
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_CMD_ARGS :=-d -v9 -g $(YOSYS_CMD_ARGS)
endif

compile: lint $(ARTIFACT_DIR)/mydesign.json
$(YOSYS_TARGETS): ${VSOURCES} $(INCLUDESRCS) | $(ARTIFACT_DIR)
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
		--textcfg $@

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


	$(TOOLPATH)/fujprog $<

simulation: $(VCDOBJS)

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
