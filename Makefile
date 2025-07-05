PROJ=this

VSOURCES=src/brightness.v \
		 src/clock_divider.v \
		 src/control_module.v \
		 src/framebuffer_fetch.v \
		 src/main.v \
		 src/matrix_scan.v \
		 src/pixel_split.v \
		 src/rgb565.v \
		 src/timeout.v \
		 src/uart_tx.v \
		 src/debugger.v \
		 src/timeout_sync.v \
		 src/debug_uart_rx.v \
		 src/newram4.v \
		 src/fm6126init.v \
		 src/new_pll.v \
		 src/multimem.v \
		 src/platform/tiny_cells_sim.v
##
# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations
BUILD_FLAGS=-DUSE_FM6126A -DSIM
#BUILD_FLAGS=-DSIM
ARTIFACT_DIR=build_artifacts
TOOLPATH=oss-cad-suite/bin
YOSYS=../ice40_toolchain/yosys/yosys
NETLISTSVG=nenv/bin/netlistsvg
IVERILOG_BIN=iverilog
IVERILOG_FLAGS=
VVP_BIN=vvp
VVP_FLAGS=
GTKWAVE_BIN=gtkwave
GTKWAVE_FLAGS=

.PHONY: all diagram simulation clean compile
all: diagram simulation

diagram: $(ARTIFACT_DIR)/netlist.svg $(ARTIFACT_DIR)/yosys.json

$(ARTIFACT_DIR)/yosys.json: ${VSOURCES}
	$(shell mkdir -p $(ARTIFACT_DIR))
#	${YOSYS} -p "read_verilog ${VSOURCES}; proc; write_json -compat-int $@.json; proc"
	${YOSYS} ${BUILD_FLAGS} -p "prep -top main ; write_json $@" $^
#	${YOSYS} -p "prep -top main -flatten; write_json $@.json" ${VSOURCES}

$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/yosys.json
	${NETLISTSVG} $< -o $@

SIMULATION_DIR := $(ARTIFACT_DIR)/simulation
SRC_DIR = src
TB_DIR = src/testbenches
SRCS := $(shell find $(SRC_DIR) -name '*.v')
TBSRCS := $(shell find $(TB_DIR) -name '*.v')
VVPOBJS := $(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.v=%.vvp)))
VCDOBJS := $(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.v=%.vcd)))
#$(warning In a command script $(VVPOBJS))
simulation: $(VCDOBJS)

$(SIMULATION_DIR)/%.vcd: $(SIMULATION_DIR)/%.vvp
	$(VVP_BIN) ${VVP_FLAGS} $<

$(SIMULATION_DIR)/%.vvp: $(SRC_DIR)/%.v $(TB_DIR)/tb_%.v
#	$(info In a command script)
	$(shell mkdir -p $(SIMULATION_DIR))
	${IVERILOG_BIN} ${BUILD_FLAGS} -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^
$(SIMULATION_DIR)/main.vvp: $(foreach file, \
											fm6126init.v \
										    new_pll.v \
											timeout.v \
											timeout_sync.v \
											matrix_scan.v \
											framebuffer_fetch.v \
											control_module.v \
											multimem.v \
		 									newram4.v \
											pixel_split.v \
											debugger.v \
											clock_divider.v \
											platform/sb_ice40.v \
											debug_uart_rx.v \
											brightness.v \
											rgb565.v \
											uart_tx.v \
											, $(SRC_DIR)/$(file))
#$(SIMULATION_DIR)/newram2.vvp: $(SRC_DIR)/newram2.v $(TB_DIR)/tb_newram2.v $(foreach file, mpram.v mpram_lvt_1ht.v lvt_1ht.v mrram.v dpram.v mpram_gen.#v, $(SRC_DIR)/Multiported-RAM/$(file))
#	${IVERILOG_BIN} -I $(SRC_DIR)/Multiported-RAM -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^
#$(SIMULATION_DIR)/main.vvp: $(SRC_DIR)/main.v \
#						    $(TB_DIR)/tb_main.v \
#							$(foreach file, mpram.v mpram_lvt_1ht.v lvt_1ht.v mrram.v dpram.v mpram_gen.v, $(SRC_DIR)/Multiported-RAM/$(file)) \
#							$(foreach file, \
#											fm6126init.v \
#										    new_pll.v \
#											timeout.v \
#											matrix_scan.v \
#											framebuffer_fetch.v \
#											control_module.v \
#											pixel_split.v \
#											debugger.v \
#											clock_divider.v \
#											platform/sb_ice40.v \
#											debug_uart_rx.v \
#											brightness.v \
#											rgb565.v \
#											uart_tx.v \
#											newram2.v \
#											mem_core/syncore_ram.v \
#											, $(SRC_DIR)/$(file))
#	${IVERILOG_BIN} -I $(SRC_DIR)/Multiported-RAM -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -DSIM -o $@ $^


$(SIMULATION_DIR)/newram4.vvp: $(SRC_DIR)/newram4.v $(TB_DIR)/tb_newram4.v $(SRC_DIR)/platform/sb_ice40.v
$(SIMULATION_DIR)/multimem.vvp: $(SRC_DIR)/multimem.v $(TB_DIR)/tb_multimem.v $(SRC_DIR)/newram4.v $(SRC_DIR)/platform/sb_ice40.v
	${IVERILOG_BIN} ${BUILD_FLAGS} -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^
$(SIMULATION_DIR)/control_module.vvp: $(SRC_DIR)/control_module.v \
									  $(TB_DIR)/tb_control_module.v \
									  $(foreach file, timeout.v debug_uart_rx.v debugger.v uart_tx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/debugger.vvp: $(SRC_DIR)/debugger.v \
							    $(TB_DIR)/tb_debugger.v \
								$(foreach file, debug_uart_rx.v uart_tx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/matrix_scan.vvp: $(SRC_DIR)/matrix_scan.v \
								   $(TB_DIR)/tb_matrix_scan.v \
								   $(foreach file, timeout.v, $(SRC_DIR)/$(file))

clean:
	rm -f $(SIMULATION_DIR)/*
	rm -f $(ARTIFACT_DIR)/yosys.json
	rm -f $(ARTIFACT_DIR)/netlist.svg

#
##iverilog: ${VSOURCES} ${VTESTBENCHES} Makefile
##	$(IVEROLOG_BIN) ${VSOURCES} ${VTESTBENCHES} -o ${SIMULATION_DIR}/main.vvp
##
##vvp: ${ARTIFACT_DIR}/main.vvp
##	$(VVP_BIN) ${VVP_FLAGS} ${SIMULATION_DIR}/main.vvp
##
##vsim: simulation gtkwave
##	$(GTKWAVE_BIN) ${GTKWAVE_FLAGS} ${SIMULATION_DIR}/main.vcd
#
#

ulx3s.bit: ulx3s_out.config
	$(TOOLPATH)/ecppack ulx3s_out.config ulx3s.bit
# E	$(TOOLPATH)/ecppack ulx3s_out.config --bit ulx3s.bit --input mydesign.json --spibin mydesign.bin
# 	$(TOOLPATH)/ecppack ulx3s_out.config --input mydesign.json --spibin mydesign.bin
compile: ulx3s_out.config

ulx3s_out.config: mydesign.json
	$(TOOLPATH)/nextpnr-ecp5 --85k --json mydesign.json \
		--lpf constraints/ulx3s_v316.lpf \
		--package CABGA381 \
		--textcfg ulx3s_out.config

# blinky.json: blinky.ys blinky.v
# 	yosys blinky.ys
mydesign.json: ${VSOURCES}
	rm -f mydesign.ys
	# echo -e "echo on" >> mydesign.ys
	echo -e "read_verilog \\" >> mydesign.ys
	for file in $^ ; do \
		echo -e "    $${file} \\" >> mydesign.ys; \
	done
	echo -e "\n" >> mydesign.ys
	# echo -e "synth_ecp5 -json mydesign.json -run :map_ffs" >> mydesign.ys
	echo -e "synth_ecp5 -json mydesign.json" >> mydesign.ys
	$(TOOLPATH)/yosys -DUSE_FM6126A -L out.log mydesign.ys
	
memprog: ulx3s.bit
	$(TOOLPATH)/fujprog ulx3s.bit
