PROJ:=this

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
SRC_DIR:=src
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints

# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations

BUILD_FLAGS:=
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=nenv/node_modules/.bin/netlistsvg
IVERILOG_BIN:=$(TOOLPATH)/iverilog
IVERILOG_FLAGS:=-g2012 -Wanachronisms -Wimplicit -Wmacro-redefinition -Wmacro-replacement -Wportbind -Wselect-range -Winfloop -Wsensitivity-entire-vector -Wsensitivity-entire-array # -g2012 solves issue where platform/tiny_cell_sim.v is detected as systemverilog | tells iVerilog to read the source files as SystemVerilog (specifically the SystemVerilog defined in IEEE 1800-2012)
VVP_BIN:=$(TOOLPATH)/vvp
VVP_FLAGS:=
GTKWAVE_BIN:=gtkwave
GTKWAVE_FLAGS:=
VERILATOR_BIN:=$(TOOLPATH)/verilator
VERILATOR_FLAGS:=--lint-only -Wno-fatal -Wall -Wno-TIMESCALEMOD -sv -y $(SRC_DIR) -v $(SRC_DIR)/platform/tiny_ecp5_sim.v

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
		  $(SRC_DIR)/debugger.sv \
		  $(SRC_DIR)/timeout_sync.sv \
		  $(SRC_DIR)/uart_rx.sv \
		  $(SRC_DIR)/fm6126init.sv \
		  $(SRC_DIR)/new_pll.sv \
		  $(SRC_DIR)/reset_on_start.sv \
		  $(SRC_DIR)/multimem.sv \
		  $(SRC_DIR)/platform/tiny_ecp5_sim.v

TBSRCS:=$(shell find $(TB_DIR) -name '*.sv' -or -name '*.v')
VVPOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vvp)))
VCDOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.vcd)))

.PHONY: all diagram simulation clean compile loopviz route lint
all: diagram simulation lint

simulation: $(VCDOBJS)

$(ARTIFACT_DIR)/yosys.json: ${VSOURCES} | $(ARTIFACT_DIR)
	$(shell mkdir -p $(ARTIFACT_DIR))
	$(TOOLPATH)/yosys -p "read_verilog $(SIM_FLAGS) -sv $^; prep -top main ; write_json $@"

diagram: $(ARTIFACT_DIR)/netlist.svg $(ARTIFACT_DIR)/yosys.json
$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/yosys.json  | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@

#$(warning In a command script $(VVPOBJS))

$(SIMULATION_DIR)/%.vcd: $(SIMULATION_DIR)/%.vvp | $(SIMULATION_DIR)
	$(VVP_BIN) $(VVP_FLAGS) $<

$(SIMULATION_DIR)/%.vvp: $(TB_DIR)/tb_%.sv $(SRC_DIR)/%.sv | $(SIMULATION_DIR)
#	$(info In a command script)
	$(shell mkdir -p $(SIMULATION_DIR))
	$(IVERILOG_BIN) $(SIM_FLAGS) $(IVERILOG_FLAGS) -s tb_$(*F) -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $(VSOURCES) $<

$(SIMULATION_DIR)/main_uart.vvp: $(TB_DIR)/tb_main_uart.sv $(SRC_DIR)/main.sv | $(SIMULATION_DIR)
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

# YOSYS_DEBUG:=echo on
compile: lint $(ARTIFACT_DIR)/mydesign.json
$(ARTIFACT_DIR)/mydesign.json $(ARTIFACT_DIR)/mydesign_show.dot $(ARTIFACT_DIR)/yosys.il: ${VSOURCES} | $(ARTIFACT_DIR)
	$(eval YOSYS_CMD:=$(YOSYS_DEBUG); read_verilog $(BUILD_FLAGS) -sv $^; synth_ecp5 -top main -json $@; show -format dot -prefix $(ARTIFACT_DIR)/mydesign_show; write_rtlil $(ARTIFACT_DIR)/yosys.il)
	# echo -e "synth_ecp5 -json $@ -run :map_ffs" >> $(ARTIFACT_DIR)/mydesign.ys
	echo "$(YOSYS_CMD)" > $(ARTIFACT_DIR)/mydesign.ys
	$(TOOLPATH)/yosys -L $(ARTIFACT_DIR)/yosys.log -p "$(YOSYS_CMD)"

loopviz: $(ARTIFACT_DIR)/mydesign_show.svg
$(ARTIFACT_DIR)/mydesign_show.svg: $(ARTIFACT_DIR)/mydesign_show.dot | $(ARTIFACT_DIR)
	$(TOOLPATH)/dot -Ksfdp -o $@ -Tsvg $<

route: $(ARTIFACT_DIR)/ulx3s_out.config
$(ARTIFACT_DIR)/ulx3s_out.config: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	$(TOOLPATH)/nextpnr-ecp5 --85k --json $< \
		--lpf $(CONSTRAINTS_DIR)/ulx3s_v316.lpf \
		--log $(ARTIFACT_DIR)/nextpnr.log \
		--package CABGA381 \
		--textcfg $@

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
