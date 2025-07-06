PROJ:=this

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
SRC_DIR:=src
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints

# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations

BUILD_FLAGS:=-DUSE_FM6126A
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=nenv/node_modules/.bin/netlistsvg
IVERILOG_BIN:=$(TOOLPATH)/iverilog
IVERILOG_FLAGS:=-g2012 # -g2012 solves issue where platform/tiny_cell_sim.v is detected as systemverilog
VVP_BIN:=$(TOOLPATH)/vvp
VVP_FLAGS:=
GTKWAVE_BIN:=gtkwave
GTKWAVE_FLAGS:=

VSOURCES := $(shell find $(SRC_DIR) -path '$(TB_DIR)' -prune -o -name '*.v' -print)

TBSRCS:=$(shell find $(TB_DIR) -name '*.v')
VVPOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.v=%.vvp)))
VCDOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.v=%.vcd)))

.PHONY: all diagram simulation clean compile
all: diagram simulation

simulation: $(VCDOBJS)

$(ARTIFACT_DIR)/yosys.json: ${VSOURCES}
	$(shell mkdir -p $(ARTIFACT_DIR))
	$(TOOLPATH)/yosys ${SIM_FLAGS} -p "prep -top main ; write_json $@" $^

diagram: $(ARTIFACT_DIR)/netlist.svg $(ARTIFACT_DIR)/yosys.json
$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/yosys.json
	$(NETLISTSVG) $< -o $@

#$(warning In a command script $(VVPOBJS))

$(SIMULATION_DIR)/%.vcd: $(SIMULATION_DIR)/%.vvp
	$(VVP_BIN) $(VVP_FLAGS) $<

$(SIMULATION_DIR)/%.vvp: $(SRC_DIR)/%.v $(TB_DIR)/tb_%.v
#	$(info In a command script)
	$(shell mkdir -p $(SIMULATION_DIR))
	$(IVERILOG_BIN) $(SIM_FLAGS) $(IVERILOG_FLAGS) -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^
$(SIMULATION_DIR)/main.vvp: ${VSOURCES}

$(SIMULATION_DIR)/newram4.vvp: $(SRC_DIR)/newram4.v $(TB_DIR)/tb_newram4.v $(SRC_DIR)/platform/tiny_cells_sim.v
$(SIMULATION_DIR)/multimem.vvp: $(SRC_DIR)/multimem.v $(TB_DIR)/tb_multimem.v $(SRC_DIR)/newram4.v $(SRC_DIR)/platform/tiny_cells_sim.v
$(SIMULATION_DIR)/control_module.vvp: $(SRC_DIR)/control_module.v \
									  $(TB_DIR)/tb_control_module.v \
									  $(foreach file, timeout.v uart_rx.v debugger.v uart_tx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/debugger.vvp: $(SRC_DIR)/debugger.v \
							    $(TB_DIR)/tb_debugger.v \
								$(foreach file, uart_rx.v uart_tx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/matrix_scan.vvp: $(SRC_DIR)/matrix_scan.v \
								   $(TB_DIR)/tb_matrix_scan.v \
								   $(foreach file, timeout.v, $(SRC_DIR)/$(file))

clean:
	rm -f $(SIMULATION_DIR)/*
	rm -f $(ARTIFACT_DIR)/yosys.json
	rm -f $(ARTIFACT_DIR)/netlist.svg
	rm -f $(ARTIFACT_DIR)/ulx3s_out.config
	rm -f $(ARTIFACT_DIR)/ulx3s.bit
	rm -f $(ARTIFACT_DIR)/mydesign.json
	rm -f $(ARTIFACT_DIR)/mydesign.ys

# YOSYS_DEBUG:=echo on
$(ARTIFACT_DIR)/mydesign.json: ${VSOURCES}
	$(eval YOSYS_CMD:=$(YOSYS_DEBUG); read_verilog $^; synth_ecp5 -json $@)
	# echo -e "synth_ecp5 -json $@ -run :map_ffs" >> $(ARTIFACT_DIR)/mydesign.ys
	echo "$(YOSYS_CMD)" > $(ARTIFACT_DIR)/mydesign.ys
	$(TOOLPATH)/yosys $(BUILD_FLAGS) -L $(ARTIFACT_DIR)/yosys.log -p "$(YOSYS_CMD)"

compile: $(ARTIFACT_DIR)/ulx3s_out.config
$(ARTIFACT_DIR)/ulx3s_out.config: $(ARTIFACT_DIR)/mydesign.json
	$(TOOLPATH)/nextpnr-ecp5 --85k --json $< \
		--lpf $(CONSTRAINTS_DIR)/ulx3s_v316.lpf \
		--log $(ARTIFACT_DIR)/nextpnr.log \
		--package CABGA381 \
		--textcfg $@

$(ARTIFACT_DIR)/ulx3s.bit: $(ARTIFACT_DIR)/ulx3s_out.config
	$(TOOLPATH)/ecppack $< $@

memprog: $(ARTIFACT_DIR)/ulx3s.bit
	$(TOOLPATH)/fujprog $<
