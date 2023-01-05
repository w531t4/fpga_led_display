# Wed Jan  4 09:32:56 2023
Synopsys Lattice Technology Mapper, Version maplat, Build 1612R, Built Dec  5 2016 09:30:53
Copyright (C) 1994-2016 Synopsys, Inc. All rights reserved. This Synopsys software and all associated documentation are proprietary to Synopsys, Inc. and may only be used pursuant to the terms and conditions of a written license agreement with Synopsys, Inc. All other use, reproduction, modification, or distribution of the Synopsys software or the associated documentation is strictly prohibited.
Product Version L-2016.09L+ice40
Mapper Startup Complete (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 98MB peak: 99MB)
@N: MF248 |Running in 64-bit mode.
@N: MF666 |Clock conversion enabled. (Command "set_option -fix_gated_and_generated_clocks 1" in the project file.)
Design Input Complete (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 98MB peak: 100MB)
Mapper Initialization Complete (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 98MB peak: 100MB)
Start loading timing files (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 100MB peak: 100MB)
Finished loading timing files (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 100MB peak: 102MB)
Starting Optimization and Mapping (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 132MB peak: 134MB)
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[1].dpram_i.WAddr_r[11:0] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[1].dpram_i.RAddr_r[11:0]. To keep the instance, apply constraint syn_preserve=1 on the instance.
Available hyper_sources - for debug and ip models
	None Found
@N: MT204 |Auto Constrain mode is disabled because clocks are defined in the SDC file
            myclk_root
            my16mhzclk
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance timeout_global_reset.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v":119:1:119:6|User-specified initial value defined for instance matscan1.state[1:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v":129:4:129:9|User-specified initial value defined for instance matscan1.brightness_mask[5:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/matrix_scan.v":74:4:74:9|User-specified initial value defined for instance matscan1.row_latch_state[1:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance matscan1.timeout_output_enable.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance matscan1.timeout_column_address.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance matscan1.timeout_clk_pixel_load_en.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance fb_f.timeout_pixel_load.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|User-specified initial value defined for instance ctrl.timeout_cmd_line_write.start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|User-specified initial value defined for instance ctrl.brightness_enable[5:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|User-specified initial value defined for instance ctrl.cmd_line_addr_col[7:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|User-specified initial value defined for instance ctrl.rgb_enable[2:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|User-specified initial value defined for instance ctrl.cmd_line_addr_row[4:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":103:1:103:6|User-specified initial value defined for instance ctrl.ram_access_start_latch is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|User-specified initial value defined for instance ctrl.ram_access_start is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":75:4:75:9|User-specified initial value defined for instance mydebug.debug_bits[7:0] is being ignored.
@W: FX1039 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":44:4:44:9|User-specified initial value defined for instance mydebug.count[24:0] is being ignored.
Finished RTL optimizations (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 133MB peak: 134MB)
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Found counter in view:work.matrix_scan(verilog) instance timeout_output_enable.counter[9:0]
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Found counter in view:work.matrix_scan(verilog) instance timeout_column_address.counter[5:0]
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Found counter in view:work.matrix_scan(verilog) instance timeout_clk_pixel_load_en.counter[6:0]
Encoding state machine cmd_line_state[2:0] (in view: work.control_module(verilog))
original code -> new code
   00 -> 00
   01 -> 01
   10 -> 10
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Found counter in view:work.control_module(verilog) instance cmd_line_addr_col[7:0]
Encoding state machine currentState[4:0] (in view: work.debug_uart_rx_49_6s_48_24_1_2_4_8_16(verilog))
original code -> new code
   00001 -> 00001
   00010 -> 00010
   00100 -> 00100
   01000 -> 01000
   10000 -> 10000
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":169:4:169:9|Found counter in view:work.debug_uart_rx_49_6s_48_24_1_2_4_8_16(verilog) instance bit_ticks_counter[5:0]
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: MF179 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":79:47:79:65|Found 12 by 12 bit equality operator ('==') un1_bypass2 (in view: work.dpram_4096s_16s_2_0s_init_ram_1_0(verilog))
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@W: MO129 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Sequential instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[0] is reduced to a combinational gate by constant propagation.
@N: MF179 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":78:47:78:65|Found 12 by 12 bit equality operator ('==') un1_bypass1 (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog))
@N: MF179 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":79:47:79:65|Found 12 by 12 bit equality operator ('==') un1_bypass2 (in view: work.dpram_4096s_16s_2_0s_init_ram_0_0(verilog))
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/mpram_gen.v":62:2:62:7|Removing sequential instance dpram_inst.RData[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[8] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[9] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[10] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[11] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[12] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[13] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[14] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing sequential instance WData_r[15] (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog)) of type view:PrimLib.dff(prim) because it does not drive other instances.
@W: MO129 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Sequential instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[0] is reduced to a combinational gate by constant propagation.
@N: MF179 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":78:47:78:65|Found 12 by 12 bit equality operator ('==') un1_bypass1 (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog))
@N: MF179 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":79:47:79:65|Found 12 by 12 bit equality operator ('==') un1_bypass2 (in view: work.dpram_4096s_16s_2_0s_init_ram_0_1(verilog))
Encoding state machine currentState_1[3:0] (in view: work.debugger_25s_6000000s_184s_8s_1146s_11s_1_2_4_8(verilog))
original code -> new code
   0001 -> 00
   0010 -> 01
   0100 -> 10
   1000 -> 11
@N: MO225 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":75:4:75:9|There are no possible illegal states for state machine currentState_1[3:0] (in view: work.debugger_25s_6000000s_184s_8s_1146s_11s_1_2_4_8(verilog)); safe FSM implementation is not required.
Encoding state machine currentState[4:0] (in view: work.debug_uart_rx_1146s_11s_1145s_572s_1_2_4_8_16(verilog))
original code -> new code
   00001 -> 00001
   00010 -> 00010
   00100 -> 00100
   01000 -> 01000
   10000 -> 10000
@N: MO231 :"/home/awhite/Documents/Projects/fpga_led_display/src/debug_uart_rx.v":169:4:169:9|Found counter in view:work.debug_uart_rx_1146s_11s_1145s_572s_1_2_4_8_16(verilog) instance bit_ticks_counter[10:0]
Encoding state machine currentState[4:0] (in view: work.uart_tx_1146s_11s_1_2_4_8_16(verilog))
original code -> new code
   00001 -> 000
   00010 -> 001
   00100 -> 010
   01000 -> 011
   10000 -> 100
@N: MF794 |RAM dpram_inst.mem[7:0] required 3 registers during mapping
Starting factoring (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:00s; Memory used current: 138MB peak: 138MB)
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WEnb_r because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WEnb_r. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[1].dpram_i.WEnb_r because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WEnb_r. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[7] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[7]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[8] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[8]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[9] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[9]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[10] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[10]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[11] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.RAddr_r[11]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WData_r[0] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WData_r[0]. To keep the instance, apply constraint syn_preserve=1 on the instance.
@W: BN132 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Removing instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[1].dpram_i.WData_r[0] because it is equivalent to instance fb.mpram_ins_p1.genblk1.mrram_ins.RPORTrpi[0].dpram_i.WData_r[0]. To keep the instance, apply constraint syn_preserve=1 on the instance.
Finished factoring (Real Time elapsed 0h:00m:00s; CPU Time elapsed 0h:00m:01s; Memory used current: 142MB peak: 143MB)
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Removing sequential instance fb_f.timeout_pixel_load.counter[1] (in view: work.main(verilog)) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Removing sequential instance fb_f.timeout_pixel_load.counter[0] (in view: work.main(verilog)) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Removing sequential instance ctrl.timeout_cmd_line_write.counter[1] (in view: work.main(verilog)) because it does not drive other instances.
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/timeout.v":25:1:25:6|Removing sequential instance ctrl.timeout_cmd_line_write.counter[0] (in view: work.main(verilog)) because it does not drive other instances.
Finished gated-clock and generated-clock conversion (Real Time elapsed 0h:00m:01s; CPU Time elapsed 0h:00m:01s; Memory used current: 141MB peak: 143MB)
Finished generic timing optimizations - Pass 1 (Real Time elapsed 0h:00m:01s; CPU Time elapsed 0h:00m:01s; Memory used current: 142MB peak: 146MB)
Starting Early Timing Optimization (Real Time elapsed 0h:00m:01s; CPU Time elapsed 0h:00m:01s; Memory used current: 142MB peak: 146MB)
Finished Early Timing Optimization (Real Time elapsed 0h:00m:02s; CPU Time elapsed 0h:00m:02s; Memory used current: 146MB peak: 146MB)
Finished generic timing optimizations - Pass 2 (Real Time elapsed 0h:00m:02s; CPU Time elapsed 0h:00m:02s; Memory used current: 145MB peak: 146MB)
@N: BN362 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":75:4:75:9|Removing sequential instance mydebug.current_position[0] (in view: work.main(verilog)) because it does not drive other instances.
Finished preparing to map (Real Time elapsed 0h:00m:02s; CPU Time elapsed 0h:00m:02s; Memory used current: 145MB peak: 146MB)
Finished technology mapping (Real Time elapsed 0h:00m:02s; CPU Time elapsed 0h:00m:02s; Memory used current: 160MB peak: 162MB)
Pass		 CPU time		Worst Slack		Luts / Registers
------------------------------------------------------------
   1		0h:00m:02s		    -2.05ns		 716 /       494
   2		0h:00m:02s		    -2.05ns		 693 /       494
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RAddr_r[11] (in view: work.main(verilog)) with 18 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/debugger.v":75:4:75:9|Replicating instance mydebug.current_position[3] (in view: work.main(verilog)) with 28 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[3] (in view: work.main(verilog)) with 36 loads 1 time to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[2] (in view: work.main(verilog)) with 36 loads 1 time to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[5] (in view: work.main(verilog)) with 36 loads 1 time to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[4] (in view: work.main(verilog)) with 36 loads 1 time to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[7] (in view: work.main(verilog)) with 36 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[6] (in view: work.main(verilog)) with 36 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[9] (in view: work.main(verilog)) with 36 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[8] (in view: work.main(verilog)) with 36 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/control_module.v":116:1:116:6|Replicating instance ctrl.ram_address[10] (in view: work.main(verilog)) with 36 loads 2 times to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[7] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[6] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[5] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[4] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[3] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[2] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[1] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p2.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[0] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[3] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[4] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[0] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[1] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[2] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[5] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[7] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":83:4:83:5|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.RData[6] (in view: work.main(verilog)) with 3 loads 2 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_bottom.b_green.out_0 (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_top.b_green.out_0 (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
Timing driven replication report
Added 18 Registers via timing driven replication
Added 36 LUTs via timing driven replication
   3		0h:00m:02s		    -1.40ns		 729 /       512
   4		0h:00m:02s		    -1.09ns		 729 /       512
   5		0h:00m:03s		    -1.09ns		 732 /       512
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/Multiported-RAM/dpram.v":69:2:69:7|Replicating instance fb.mpram_ins_p1.genblk1\.mrram_ins.RPORTrpi\[0\]\.dpram_i.WAddr_r[11] (in view: work.main(verilog)) with 10 loads 1 time to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_top.b_red.out (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_top.b_blue.out (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_bottom.b_red.out (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
@N: FX271 :"/home/awhite/Documents/Projects/fpga_led_display/src/brightness.v":10:14:10:36|Replicating instance px_bottom.b_blue.out (in view: work.main(verilog)) with 2 loads 1 time(s) to improve timing.
Timing driven replication report
Added 1 Registers via timing driven replication
Added 4 LUTs via timing driven replication
   6		0h:00m:03s		    -1.09ns		 736 /       513
@N: FX1017 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":109:4:109:15|SB_GB inserted on the net clk_root_0.
@N: FX1017 :|SB_GB inserted on the net fb.clk_a.
@N: FX1017 :"/home/awhite/Documents/Projects/fpga_led_display/src/main.v":160:1:160:6|SB_GB inserted on the net ram_a_reset.
@N: FX1017 :|SB_GB inserted on the net mydebug.current_position19.
@N: FX1017 :|SB_GB inserted on the net N_288.
@N: FX1017 :|SB_GB inserted on the net fb.un1_clk_a_0_0_i.
Finished technology timing optimizations and critical path resynthesis (Real Time elapsed 0h:00m:03s; CPU Time elapsed 0h:00m:03s; Memory used current: 160MB peak: 162MB)
Finished restoring hierarchy (Real Time elapsed 0h:00m:03s; CPU Time elapsed 0h:00m:03s; Memory used current: 161MB peak: 162MB)
@N: MT611 :|Automatically generated clock clock_divider_2s_3s|clk_out_keep is not used and is being removed
@N: MT611 :|Automatically generated clock debug_uart_rx_49_6s_48_24_1_2_4_8_16|currentState_derived_clock[0] is not used and is being removed