# Wed Jan  4 09:32:54 2023
#Implementation: template_Implmnt
Synopsys HDL Compiler, version comp2016q3p1, Build 141R, built Dec  5 2016
@N|Running in 64-bit mode
Copyright (C) 1994-2016 Synopsys, Inc. All rights reserved. This Synopsys software and all associated documentation are proprietary to Synopsys, Inc. and may only be used pursuant to the terms and conditions of a written license agreement with Synopsys, Inc. All other use, reproduction, modification, or distribution of the Synopsys software or the associated documentation is strictly prohibited.
Synopsys Verilog Compiler, version comp2016q3p1, Build 141R, built Dec  5 2016
@N|Running in 64-bit mode
Copyright (C) 1994-2016 Synopsys, Inc. All rights reserved. This Synopsys software and all associated documentation are proprietary to Synopsys, Inc. and may only be used pursuant to the terms and conditions of a written license agreement with Synopsys, Inc. All other use, reproduction, modification, or distribution of the Synopsys software or the associated documentation is strictly prohibited.
Running on host :otherbarry
@N:: Running Verilog Compiler in System Verilog mode
@N:: Running Verilog Compiler in Multiple File Compilation Unit mode
@I::"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/generic/sb_ice40.v" (library work)
@I::"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/vlog/hypermods.v" (library __hyper__lib__)
@I::"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/vlog/umr_capim.v" (library snps_haps)
@I::"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/vlog/scemi_objects.v" (library snps_haps)
@I::"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/vlog/scemi_pipes.svh" (library snps_haps)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/main.v" (library work)
@W: CS133 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":119:18:119:28|Ignoring property syn_noprune
@W: CS133 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":127:54:127:64|Ignoring property syn_noprune
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/clock_divider.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/framebuffer.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/framebuffer_fetch.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/newram.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/pixel_split.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/rgb565.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/syncore_ram.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/uart_tx.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v" (library work)
@I:"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/utils.vh" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mrram.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_xor.v" (library work)
@I::"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v" (library work)
Verilog syntax check successful!
File /home/awhite/Documents/Projects/fpga_led_display/src/main.v changed - recompiling
File /home/awhite/Documents/Projects/fpga_led_display/src/clock_divider.v changed - recompiling
File /home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v changed - recompiling
Selecting top level module main
@N: CG364 :"/home/awhite/lscc/iCEcube2.2020.12/synpbase/lib/generic/sb_ice40.v":698:7:698:19|Synthesizing module SB_PLL40_CORE in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":13:7:13:9|Synthesizing module pll in library work.
@W: CG781 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":25:10:25:12|Input EXTFEEDBACK on instance uut is undriven; assigning to 0.  Simulation mismatch possible. Either assign the input or remove the declaration.
@W: CG781 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":25:10:25:12|Input DYNAMICDELAY on instance uut is undriven; assigning to 0.  Simulation mismatch possible. Either assign the input or remove the declaration.
@W: CG781 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":25:10:25:12|Input SDI on instance uut is undriven; assigning to 0.  Simulation mismatch possible. Either assign the input or remove the declaration.
@W: CG781 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":25:10:25:12|Input SCLK on instance uut is undriven; assigning to 0.  Simulation mismatch possible. Either assign the input or remove the declaration.
@W: CG781 :"/home/awhite/Documents/Projects/fpga_led_display/src/new_pll.v":25:10:25:12|Input LATCHINPUTVALUE on instance uut is undriven; assigning to 0.  Simulation mismatch possible. Either assign the input or remove the declaration.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":9:7:9:13|Synthesizing module timeout in library work.
	COUNTER_WIDTH=32'b00000000000000000000000000000100
   Generated name = timeout_4s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/clock_divider.v":7:7:7:19|Synthesizing module clock_divider in library work.
	CLK_DIV_WIDTH=32'b00000000000000000000000000000010
	CLK_DIV_COUNT=32'b00000000000000000000000000000011
   Generated name = clock_divider_2s_3s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":9:7:9:13|Synthesizing module timeout in library work.
	COUNTER_WIDTH=32'b00000000000000000000000000000111
   Generated name = timeout_7s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":9:7:9:13|Synthesizing module timeout in library work.
	COUNTER_WIDTH=32'b00000000000000000000000000000110
   Generated name = timeout_6s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":9:7:9:13|Synthesizing module timeout in library work.
	COUNTER_WIDTH=32'b00000000000000000000000000001010
   Generated name = timeout_10s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v":1:7:1:17|Synthesizing module matrix_scan in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":9:7:9:13|Synthesizing module timeout in library work.
	COUNTER_WIDTH=32'b00000000000000000000000000000010
   Generated name = timeout_2s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/framebuffer_fetch.v":1:7:1:23|Synthesizing module framebuffer_fetch in library work.
@W: CS263 :"/home/awhite/Documents/Projects/fpga_led_display/src/framebuffer_fetch.v":40:11:40:28|Port-width mismatch for port counter. The port definition is 2 bits, but the actual port connection bit width is 4. Adjust either the definition or the instantiation of this port.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":25:7:25:19|Synthesizing module debug_uart_rx in library work.
	TICKS_PER_BIT=6'b110001
	TICKS_PER_BIT_SIZE=32'b00000000000000000000000000000110
	TICKS_TO_BIT=32'b00000000000000000000000000110000
	TICKS_TO_MIDLE=32'b00000000000000000000000000011000
	STATE_IDLE=5'b00001
	STATE_RECEIVE_START=5'b00010
	STATE_RECEIVE_DATA=5'b00100
	STATE_RECEIVE_STOP=5'b01000
	STATE_DONE=5'b10000
   Generated name = debug_uart_rx_49_6s_48_24_1_2_4_8_16
@W: CG532 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":67:4:67:10|Within an initial block, only Verilog force statements and memory $readmemh/$readmemb initialization statements are recognized, and all other content is ignored.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":1:7:1:20|Synthesizing module control_module in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram.v":36:7:36:11|Synthesizing module mpram in library work.
	MEMD=32'b00000000000000000001000000000000
	DATAW=32'b00000000000000000000000000010000
	nRPORTS=32'b00000000000000000000000000000010
	nWPORTS=32'b00000000000000000000000000000001
	TYPE=24'b010110000100111101010010
	BYP=24'b010100100100010001010111
	IFILE=64'b0110100101101110011010010111010001011111011100100110000101101101
	ADDRW=32'b00000000000000000000000000001100
	l2nW=32'b00000000000000000000000000000000
	nBitsXOR=32'b00000000000000000000000000000000
	nBitsBIN=32'b00000000000000000000000000000000
	nBits1HT=32'b00000000000000000000000000000000
	AUTOTYPE=48'b010011000101011001010100001100010100100001010100
	iTYPE=48'b000000000000000000000000010110000100111101010010
	WAW=1'b1
	RAW=1'b1
	RDW=1'b1
   Generated name = mpram_Z1
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mrram.v":37:7:37:11|Synthesizing module mrram in library work.
	MEMD=32'b00000000000000000001000000000000
	DATAW=32'b00000000000000000000000000010000
	nRPORTS=32'b00000000000000000000000000000010
	BYPASS=32'b00000000000000000000000000000010
	IZERO=32'b00000000000000000000000000000000
	IFILE=64'b0110100101101110011010010111010001011111011100100110000101101101
	ADDRW=32'b00000000000000000000000000001100
   Generated name = mrram_4096s_16s_2s_2_0s_init_ram_12s
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":36:7:36:15|Synthesizing module mpram_gen in library work.
	MEMD=32'b00000000000000000001000000000000
	DATAW=32'b00000000000000000000000000010000
	nRPORTS=32'b00000000000000000000000000000001
	nWPORTS=32'b00000000000000000000000000000001
	IZERO=32'b00000000000000000000000000000000
	IFILE=64'b0110100101101110011010010111010001011111011100100110000101101101
	ADDRW=32'b00000000000000000000000000001100
   Generated name = mpram_gen_4096s_16s_1s_1s_0s_init_ram_12s
@W: CG371 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":60:23:60:31|Cannot find data file init_ram.hex for task $readmemh
@W: CG532 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":56:2:56:8|Within an initial block, only Verilog force statements and memory $readmemh/$readmemb initialization statements are recognized, and all other content is ignored.
@N: CL134 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Found RAM mem, depth=4096, width=16
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":36:7:36:11|Synthesizing module dpram in library work.
	MEMD=32'b00000000000000000001000000000000
	DATAW=32'b00000000000000000000000000010000
	BYPASS=32'b00000000000000000000000000000010
	IZERO=32'b00000000000000000000000000000000
	IFILE=64'b0110100101101110011010010111010001011111011100100110000101101101
   Generated name = dpram_4096s_16s_2_0s_init_ram
@W: CG133 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mrram.v":58:10:58:10|Object _j_ is declared but not assigned. Either assign a value or remove the declaration.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":26:12:26:18|Synthesizing module newram2 in library work.
@W: CG360 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":109:8:109:12|Removing wire clk_b, as there is no assignment to it.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/rgb565.v":1:7:1:12|Synthesizing module rgb565 in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":1:7:1:16|Synthesizing module brightness in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/pixel_split.v":1:7:1:17|Synthesizing module pixel_split in library work.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":25:7:25:19|Synthesizing module debug_uart_rx in library work.
	TICKS_PER_BIT=32'b00000000000000000000010001111010
	TICKS_PER_BIT_SIZE=32'b00000000000000000000000000001011
	TICKS_TO_BIT=32'b00000000000000000000010001111001
	TICKS_TO_MIDLE=32'b00000000000000000000001000111100
	STATE_IDLE=5'b00001
	STATE_RECEIVE_START=5'b00010
	STATE_RECEIVE_DATA=5'b00100
	STATE_RECEIVE_STOP=5'b01000
	STATE_DONE=5'b10000
   Generated name = debug_uart_rx_1146s_11s_1145s_572s_1_2_4_8_16
@W: CG532 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":67:4:67:10|Within an initial block, only Verilog force statements and memory $readmemh/$readmemb initialization statements are recognized, and all other content is ignored.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/uart_tx.v":25:7:25:13|Synthesizing module uart_tx in library work.
	TICKS_PER_BIT=32'b00000000000000000000010001111010
	TICKS_PER_BIT_SIZE=32'b00000000000000000000000000001011
	STATE_IDLE=5'b00001
	STATE_SEND_START=5'b00010
	STATE_SEND_BITS=5'b00100
	STATE_SEND_STOP=5'b01000
	STATE_DONE=5'b10000
   Generated name = uart_tx_1146s_11s_1_2_4_8_16
@W: CG532 :"/home/awhite/Documents/Projects/fpga_led_display/src/uart_tx.v":67:1:67:7|Within an initial block, only Verilog force statements and memory $readmemh/$readmemb initialization statements are recognized, and all other content is ignored.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":1:7:1:14|Synthesizing module debugger in library work.
	DIVIDER_TICKS_WIDTH=32'b00000000000000000000000000011001
	DIVIDER_TICKS=32'b00000000010110111000110110000000
	DATA_WIDTH=32'b00000000000000000000000010111000
	DATA_WIDTH_BASE2=32'b00000000000000000000000000001000
	UART_TICKS_PER_BIT=32'b00000000000000000000010001111010
	UART_TICKS_PER_BIT_SIZE=32'b00000000000000000000000000001011
	STATE_IDLE=5'b00001
	STATE_START=5'b00010
	STATE_SEND=5'b00100
	STATE_WAIT=5'b01000
   Generated name = debugger_25s_6000000s_184s_8s_1146s_11s_1_2_4_8
@W: CG532 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":66:4:66:10|Within an initial block, only Verilog force statements and memory $readmemh/$readmemb initialization statements are recognized, and all other content is ignored.
@N: CG364 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":2:7:2:10|Synthesizing module main in library work.
@W: CG360 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":107:6:107:19|Removing wire clk_root_logic, as there is no assignment to it.
@N: CL201 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":75:4:75:9|Trying to extract state machine for register currentState.
Extracted state machine for register currentState
State machine has 4 reachable states with original encodings of:
   0001
   0010
   0100
   1000
@N: CL201 :"/home/awhite/Documents/Projects/fpga_led_display/src/uart_tx.v":140:1:140:6|Trying to extract state machine for register currentState.
Extracted state machine for register currentState
State machine has 5 reachable states with original encodings of:
   00001
   00010
   00100
   01000
   10000
@N: CL201 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":169:4:169:9|Trying to extract state machine for register currentState.
Extracted state machine for register currentState
State machine has 5 reachable states with original encodings of:
   00001
   00010
   00100
   01000
   10000
@N: CL159 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":57:8:57:17|Input PortAReset is unused.
@N: CL159 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":60:8:60:15|Input PortBClk is unused.
@N: CL159 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":62:28:62:38|Input PortBDataIn is unused.
@N: CL159 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":63:8:63:23|Input PortBWriteEnable is unused.
@N: CL159 :"/home/awhite/Documents/Projects/fpga_led_display/src/newram2.v":64:8:64:17|Input PortBReset is unused.
@N: CL201 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Trying to extract state machine for register cmd_line_state.
Extracted state machine for register cmd_line_state
State machine has 3 reachable states with original encodings of:
   00
   01
   10
@W: CL249 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Initial value is not supported on state machine cmd_line_state
@N: CL201 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":169:4:169:9|Trying to extract state machine for register currentState.
Extracted state machine for register currentState
State machine has 5 reachable states with original encodings of:
   00001
   00010
   00100
   01000
   10000
At c_ver Exit (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 80MB peak: 83MB)
Process took 0h:00m:01s realtime, 0h:00m:01s cputime
Process completed successfully.