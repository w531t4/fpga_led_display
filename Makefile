PROJ=this

VSOURCES=src/brightness.v \
		 src/clock_divider.v \
		 src/control_module.v \
		 src/framebuffer.v \
		 src/framebuffer_fetch.v \
		 src/main.v \
		 src/matrix_scan.v \
		 src/pixel_split.v \
		 src/rgb565.v \
		 src/timeout.v \
		 src/newram.v \
		 src/syncore_ram.v \
		 src/newram2.v \
		 src/uart_tx.v \
		 src/debugger.v \
		 src/debug_uart_rx.v \
		 src/Multiported-RAM/mpram.v \
		 src/Multiported-RAM/mrram.v \
		 src/Multiported-RAM/dpram.v \
		 src/Multiported-RAM/mpram_gen.v \
		 src/Multiported-RAM/mpram_xor.v \
		 src/fm6126init.v \
		 src/new_pll.v \
		 src/multimem.v \
		 src/newram3.v \
		 src/platform/sb_ice40.v

ARTIFACT_DIR=build_artifacts
YOSYS=../ice40_toolchain/yosys/yosys
NETLISTSVG=nenv/bin/netlistsvg
IVERILOG_BIN=iverilog
IVERILOG_FLAGS=""
VVP_BIN=vvp
VVP_FLAGS=""
GTKWAVE_BIN=gtkwave
GTKWAVE_FLAGS=""

.PHONY: all diagram simulation clean
all: diagram simulation

diagram: $(ARTIFACT_DIR)/netlist.svg $(ARTIFACT_DIR)/yosys.json

$(ARTIFACT_DIR)/yosys.json: ${VSOURCES}
	$(shell mkdir -p $(ARTIFACT_DIR))
#	${YOSYS} -p "read_verilog ${VSOURCES}; proc; write_json -compat-int $@.json; proc"
	${YOSYS} -p "prep -top main ; write_json $@" $^
#	${YOSYS} -p "prep -top main -flatten; write_json $@.json" ${VSOURCES}

$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/yosys.json
	${NETLISTSVG} $< -o $@

SIMULATION_DIR := $(ARTIFACT_DIR)/simulation
SRC_DIR = src
TB_DIR = src/testbenches
SRCS := $(shell find $(SRC_DIR) -name '*.v')
TBSRCS := $(shell find $(TB_DIR) -name '*.v')
VVPOBJS := $(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.v=%.vvp)))
#$(warning In a command script $(VVPOBJS))
simulation: vvp
vvp: $(VVPOBJS)

$(SIMULATION_DIR)/%.vvp: $(SRC_DIR)/%.v $(TB_DIR)/tb_%.v
#	$(info In a command script)
	$(shell mkdir -p $(SIMULATION_DIR))
	${IVERILOG_BIN} -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^

$(SIMULATION_DIR)/main.vvp: $(foreach file, fm6126init.v \
										    new_pll.v \
											timeout.v \
											matrix_scan.v \
											framebuffer_fetch.v \
											control_module.v \
											multimem.v \
											pixel_split.v \
											debugger.v \
											clock_divider.v \
											platform/sb_ice40.v \
											debug_uart_rx.v \
											newram3.v \
											brightness.v \
											rgb565.v \
											uart_tx.v \
											syncore_ram.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/newram2.vvp: $(foreach file, mpram.v mpram_lvt_1ht.v lvt_1ht.v mrram.v dpram.v mpram_gen.v, $(SRC_DIR)/Multiported-RAM/$(file))
	${IVERILOG_BIN} -I $(SRC_DIR)/Multiported-RAM -D'DUMP_FILE_NAME="$(addprefix $(SIMULATION_DIR)/, $(subst .vvp,.vcd, $(notdir $@)))"' -o $@ $^

$(SIMULATION_DIR)/control_module.vvp: $(foreach file, timeout.v debug_uart_rx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/debugger.vvp: $(foreach file, debug_uart_rx.v uart_tx.v clock_divider.v, $(SRC_DIR)/$(file))
$(SIMULATION_DIR)/matrix_scan.vvp: $(foreach file, timeout.v, $(SRC_DIR)/$(file))

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
