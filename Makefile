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
		 src/new_pll.v \
		 src/sb_ice40.v

YOSYS=../ice40_toolchain/yosys/yosys
NETLISTSVG=nenv/bin/netlistsvg
all: ${VSOURCES} Makefile

#	${YOSYS} -p "read_verilog ${VSOURCES}; proc; write_json -compat-int $@.json; proc"
	${YOSYS} -p "prep -top main ; write_json build_artifacts/$@.json" ${VSOURCES}
#	${YOSYS} -p "prep -top main -flatten; write_json $@.json" ${VSOURCES}
	${NETLISTSVG} build_artifacts/all.json -o build_artifacts/netlist.svg
