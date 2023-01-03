// Verilog netlist produced by program LSE :  version Diamond Version 0.0.0
// Netlist written on Tue Mar 12 14:10:39 2019
//
// Verilog Description of module main
//

module main (pin1_usb_dp, pin2_usb_dn, pin3_clk_16mhz, pin3, pin4, 
            pin5, pin6, pin7, pin8, pin9, pin10, pin11, pin12, 
            pin13, pin14_sdo, pin15_sdi, pin16_sck, pin17_ss, pin18, 
            pin19, pin20, pin21, pin22, pin23, pin24, pinLED) /* synthesis syn_module_defined=1 */ ;   // main.v(2[8:12])
    output pin1_usb_dp /* synthesis .original_dir=IN_OUT */ ;   // main.v(5[9:20])
    output pin2_usb_dn /* synthesis .original_dir=IN_OUT */ ;   // main.v(6[9:20])
    input pin3_clk_16mhz;   // main.v(7[9:23])
    output pin3 /* synthesis .original_dir=IN_OUT */ ;   // main.v(8[9:13])
    output pin4 /* synthesis .original_dir=IN_OUT */ ;   // main.v(9[9:13])
    output pin5 /* synthesis .original_dir=IN_OUT */ ;   // main.v(10[9:13])
    output pin6 /* synthesis .original_dir=IN_OUT */ ;   // main.v(11[9:13])
    inout pin7;   // main.v(12[9:13])
    output pin8 /* synthesis .original_dir=IN_OUT */ ;   // main.v(13[9:13])
    output pin9 /* synthesis .original_dir=IN_OUT */ ;   // main.v(14[9:13])
    output pin10 /* synthesis .original_dir=IN_OUT */ ;   // main.v(15[9:14])
    output pin11 /* synthesis .original_dir=IN_OUT */ ;   // main.v(16[9:14])
    output pin12 /* synthesis .original_dir=IN_OUT */ ;   // main.v(17[9:14])
    output pin13 /* synthesis .original_dir=IN_OUT */ ;   // main.v(18[9:14])
    output pin14_sdo /* synthesis .original_dir=IN_OUT */ ;   // main.v(19[9:18])
    output pin15_sdi /* synthesis .original_dir=IN_OUT */ ;   // main.v(20[9:18])
    output pin16_sck /* synthesis .original_dir=IN_OUT */ ;   // main.v(21[9:18])
    output pin17_ss /* synthesis .original_dir=IN_OUT */ ;   // main.v(22[9:17])
    output pin18 /* synthesis .original_dir=IN_OUT */ ;   // main.v(23[9:14])
    output pin19 /* synthesis .original_dir=IN_OUT */ ;   // main.v(24[9:14])
    output pin20 /* synthesis .original_dir=IN_OUT */ ;   // main.v(25[9:14])
    output pin21 /* synthesis .original_dir=IN_OUT */ ;   // main.v(26[9:14])
    output pin22 /* synthesis .original_dir=IN_OUT */ ;   // main.v(27[9:14])
    output pin23 /* synthesis .original_dir=IN_OUT */ ;   // main.v(28[9:14])
    output pin24 /* synthesis .original_dir=IN_OUT */ ;   // main.v(29[9:14])
    output pinLED /* synthesis .original_dir=IN_OUT */ ;   // main.v(30[9:15])
    
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    wire pin11_c /* synthesis is_inv_clock=1 */ ;   // main.v(16[9:14])
    wire pin14_sdo_c /* synthesis is_clock=1, SET_AS_NETWORK=pin14_sdo_c */ ;   // main.v(19[9:18])
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    
    wire pin3_clk_16mhz_c, pin4_c_1, pin5_c_2, pin6_c_3, pin10_c, 
        pin15_sdi_c, pin16_sck_c_0, pin17_ss_c_1, pin22_c_0, pin23_c_0, 
        pin24_c_1, pinLED_c, output_enable, GND_net, n15, n1740, 
        pin7_out, clkdiv_baudrate_reset, n1688, VCC_net;
    
    GND i1 (.Y(GND_net));
    SB_IO pin2_usb_dn_pad (.PACKAGE_PIN(pin2_usb_dn), .OUTPUT_ENABLE(GND_net), 
          .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin2_usb_dn_pad.PIN_TYPE = 6'b101001;
    defparam pin2_usb_dn_pad.PULLUP = 1'b0;
    defparam pin2_usb_dn_pad.NEG_TRIGGER = 1'b0;
    defparam pin2_usb_dn_pad.IO_STANDARD = "SB_LVCMOS";
    SB_PLL40_CORE usb_pll_inst (.REFERENCECLK(pin3_clk_16mhz_c), .PLLOUTCORE(pin3_c), 
            .BYPASS(GND_net), .RESETB(VCC_net)) /* synthesis syn_instantiated=1 */ ;
    defparam usb_pll_inst.FEEDBACK_PATH = "SIMPLE";
    defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
    defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
    defparam usb_pll_inst.SHIFTREG_DIV_MODE = 2'b00;
    defparam usb_pll_inst.FDA_FEEDBACK = 4'b0000;
    defparam usb_pll_inst.FDA_RELATIVE = 4'b0000;
    defparam usb_pll_inst.PLLOUT_SELECT = "GENCLK";
    defparam usb_pll_inst.DIVR = 0;
    defparam usb_pll_inst.DIVF = 40;
    defparam usb_pll_inst.DIVQ = 2;
    defparam usb_pll_inst.FILTER_RANGE = 3'b001;
    defparam usb_pll_inst.ENABLE_ICEGATE = 1'b0;
    defparam usb_pll_inst.TEST_MODE = 1'b0;
    defparam usb_pll_inst.EXTERNAL_DIVIDE_FACTOR = 1;
    SB_IO pin1_usb_dp_pad (.PACKAGE_PIN(pin1_usb_dp), .OUTPUT_ENABLE(GND_net), 
          .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin1_usb_dp_pad.PIN_TYPE = 6'b101001;
    defparam pin1_usb_dp_pad.PULLUP = 1'b0;
    defparam pin1_usb_dp_pad.NEG_TRIGGER = 1'b0;
    defparam pin1_usb_dp_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin7_pad (.PACKAGE_PIN(pin7), .OUTPUT_ENABLE(GND_net), .D_OUT_0(GND_net), 
          .D_IN_0(pin7_out));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin7_pad.PIN_TYPE = 6'b101001;
    defparam pin7_pad.PULLUP = 1'b0;
    defparam pin7_pad.NEG_TRIGGER = 1'b0;
    defparam pin7_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin3_clk_16mhz_pad (.PACKAGE_PIN(pin3_clk_16mhz), .OUTPUT_ENABLE(VCC_net), 
          .D_IN_0(pin3_clk_16mhz_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin3_clk_16mhz_pad.PIN_TYPE = 6'b000001;
    defparam pin3_clk_16mhz_pad.PULLUP = 1'b0;
    defparam pin3_clk_16mhz_pad.NEG_TRIGGER = 1'b0;
    defparam pin3_clk_16mhz_pad.IO_STANDARD = "SB_LVCMOS";
    SB_LUT4 i21_4_lut (.I0(pin24_c_1), .I1(n15), .I2(pin23_c_0), .I3(n1740), 
            .O(n1688));   // control_module.v(110[8] 158[6])
    defparam i21_4_lut.LUT_INIT = 16'h1aba;
    SB_IO pinLED_pad (.PACKAGE_PIN(pinLED), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pinLED_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pinLED_pad.PIN_TYPE = 6'b011001;
    defparam pinLED_pad.PULLUP = 1'b0;
    defparam pinLED_pad.NEG_TRIGGER = 1'b0;
    defparam pinLED_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin24_pad (.PACKAGE_PIN(pin24), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin24_c_1));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin24_pad.PIN_TYPE = 6'b011001;
    defparam pin24_pad.PULLUP = 1'b0;
    defparam pin24_pad.NEG_TRIGGER = 1'b0;
    defparam pin24_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin23_pad (.PACKAGE_PIN(pin23), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin23_c_0));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin23_pad.PIN_TYPE = 6'b011001;
    defparam pin23_pad.PULLUP = 1'b0;
    defparam pin23_pad.NEG_TRIGGER = 1'b0;
    defparam pin23_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin22_pad (.PACKAGE_PIN(pin22), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin22_c_0));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin22_pad.PIN_TYPE = 6'b011001;
    defparam pin22_pad.PULLUP = 1'b0;
    defparam pin22_pad.NEG_TRIGGER = 1'b0;
    defparam pin22_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin21_pad (.PACKAGE_PIN(pin21), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin21_pad.PIN_TYPE = 6'b011001;
    defparam pin21_pad.PULLUP = 1'b0;
    defparam pin21_pad.NEG_TRIGGER = 1'b0;
    defparam pin21_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin20_pad (.PACKAGE_PIN(pin20), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin20_pad.PIN_TYPE = 6'b011001;
    defparam pin20_pad.PULLUP = 1'b0;
    defparam pin20_pad.NEG_TRIGGER = 1'b0;
    defparam pin20_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin19_pad (.PACKAGE_PIN(pin19), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin19_pad.PIN_TYPE = 6'b011001;
    defparam pin19_pad.PULLUP = 1'b0;
    defparam pin19_pad.NEG_TRIGGER = 1'b0;
    defparam pin19_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin18_pad (.PACKAGE_PIN(pin18), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin18_pad.PIN_TYPE = 6'b011001;
    defparam pin18_pad.PULLUP = 1'b0;
    defparam pin18_pad.NEG_TRIGGER = 1'b0;
    defparam pin18_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin17_ss_pad (.PACKAGE_PIN(pin17_ss), .OUTPUT_ENABLE(VCC_net), 
          .D_OUT_0(pin17_ss_c_1));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin17_ss_pad.PIN_TYPE = 6'b011001;
    defparam pin17_ss_pad.PULLUP = 1'b0;
    defparam pin17_ss_pad.NEG_TRIGGER = 1'b0;
    defparam pin17_ss_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin16_sck_pad (.PACKAGE_PIN(pin16_sck), .OUTPUT_ENABLE(VCC_net), 
          .D_OUT_0(pin16_sck_c_0));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin16_sck_pad.PIN_TYPE = 6'b011001;
    defparam pin16_sck_pad.PULLUP = 1'b0;
    defparam pin16_sck_pad.NEG_TRIGGER = 1'b0;
    defparam pin16_sck_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin15_sdi_pad (.PACKAGE_PIN(pin15_sdi), .OUTPUT_ENABLE(VCC_net), 
          .D_OUT_0(pin15_sdi_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin15_sdi_pad.PIN_TYPE = 6'b011001;
    defparam pin15_sdi_pad.PULLUP = 1'b0;
    defparam pin15_sdi_pad.NEG_TRIGGER = 1'b0;
    defparam pin15_sdi_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin14_sdo_pad (.PACKAGE_PIN(pin14_sdo), .OUTPUT_ENABLE(VCC_net), 
          .D_OUT_0(pin14_sdo_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin14_sdo_pad.PIN_TYPE = 6'b011001;
    defparam pin14_sdo_pad.PULLUP = 1'b0;
    defparam pin14_sdo_pad.NEG_TRIGGER = 1'b0;
    defparam pin14_sdo_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin13_pad (.PACKAGE_PIN(pin13), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin13_pad.PIN_TYPE = 6'b011001;
    defparam pin13_pad.PULLUP = 1'b0;
    defparam pin13_pad.NEG_TRIGGER = 1'b0;
    defparam pin13_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin12_pad (.PACKAGE_PIN(pin12), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin12_pad.PIN_TYPE = 6'b011001;
    defparam pin12_pad.PULLUP = 1'b0;
    defparam pin12_pad.NEG_TRIGGER = 1'b0;
    defparam pin12_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin11_pad (.PACKAGE_PIN(pin11), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin11_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin11_pad.PIN_TYPE = 6'b011001;
    defparam pin11_pad.PULLUP = 1'b0;
    defparam pin11_pad.NEG_TRIGGER = 1'b0;
    defparam pin11_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin10_pad (.PACKAGE_PIN(pin10), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin10_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin10_pad.PIN_TYPE = 6'b011001;
    defparam pin10_pad.PULLUP = 1'b0;
    defparam pin10_pad.NEG_TRIGGER = 1'b0;
    defparam pin10_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin9_pad (.PACKAGE_PIN(pin9), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(output_enable));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin9_pad.PIN_TYPE = 6'b011001;
    defparam pin9_pad.PULLUP = 1'b0;
    defparam pin9_pad.NEG_TRIGGER = 1'b0;
    defparam pin9_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin8_pad (.PACKAGE_PIN(pin8), .OUTPUT_ENABLE(GND_net), .D_OUT_0(GND_net));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin8_pad.PIN_TYPE = 6'b101001;
    defparam pin8_pad.PULLUP = 1'b0;
    defparam pin8_pad.NEG_TRIGGER = 1'b0;
    defparam pin8_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin6_pad (.PACKAGE_PIN(pin6), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin6_c_3));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin6_pad.PIN_TYPE = 6'b011001;
    defparam pin6_pad.PULLUP = 1'b0;
    defparam pin6_pad.NEG_TRIGGER = 1'b0;
    defparam pin6_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin5_pad (.PACKAGE_PIN(pin5), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin5_c_2));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin5_pad.PIN_TYPE = 6'b011001;
    defparam pin5_pad.PULLUP = 1'b0;
    defparam pin5_pad.NEG_TRIGGER = 1'b0;
    defparam pin5_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin4_pad (.PACKAGE_PIN(pin4), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin4_c_1));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin4_pad.PIN_TYPE = 6'b011001;
    defparam pin4_pad.PULLUP = 1'b0;
    defparam pin4_pad.NEG_TRIGGER = 1'b0;
    defparam pin4_pad.IO_STANDARD = "SB_LVCMOS";
    SB_IO pin3_pad (.PACKAGE_PIN(pin3), .OUTPUT_ENABLE(VCC_net), .D_OUT_0(pin3_c));   // /home/awhite/lscc/iCEcube2.2017.08/LSE/userware/unix/SYNTHESIS_HEADERS/sb_ice40.v(502[8:13])
    defparam pin3_pad.PIN_TYPE = 6'b011001;
    defparam pin3_pad.PULLUP = 1'b0;
    defparam pin3_pad.NEG_TRIGGER = 1'b0;
    defparam pin3_pad.IO_STANDARD = "SB_LVCMOS";
    \clock_divider(CLK_DIV_WIDTH=2,CLK_DIV_COUNT=3)  clkdiv_matrix (.GND_net(GND_net), 
            .clk_matrix(clk_matrix), .pin3_c(pin3_c), .pin17_ss_c_1(pin17_ss_c_1)) /* synthesis syn_module_defined=1 */ ;   // main.v(144[4] 148[3])
    control_module ctrl (.pin23_c_0(pin23_c_0), .pin24_c_1(pin24_c_1), .GND_net(GND_net), 
            .n1740(n1740), .pin14_sdo_c(pin14_sdo_c), .pin17_ss_c_1(pin17_ss_c_1), 
            .n15(n15), .pin16_sck_c_0(pin16_sck_c_0), .n1688(n1688), .pin7_out(pin7_out), 
            .pin15_sdi_c(pin15_sdi_c), .pinLED_c(pinLED_c), .pin3_c(pin3_c), 
            .clkdiv_baudrate_reset(clkdiv_baudrate_reset)) /* synthesis syn_module_defined=1 */ ;   // main.v(185[17] 211[3])
    \timeout(COUNTER_WIDTH=4)  timeout_global_reset (.pin3_c(pin3_c), .pin17_ss_c_1(pin17_ss_c_1), 
            .GND_net(GND_net), .pin14_sdo_c(pin14_sdo_c), .pin7_out(pin7_out), 
            .clkdiv_baudrate_reset(clkdiv_baudrate_reset)) /* synthesis syn_module_defined=1 */ ;   // main.v(131[4] 138[3])
    matrix_scan matscan1 (.pin17_ss_c_1(pin17_ss_c_1), .GND_net(GND_net), 
            .clk_matrix(clk_matrix), .pin22_c_0(pin22_c_0), .pin10_c(pin10_c), 
            .pin11_c(pin11_c), .pin6_c_3(pin6_c_3), .pin5_c_2(pin5_c_2), 
            .pin4_c_1(pin4_c_1), .output_enable(output_enable)) /* synthesis syn_module_defined=1 */ ;   // main.v(153[14] 164[3])
    VCC i1578 (.Y(VCC_net));
    
endmodule
//
// Verilog Description of module \clock_divider(CLK_DIV_WIDTH=2,CLK_DIV_COUNT=3) 
//

module \clock_divider(CLK_DIV_WIDTH=2,CLK_DIV_COUNT=3)  (GND_net, clk_matrix, 
            pin3_c, pin17_ss_c_1) /* synthesis syn_module_defined=1 */ ;
    input GND_net;
    output clk_matrix;
    input pin3_c;
    input pin17_ss_c_1;
    
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    wire [1:0]clk_count;   // clock_divider.v(13[28:37])
    
    wire n1610, clk_out_N_25, n1728;
    
    SB_LUT4 i1489_2_lut (.I0(clk_count[0]), .I1(clk_count[1]), .I2(GND_net), 
            .I3(GND_net), .O(n1610));
    defparam i1489_2_lut.LUT_INIT = 16'h1111;
    SB_DFFR clk_out_11 (.Q(clk_matrix), .C(pin3_c), .D(clk_out_N_25), 
            .R(pin17_ss_c_1));   // clock_divider.v(20[8] 28[6])
    SB_DFFR clk_count_351__i0 (.Q(clk_count[0]), .C(pin3_c), .D(n1610), 
            .R(pin17_ss_c_1));   // clock_divider.v(26[18:33])
    SB_DFFR clk_count_351__i1 (.Q(clk_count[1]), .C(pin3_c), .D(n1728), 
            .R(pin17_ss_c_1));   // clock_divider.v(26[18:33])
    SB_LUT4 i1_2_lut (.I0(clk_count[1]), .I1(clk_count[0]), .I2(GND_net), 
            .I3(GND_net), .O(n1728));   // clock_divider.v(26[18:33])
    defparam i1_2_lut.LUT_INIT = 16'h4444;
    SB_LUT4 i1_3_lut (.I0(clk_matrix), .I1(clk_count[0]), .I2(clk_count[1]), 
            .I3(GND_net), .O(clk_out_N_25));
    defparam i1_3_lut.LUT_INIT = 16'h9a9a;
    
endmodule
//
// Verilog Description of module control_module
//

module control_module (pin23_c_0, pin24_c_1, GND_net, n1740, pin14_sdo_c, 
            pin17_ss_c_1, n15, pin16_sck_c_0, n1688, pin7_out, pin15_sdi_c, 
            pinLED_c, pin3_c, clkdiv_baudrate_reset) /* synthesis syn_module_defined=1 */ ;
    output pin23_c_0;
    output pin24_c_1;
    input GND_net;
    output n1740;
    output pin14_sdo_c;
    input pin17_ss_c_1;
    output n15;
    output pin16_sck_c_0;
    input n1688;
    input pin7_out;
    output pin15_sdi_c;
    output pinLED_c;
    input pin3_c;
    input clkdiv_baudrate_reset;
    
    wire pin14_sdo_c /* synthesis is_clock=1, SET_AS_NETWORK=pin14_sdo_c */ ;   // main.v(19[9:18])
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    
    wire n3;
    wire [1:0]cmd_line_state2_1__N_235;
    wire [7:0]uart_rx_data;   // control_module.v(38[13:25])
    
    wire n27;
    wire [7:0]cmd_line_addr_col_7__N_242;
    
    wire n949;
    wire [7:0]cmd_line_addr_col;   // control_module.v(56[14:31])
    
    wire n988, VCC_net, n1605, n1604, n1603, n1602, n1601, n1600, 
        n1599, n1760;
    wire [2:0]n424;
    
    wire n10, n14, n1849;
    
    SB_LUT4 cmd_line_state2_1__I_0_84_i3_2_lut (.I0(pin23_c_0), .I1(pin24_c_1), 
            .I2(GND_net), .I3(GND_net), .O(n3));   // control_module.v(110[12:34])
    defparam cmd_line_state2_1__I_0_84_i3_2_lut.LUT_INIT = 16'hbbbb;
    SB_LUT4 i704_1_lut_2_lut (.I0(pin23_c_0), .I1(pin24_c_1), .I2(GND_net), 
            .I3(GND_net), .O(cmd_line_state2_1__N_235[0]));   // control_module.v(119[8] 158[6])
    defparam i704_1_lut_2_lut.LUT_INIT = 16'h4444;
    SB_LUT4 i3_4_lut (.I0(uart_rx_data[6]), .I1(uart_rx_data[2]), .I2(n27), 
            .I3(uart_rx_data[3]), .O(n1740));
    defparam i3_4_lut.LUT_INIT = 16'h0800;
    SB_LUT4 i12_3_lut (.I0(pin23_c_0), .I1(pin24_c_1), .I2(n1740), .I3(GND_net), 
            .O(cmd_line_state2_1__N_235[1]));   // control_module.v(119[8] 158[6])
    defparam i12_3_lut.LUT_INIT = 16'h9898;
    SB_DFFNER cmd_line_addr_col_i0 (.Q(cmd_line_addr_col[0]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[0]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i6 (.Q(cmd_line_addr_col[6]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[6]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i5 (.Q(cmd_line_addr_col[5]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[5]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i4 (.Q(cmd_line_addr_col[4]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[4]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i3 (.Q(cmd_line_addr_col[3]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[3]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i2 (.Q(cmd_line_addr_col[2]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[2]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i1 (.Q(cmd_line_addr_col[1]), .C(pin14_sdo_c), 
            .E(n949), .D(cmd_line_addr_col_7__N_242[1]), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNR cmd_line_state_i2 (.Q(pin24_c_1), .C(pin14_sdo_c), .D(cmd_line_state2_1__N_235[1]), 
            .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_LUT4 sub_28_add_2_9_lut (.I0(n3), .I1(cmd_line_addr_col[7]), .I2(VCC_net), 
            .I3(n1605), .O(n988)) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_9_lut.LUT_INIT = 16'h8228;
    SB_LUT4 sub_28_add_2_8_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[6]), 
            .I2(VCC_net), .I3(n1604), .O(cmd_line_addr_col_7__N_242[6])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_8_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_8 (.CI(n1604), .I0(cmd_line_addr_col[6]), .I1(VCC_net), 
            .CO(n1605));
    SB_LUT4 sub_28_add_2_7_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[5]), 
            .I2(VCC_net), .I3(n1603), .O(cmd_line_addr_col_7__N_242[5])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_7_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_7 (.CI(n1603), .I0(cmd_line_addr_col[5]), .I1(VCC_net), 
            .CO(n1604));
    SB_LUT4 sub_28_add_2_6_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[4]), 
            .I2(VCC_net), .I3(n1602), .O(cmd_line_addr_col_7__N_242[4])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_6_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_6 (.CI(n1602), .I0(cmd_line_addr_col[4]), .I1(VCC_net), 
            .CO(n1603));
    SB_LUT4 sub_28_add_2_5_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[3]), 
            .I2(VCC_net), .I3(n1601), .O(cmd_line_addr_col_7__N_242[3])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_5_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_5 (.CI(n1601), .I0(cmd_line_addr_col[3]), .I1(VCC_net), 
            .CO(n1602));
    SB_LUT4 sub_28_add_2_4_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[2]), 
            .I2(VCC_net), .I3(n1600), .O(cmd_line_addr_col_7__N_242[2])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_4_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_4 (.CI(n1600), .I0(cmd_line_addr_col[2]), .I1(VCC_net), 
            .CO(n1601));
    SB_LUT4 sub_28_add_2_3_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[1]), 
            .I2(VCC_net), .I3(n1599), .O(cmd_line_addr_col_7__N_242[1])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_3_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_3 (.CI(n1599), .I0(cmd_line_addr_col[1]), .I1(VCC_net), 
            .CO(n1600));
    SB_LUT4 sub_28_add_2_2_lut (.I0(cmd_line_state2_1__N_235[0]), .I1(cmd_line_addr_col[0]), 
            .I2(n15), .I3(VCC_net), .O(cmd_line_addr_col_7__N_242[0])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_28_add_2_2_lut.LUT_INIT = 16'hebbe;
    SB_CARRY sub_28_add_2_2 (.CI(VCC_net), .I0(cmd_line_addr_col[0]), .I1(n15), 
            .CO(n1599));
    SB_LUT4 i1473_2_lut (.I0(pin24_c_1), .I1(pin23_c_0), .I2(GND_net), 
            .I3(GND_net), .O(n1760));
    defparam i1473_2_lut.LUT_INIT = 16'h6666;
    SB_LUT4 i27_2_lut (.I0(pin23_c_0), .I1(pin24_c_1), .I2(GND_net), .I3(GND_net), 
            .O(n949));   // control_module.v(110[8] 158[6])
    defparam i27_2_lut.LUT_INIT = 16'h6666;
    SB_LUT4 i228_1_lut (.I0(uart_rx_data[5]), .I1(GND_net), .I2(GND_net), 
            .I3(GND_net), .O(n424[1]));
    defparam i228_1_lut.LUT_INIT = 16'h5555;
    SB_LUT4 i2_2_lut (.I0(cmd_line_addr_col[2]), .I1(cmd_line_addr_col[4]), 
            .I2(GND_net), .I3(GND_net), .O(n10));   // control_module.v(121[8:32])
    defparam i2_2_lut.LUT_INIT = 16'heeee;
    SB_LUT4 i6_4_lut (.I0(cmd_line_addr_col[3]), .I1(cmd_line_addr_col[1]), 
            .I2(cmd_line_addr_col[5]), .I3(cmd_line_addr_col[7]), .O(n14));   // control_module.v(121[8:32])
    defparam i6_4_lut.LUT_INIT = 16'hfffe;
    SB_DFFNES rgb_enable_i0_i1 (.Q(pin16_sck_c_0), .C(pin14_sdo_c), .E(n1849), 
            .D(n424[1]), .S(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_LUT4 i1499_4_lut (.I0(cmd_line_addr_col[0]), .I1(n14), .I2(n10), 
            .I3(cmd_line_addr_col[6]), .O(n15));   // control_module.v(121[8:32])
    defparam i1499_4_lut.LUT_INIT = 16'h0001;
    SB_DFFNR cmd_line_state_i1 (.Q(pin23_c_0), .C(pin14_sdo_c), .D(n1688), 
            .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    SB_DFFNER cmd_line_addr_col_i7 (.Q(cmd_line_addr_col[7]), .C(pin14_sdo_c), 
            .E(n1760), .D(n988), .R(pin17_ss_c_1));   // control_module.v(110[8] 158[6])
    \uart_rx(CLK_DIV_COUNT=25,CLK_DIV_WIDTH=8)  urx (.\uart_rx_data[5] (uart_rx_data[5]), 
            .n27(n27), .GND_net(GND_net), .pin7_out(pin7_out), .pin14_sdo_c(pin14_sdo_c), 
            .\uart_rx_data[6] (uart_rx_data[6]), .\uart_rx_data[3] (uart_rx_data[3]), 
            .\uart_rx_data[2] (uart_rx_data[2]), .n1849(n1849), .pin15_sdi_c(pin15_sdi_c), 
            .pinLED_c(pinLED_c), .pin17_ss_c_1(pin17_ss_c_1), .pin23_c_0(pin23_c_0), 
            .pin24_c_1(pin24_c_1), .pin3_c(pin3_c), .clkdiv_baudrate_reset(clkdiv_baudrate_reset)) /* synthesis syn_module_defined=1 */ ;   // control_module.v(62[4] 70[3])
    VCC i1 (.Y(VCC_net));
    
endmodule
//
// Verilog Description of module \uart_rx(CLK_DIV_COUNT=25,CLK_DIV_WIDTH=8) 
//

module \uart_rx(CLK_DIV_COUNT=25,CLK_DIV_WIDTH=8)  (\uart_rx_data[5] , n27, 
            GND_net, pin7_out, pin14_sdo_c, \uart_rx_data[6] , \uart_rx_data[3] , 
            \uart_rx_data[2] , n1849, pin15_sdi_c, pinLED_c, pin17_ss_c_1, 
            pin23_c_0, pin24_c_1, pin3_c, clkdiv_baudrate_reset) /* synthesis syn_module_defined=1 */ ;
    output \uart_rx_data[5] ;
    output n27;
    input GND_net;
    input pin7_out;
    output pin14_sdo_c;
    output \uart_rx_data[6] ;
    output \uart_rx_data[3] ;
    output \uart_rx_data[2] ;
    output n1849;
    output pin15_sdi_c;
    output pinLED_c;
    input pin17_ss_c_1;
    input pin23_c_0;
    input pin24_c_1;
    input pin3_c;
    input clkdiv_baudrate_reset;
    
    wire pin14_sdo_c /* synthesis is_clock=1, SET_AS_NETWORK=pin14_sdo_c */ ;   // main.v(19[9:18])
    wire clk_baudrate /* synthesis is_clock=1, SET_AS_NETWORK=\ctrl/urx/clk_baudrate */ ;   // uart_rx.v(34[7:19])
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    wire [7:0]uart_rx_data;   // control_module.v(38[13:25])
    
    wire n6;
    wire [8:0]rx_bitstream;   // uart_rx.v(26[29:41])
    
    wire n990, n1403, n992, n993, n994, n995, n996, n997, n999, 
        n1746, n1754, n6_adj_570;
    
    SB_LUT4 i4_4_lut (.I0(uart_rx_data[7]), .I1(uart_rx_data[0]), .I2(\uart_rx_data[5] ), 
            .I3(n6), .O(n27));   // uart_rx.v(72[8] 74[6])
    defparam i4_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i1_2_lut (.I0(uart_rx_data[1]), .I1(uart_rx_data[4]), .I2(GND_net), 
            .I3(GND_net), .O(n6));   // uart_rx.v(72[8] 74[6])
    defparam i1_2_lut.LUT_INIT = 16'heeee;
    SB_LUT4 i1140_3_lut (.I0(rx_bitstream[8]), .I1(pin7_out), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n990));   // main.v(19[9:18])
    defparam i1140_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1139_3_lut (.I0(uart_rx_data[7]), .I1(rx_bitstream[8]), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n1403));   // main.v(19[9:18])
    defparam i1139_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1150_3_lut (.I0(\uart_rx_data[6] ), .I1(uart_rx_data[7]), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n992));   // main.v(19[9:18])
    defparam i1150_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1148_3_lut (.I0(\uart_rx_data[5] ), .I1(\uart_rx_data[6] ), 
            .I2(pin14_sdo_c), .I3(GND_net), .O(n993));   // main.v(19[9:18])
    defparam i1148_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1141_3_lut (.I0(uart_rx_data[4]), .I1(\uart_rx_data[5] ), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n994));   // main.v(19[9:18])
    defparam i1141_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1149_3_lut (.I0(\uart_rx_data[3] ), .I1(uart_rx_data[4]), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n995));   // main.v(19[9:18])
    defparam i1149_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1142_3_lut (.I0(\uart_rx_data[2] ), .I1(\uart_rx_data[3] ), 
            .I2(pin14_sdo_c), .I3(GND_net), .O(n996));   // main.v(19[9:18])
    defparam i1142_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1151_3_lut (.I0(uart_rx_data[1]), .I1(\uart_rx_data[2] ), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n997));   // main.v(19[9:18])
    defparam i1151_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1152_3_lut (.I0(uart_rx_data[0]), .I1(uart_rx_data[1]), .I2(pin14_sdo_c), 
            .I3(GND_net), .O(n999));   // main.v(19[9:18])
    defparam i1152_3_lut.LUT_INIT = 16'hcaca;
    SB_LUT4 i1467_4_lut (.I0(uart_rx_data[0]), .I1(\uart_rx_data[2] ), .I2(\uart_rx_data[3] ), 
            .I3(n1746), .O(n1754));
    defparam i1467_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i3_4_lut (.I0(\uart_rx_data[6] ), .I1(uart_rx_data[4]), .I2(uart_rx_data[1]), 
            .I3(n1754), .O(n1849));
    defparam i3_4_lut.LUT_INIT = 16'h0080;
    SB_LUT4 i1_2_lut_adj_14 (.I0(\uart_rx_data[2] ), .I1(n27), .I2(GND_net), 
            .I3(GND_net), .O(n6_adj_570));
    defparam i1_2_lut_adj_14.LUT_INIT = 16'heeee;
    SB_LUT4 i1478_4_lut (.I0(rx_bitstream[8]), .I1(\uart_rx_data[6] ), .I2(\uart_rx_data[3] ), 
            .I3(n6_adj_570), .O(pin15_sdi_c));
    defparam i1478_4_lut.LUT_INIT = 16'h0001;
    SB_LUT4 pin7_I_0_1_lut (.I0(pin7_out), .I1(GND_net), .I2(GND_net), 
            .I3(GND_net), .O(pinLED_c));   // main.v(276[35:41])
    defparam pin7_I_0_1_lut.LUT_INIT = 16'h5555;
    SB_DFFR rx_bitstream__i1 (.Q(uart_rx_data[0]), .C(clk_baudrate), .D(n999), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i2 (.Q(uart_rx_data[1]), .C(clk_baudrate), .D(n997), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i3 (.Q(\uart_rx_data[2] ), .C(clk_baudrate), .D(n996), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i4 (.Q(\uart_rx_data[3] ), .C(clk_baudrate), .D(n995), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i5 (.Q(uart_rx_data[4]), .C(clk_baudrate), .D(n994), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i6 (.Q(\uart_rx_data[5] ), .C(clk_baudrate), .D(n993), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i7 (.Q(\uart_rx_data[6] ), .C(clk_baudrate), .D(n992), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i8 (.Q(uart_rx_data[7]), .C(clk_baudrate), .D(n1403), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_DFFR rx_bitstream__i9 (.Q(rx_bitstream[8]), .C(clk_baudrate), .D(n990), 
            .R(pin17_ss_c_1));   // uart_rx.v(72[8] 74[6])
    SB_LUT4 i1459_2_lut_3_lut (.I0(uart_rx_data[7]), .I1(pin23_c_0), .I2(pin24_c_1), 
            .I3(GND_net), .O(n1746));
    defparam i1459_2_lut_3_lut.LUT_INIT = 16'hbebe;
    \timeout(COUNTER_WIDTH=32'b0100)  rx_running_I_0_16 (.pin14_sdo_c(pin14_sdo_c), 
            .pin7_out(pin7_out), .GND_net(GND_net), .clk_baudrate(clk_baudrate), 
            .pin17_ss_c_1(pin17_ss_c_1)) /* synthesis syn_module_defined=1 */ ;   // uart_rx.v(56[4] 64[3])
    \clock_divider(CLK_DIV_COUNT=25)  clkdiv_baudrate (.clk_baudrate(clk_baudrate), 
            .GND_net(GND_net), .pin3_c(pin3_c), .clkdiv_baudrate_reset(clkdiv_baudrate_reset)) /* synthesis syn_module_defined=1 */ ;   // uart_rx.v(44[4] 50[3])
    
endmodule
//
// Verilog Description of module \timeout(COUNTER_WIDTH=32'b0100) 
//

module \timeout(COUNTER_WIDTH=32'b0100)  (pin14_sdo_c, pin7_out, GND_net, 
            clk_baudrate, pin17_ss_c_1) /* synthesis syn_module_defined=1 */ ;
    output pin14_sdo_c;
    input pin7_out;
    input GND_net;
    input clk_baudrate;
    input pin17_ss_c_1;
    
    wire pin14_sdo_c /* synthesis is_clock=1, SET_AS_NETWORK=pin14_sdo_c */ ;   // main.v(19[9:18])
    wire clk_baudrate /* synthesis is_clock=1, SET_AS_NETWORK=\ctrl/urx/clk_baudrate */ ;   // uart_rx.v(34[7:19])
    
    wire start_latch, n1212;
    wire [3:0]counter;   // timeout.v(17[35:42])
    wire [3:0]counter_3__N_332;
    
    wire timeout_word_start, n4, n967;
    
    SB_LUT4 i948_2_lut_3_lut (.I0(pin14_sdo_c), .I1(pin7_out), .I2(start_latch), 
            .I3(GND_net), .O(n1212));
    defparam i948_2_lut_3_lut.LUT_INIT = 16'hfefe;
    SB_LUT4 i3_3_lut_4_lut (.I0(counter[1]), .I1(counter[0]), .I2(counter[2]), 
            .I3(counter[3]), .O(pin14_sdo_c));   // timeout.v(34[13:25])
    defparam i3_3_lut_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i950_3_lut_4_lut (.I0(counter[0]), .I1(pin14_sdo_c), .I2(pin7_out), 
            .I3(start_latch), .O(counter_3__N_332[0]));   // timeout.v(34[9] 36[7])
    defparam i950_3_lut_4_lut.LUT_INIT = 16'h6664;
    SB_DFFNR counter_i0 (.Q(counter[0]), .C(clk_baudrate), .D(counter_3__N_332[0]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_LUT4 i947_3_lut_4_lut (.I0(counter[2]), .I1(timeout_word_start), 
            .I2(start_latch), .I3(n4), .O(counter_3__N_332[2]));   // timeout.v(34[9] 36[7])
    defparam i947_3_lut_4_lut.LUT_INIT = 16'ha251;
    SB_DFFNR start_latch_14 (.Q(start_latch), .C(clk_baudrate), .D(timeout_word_start), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFNER counter_i3 (.Q(counter[3]), .C(clk_baudrate), .E(n967), 
            .D(counter_3__N_332[3]), .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFNER counter_i2 (.Q(counter[2]), .C(clk_baudrate), .E(n967), 
            .D(counter_3__N_332[2]), .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFNER counter_i1 (.Q(counter[1]), .C(clk_baudrate), .E(n967), 
            .D(counter_3__N_332[1]), .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_LUT4 i1_2_lut_3_lut_3_lut (.I0(pin14_sdo_c), .I1(pin7_out), .I2(start_latch), 
            .I3(GND_net), .O(n967));
    defparam i1_2_lut_3_lut_3_lut.LUT_INIT = 16'habab;
    SB_LUT4 i1492_4_lut (.I0(counter[3]), .I1(n1212), .I2(counter[2]), 
            .I3(n4), .O(counter_3__N_332[3]));
    defparam i1492_4_lut.LUT_INIT = 16'hbbb7;
    SB_LUT4 i403_2_lut (.I0(counter[1]), .I1(counter[0]), .I2(GND_net), 
            .I3(GND_net), .O(n4));   // timeout.v(35[16:29])
    defparam i403_2_lut.LUT_INIT = 16'heeee;
    SB_LUT4 i921_3_lut_4_lut (.I0(counter[1]), .I1(timeout_word_start), 
            .I2(start_latch), .I3(counter[0]), .O(counter_3__N_332[1]));   // timeout.v(34[9] 36[7])
    defparam i921_3_lut_4_lut.LUT_INIT = 16'ha251;
    SB_LUT4 i1482_2_lut (.I0(pin14_sdo_c), .I1(pin7_out), .I2(GND_net), 
            .I3(GND_net), .O(timeout_word_start));   // timeout.v(34[13:25])
    defparam i1482_2_lut.LUT_INIT = 16'h1111;
    
endmodule
//
// Verilog Description of module \clock_divider(CLK_DIV_COUNT=25) 
//

module \clock_divider(CLK_DIV_COUNT=25)  (clk_baudrate, GND_net, pin3_c, 
            clkdiv_baudrate_reset) /* synthesis syn_module_defined=1 */ ;
    output clk_baudrate;
    input GND_net;
    input pin3_c;
    input clkdiv_baudrate_reset;
    
    wire clk_baudrate /* synthesis is_clock=1, SET_AS_NETWORK=\ctrl/urx/clk_baudrate */ ;   // uart_rx.v(34[7:19])
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    
    wire n1154, clk_out_N_331;
    wire [7:0]clk_count;   // clock_divider.v(13[28:37])
    
    wire n1748;
    wire [4:0]n32;
    
    wire n1592, n1591, n1590, n1589, VCC_net;
    
    SB_LUT4 i1471_2_lut (.I0(n1154), .I1(clk_baudrate), .I2(GND_net), 
            .I3(GND_net), .O(clk_out_N_331));   // uart_rx.v(34[7:19])
    defparam i1471_2_lut.LUT_INIT = 16'h9999;
    SB_LUT4 i1461_2_lut (.I0(clk_count[4]), .I1(clk_count[3]), .I2(GND_net), 
            .I3(GND_net), .O(n1748));
    defparam i1461_2_lut.LUT_INIT = 16'h8888;
    SB_LUT4 i3_4_lut (.I0(clk_count[0]), .I1(clk_count[2]), .I2(clk_count[1]), 
            .I3(n1748), .O(n1154));   // clock_divider.v(26[18:33])
    defparam i3_4_lut.LUT_INIT = 16'hfeff;
    SB_DFFR clk_count_354_355__i1 (.Q(clk_count[0]), .C(pin3_c), .D(n32[0]), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(26[18:33])
    SB_LUT4 clk_count_354_355_add_4_6_lut (.I0(n1154), .I1(GND_net), .I2(clk_count[4]), 
            .I3(n1592), .O(n32[4])) /* synthesis syn_instantiated=1 */ ;
    defparam clk_count_354_355_add_4_6_lut.LUT_INIT = 16'h8228;
    SB_DFFR clk_count_354_355__i5 (.Q(clk_count[4]), .C(pin3_c), .D(n32[4]), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(26[18:33])
    SB_DFFR clk_count_354_355__i4 (.Q(clk_count[3]), .C(pin3_c), .D(n32[3]), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(26[18:33])
    SB_DFFR clk_count_354_355__i3 (.Q(clk_count[2]), .C(pin3_c), .D(n32[2]), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(26[18:33])
    SB_LUT4 clk_count_354_355_add_4_5_lut (.I0(n1154), .I1(GND_net), .I2(clk_count[3]), 
            .I3(n1591), .O(n32[3])) /* synthesis syn_instantiated=1 */ ;
    defparam clk_count_354_355_add_4_5_lut.LUT_INIT = 16'h8228;
    SB_CARRY clk_count_354_355_add_4_5 (.CI(n1591), .I0(GND_net), .I1(clk_count[3]), 
            .CO(n1592));
    SB_DFFR clk_count_354_355__i2 (.Q(clk_count[1]), .C(pin3_c), .D(n32[1]), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(26[18:33])
    SB_LUT4 clk_count_354_355_add_4_4_lut (.I0(n1154), .I1(GND_net), .I2(clk_count[2]), 
            .I3(n1590), .O(n32[2])) /* synthesis syn_instantiated=1 */ ;
    defparam clk_count_354_355_add_4_4_lut.LUT_INIT = 16'h8228;
    SB_DFFR clk_out_11 (.Q(clk_baudrate), .C(pin3_c), .D(clk_out_N_331), 
            .R(clkdiv_baudrate_reset));   // clock_divider.v(20[8] 28[6])
    SB_CARRY clk_count_354_355_add_4_4 (.CI(n1590), .I0(GND_net), .I1(clk_count[2]), 
            .CO(n1591));
    SB_LUT4 clk_count_354_355_add_4_3_lut (.I0(n1154), .I1(GND_net), .I2(clk_count[1]), 
            .I3(n1589), .O(n32[1])) /* synthesis syn_instantiated=1 */ ;
    defparam clk_count_354_355_add_4_3_lut.LUT_INIT = 16'h8228;
    SB_CARRY clk_count_354_355_add_4_3 (.CI(n1589), .I0(GND_net), .I1(clk_count[1]), 
            .CO(n1590));
    SB_LUT4 clk_count_354_355_add_4_2_lut (.I0(n1154), .I1(GND_net), .I2(clk_count[0]), 
            .I3(VCC_net), .O(n32[0])) /* synthesis syn_instantiated=1 */ ;
    defparam clk_count_354_355_add_4_2_lut.LUT_INIT = 16'h8228;
    SB_CARRY clk_count_354_355_add_4_2 (.CI(VCC_net), .I0(GND_net), .I1(clk_count[0]), 
            .CO(n1589));
    VCC i1 (.Y(VCC_net));
    
endmodule
//
// Verilog Description of module \timeout(COUNTER_WIDTH=4) 
//

module \timeout(COUNTER_WIDTH=4)  (pin3_c, pin17_ss_c_1, GND_net, pin14_sdo_c, 
            pin7_out, clkdiv_baudrate_reset) /* synthesis syn_module_defined=1 */ ;
    input pin3_c;
    output pin17_ss_c_1;
    input GND_net;
    input pin14_sdo_c;
    input pin7_out;
    output clkdiv_baudrate_reset;
    
    wire pin3_c /* synthesis SET_AS_NETWORK=pin3_c, is_clock=1 */ ;   // main.v(8[9:13])
    wire pin14_sdo_c /* synthesis is_clock=1, SET_AS_NETWORK=pin14_sdo_c */ ;   // main.v(19[9:18])
    
    wire n1639;
    wire [3:0]counter;   // timeout.v(17[35:42])
    wire [3:0]n21;
    
    wire n1643, n2, n1637;
    
    SB_DFF counter_350__i1 (.Q(counter[1]), .C(pin3_c), .D(n1639));   // timeout.v(35[16:29])
    SB_LUT4 i1_2_lut (.I0(pin17_ss_c_1), .I1(counter[0]), .I2(GND_net), 
            .I3(GND_net), .O(n21[0]));
    defparam i1_2_lut.LUT_INIT = 16'h6666;
    SB_DFF counter_350__i3 (.Q(counter[3]), .C(pin3_c), .D(n1643));   // timeout.v(35[16:29])
    SB_LUT4 i1_2_lut_3_lut (.I0(counter[1]), .I1(pin17_ss_c_1), .I2(counter[0]), 
            .I3(GND_net), .O(n1639));
    defparam i1_2_lut_3_lut.LUT_INIT = 16'ha6a6;
    SB_LUT4 i1_3_lut_4_lut (.I0(counter[1]), .I1(n2), .I2(counter[2]), 
            .I3(counter[3]), .O(n1643));   // timeout.v(35[16:29])
    defparam i1_3_lut_4_lut.LUT_INIT = 16'hfe01;
    SB_DFF counter_350__i2 (.Q(counter[2]), .C(pin3_c), .D(n1637));   // timeout.v(35[16:29])
    SB_DFF counter_350__i0 (.Q(counter[0]), .C(pin3_c), .D(n21[0]));   // timeout.v(35[16:29])
    SB_LUT4 i3_4_lut (.I0(counter[0]), .I1(counter[2]), .I2(counter[1]), 
            .I3(counter[3]), .O(pin17_ss_c_1));   // timeout.v(34[13:25])
    defparam i3_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i1_3_lut (.I0(pin17_ss_c_1), .I1(pin14_sdo_c), .I2(pin7_out), 
            .I3(GND_net), .O(clkdiv_baudrate_reset));   // timeout.v(34[13:25])
    defparam i1_3_lut.LUT_INIT = 16'hbaba;
    SB_LUT4 i1265_2_lut (.I0(pin17_ss_c_1), .I1(counter[0]), .I2(GND_net), 
            .I3(GND_net), .O(n2));   // timeout.v(35[16:29])
    defparam i1265_2_lut.LUT_INIT = 16'hdddd;
    SB_LUT4 i1_2_lut_3_lut_4_lut (.I0(counter[1]), .I1(pin17_ss_c_1), .I2(counter[0]), 
            .I3(counter[2]), .O(n1637));   // timeout.v(35[16:29])
    defparam i1_2_lut_3_lut_4_lut.LUT_INIT = 16'hfb04;
    
endmodule
//
// Verilog Description of module matrix_scan
//

module matrix_scan (pin17_ss_c_1, GND_net, clk_matrix, pin22_c_0, pin10_c, 
            pin11_c, pin6_c_3, pin5_c_2, pin4_c_1, output_enable) /* synthesis syn_module_defined=1 */ ;
    input pin17_ss_c_1;
    input GND_net;
    input clk_matrix;
    output pin22_c_0;
    output pin10_c;
    output pin11_c;
    output pin6_c_3;
    output pin5_c_2;
    output pin4_c_1;
    output output_enable;
    
    wire row_latch_N_50 /* synthesis is_clock=1, SET_AS_NETWORK=\matscan1/row_latch_N_50 */ ;   // matrix_scan.v(30[13:31])
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    wire pin11_c /* synthesis is_inv_clock=1 */ ;   // main.v(16[9:14])
    wire [5:0]brightness_mask_5__N_30;
    wire [5:0]brightness_mask;   // main.v(71[13:28])
    wire [9:0]brightness_counter;   // matrix_scan.v(30[13:31])
    
    wire n4;
    wire [1:0]row_latch_state;   // matrix_scan.v(24[13:28])
    
    wire clk_pixel_load_en;
    wire [5:0]brightness_mask_active;   // matrix_scan.v(28[13:35])
    
    wire state_advance;
    wire [1:0]state;   // matrix_scan.v(18[12:17])
    wire [10:0]ram_b_address;   // main.v(58[14:27])
    
    wire VCC_net, n821, n1225, n925;
    wire [9:0]brightness_timeout;   // matrix_scan.v(29[13:31])
    
    wire n1563;
    wire [3:0]n21;
    
    wire n1744, n48, n37, n918, n824, n7, n9, clk_state, n1645, 
        n926, n920, n23_adj_569, n927, n6, n1120, counter_6__N_86, 
        n10, start_latch;
    
    SB_DFFNR brightness_mask_i0 (.Q(brightness_mask[0]), .C(row_latch_N_50), 
            .D(brightness_mask_5__N_30[0]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i1_2_lut (.I0(brightness_counter[9]), .I1(brightness_counter[7]), 
            .I2(GND_net), .I3(GND_net), .O(n4));   // matrix_scan.v(98[25:87])
    defparam i1_2_lut.LUT_INIT = 16'heeee;
    SB_DFFN row_latch_state_i1 (.Q(row_latch_state[1]), .C(clk_matrix), 
            .D(row_latch_state[0]));   // matrix_scan.v(67[9] 70[5])
    SB_DFFN row_latch_state_i0 (.Q(row_latch_state[0]), .C(clk_matrix), 
            .D(clk_pixel_load_en));   // matrix_scan.v(67[9] 70[5])
    SB_DFFNR brightness_mask_active_i0 (.Q(brightness_mask_active[0]), .C(row_latch_N_50), 
            .D(brightness_mask[0]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_DFFS state_i0 (.Q(state[0]), .C(clk_matrix), .D(state_advance), 
            .S(pin17_ss_c_1));   // matrix_scan.v(105[8] 107[6])
    SB_DFFNER row_address_active_i1 (.Q(pin22_c_0), .C(row_latch_N_50), 
            .E(VCC_net), .D(ram_b_address[6]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i977_3_lut (.I0(n821), .I1(n1225), .I2(n925), .I3(GND_net), 
            .O(brightness_timeout[4]));
    defparam i977_3_lut.LUT_INIT = 16'h7f7f;
    SB_LUT4 i1302_2_lut_3_lut (.I0(brightness_mask_5__N_30[5]), .I1(ram_b_address[6]), 
            .I2(ram_b_address[7]), .I3(GND_net), .O(n1563));   // matrix_scan.v(125[20:38])
    defparam i1302_2_lut_3_lut.LUT_INIT = 16'h8080;
    SB_LUT4 i1306_2_lut_4_lut (.I0(ram_b_address[8]), .I1(brightness_mask_5__N_30[5]), 
            .I2(ram_b_address[6]), .I3(ram_b_address[7]), .O(n21[2]));   // matrix_scan.v(125[20:38])
    defparam i1306_2_lut_4_lut.LUT_INIT = 16'h6aaa;
    SB_LUT4 i1_4_lut (.I0(brightness_mask_5__N_30[2]), .I1(n1744), .I2(brightness_mask_5__N_30[3]), 
            .I3(n48), .O(n37));   // matrix_scan.v(74[3] 80[8])
    defparam i1_4_lut.LUT_INIT = 16'h1712;
    SB_LUT4 i1_2_lut_3_lut_4_lut (.I0(brightness_mask_active[0]), .I1(brightness_mask[0]), 
            .I2(brightness_mask_5__N_30[0]), .I3(brightness_mask[2]), .O(n918));   // matrix_scan.v(78[3:40])
    defparam i1_2_lut_3_lut_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i1457_4_lut (.I0(brightness_mask[2]), .I1(brightness_mask[0]), 
            .I2(brightness_mask_5__N_30[0]), .I3(brightness_mask_active[0]), 
            .O(n1744));
    defparam i1457_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i961_2_lut_4_lut (.I0(n918), .I1(brightness_mask_5__N_30[2]), 
            .I2(brightness_mask_5__N_30[3]), .I3(n824), .O(n1225));   // matrix_scan.v(78[3:40])
    defparam i961_2_lut_4_lut.LUT_INIT = 16'hfb00;
    SB_LUT4 i966_4_lut (.I0(n925), .I1(n918), .I2(brightness_mask_5__N_30[2]), 
            .I3(brightness_mask_5__N_30[3]), .O(brightness_timeout[6]));
    defparam i966_4_lut.LUT_INIT = 16'h5775;
    SB_LUT4 i2_3_lut_4_lut (.I0(brightness_mask_active[0]), .I1(n7), .I2(n9), 
            .I3(brightness_mask[2]), .O(n824));   // matrix_scan.v(78[3:40])
    defparam i2_3_lut_4_lut.LUT_INIT = 16'hfeff;
    SB_LUT4 i1_2_lut_adj_8 (.I0(state[0]), .I1(state[1]), .I2(GND_net), 
            .I3(GND_net), .O(clk_state));   // matrix_scan.v(105[8] 107[6])
    defparam i1_2_lut_adj_8.LUT_INIT = 16'h4444;
    SB_DFFNR row_address_352__i1 (.Q(ram_b_address[6]), .C(row_latch_N_50), 
            .D(n1645), .R(pin17_ss_c_1));   // matrix_scan.v(125[20:38])
    SB_DFFNR row_address_352__i4 (.Q(ram_b_address[9]), .C(row_latch_N_50), 
            .D(n21[3]), .R(pin17_ss_c_1));   // matrix_scan.v(125[20:38])
    SB_DFFNR row_address_352__i3 (.Q(ram_b_address[8]), .C(row_latch_N_50), 
            .D(n21[2]), .R(pin17_ss_c_1));   // matrix_scan.v(125[20:38])
    SB_DFFNR row_address_352__i2 (.Q(ram_b_address[7]), .C(row_latch_N_50), 
            .D(n21[1]), .R(pin17_ss_c_1));   // matrix_scan.v(125[20:38])
    SB_DFFNR brightness_mask_i5 (.Q(brightness_mask_5__N_30[4]), .C(row_latch_N_50), 
            .D(brightness_mask_5__N_30[5]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i1_4_lut_4_lut (.I0(brightness_mask_active[0]), .I1(brightness_mask_5__N_30[0]), 
            .I2(brightness_mask[0]), .I3(brightness_mask[2]), .O(n48));   // matrix_scan.v(74[3] 80[8])
    defparam i1_4_lut_4_lut.LUT_INIT = 16'h0116;
    SB_LUT4 i972_3_lut (.I0(n926), .I1(n1225), .I2(n920), .I3(GND_net), 
            .O(brightness_timeout[5]));
    defparam i972_3_lut.LUT_INIT = 16'h7f7f;
    SB_LUT4 clk_in_I_0_2_lut (.I0(clk_matrix), .I1(row_latch_state[0]), 
            .I2(GND_net), .I3(GND_net), .O(pin10_c));   // matrix_scan.v(33[21:43])
    defparam clk_in_I_0_2_lut.LUT_INIT = 16'h8888;
    SB_LUT4 i1505_3_lut_4_lut (.I0(brightness_counter[9]), .I1(brightness_counter[7]), 
            .I2(brightness_counter[8]), .I3(n23_adj_569), .O(state_advance));   // matrix_scan.v(98[25:87])
    defparam i1505_3_lut_4_lut.LUT_INIT = 16'hfeff;
    SB_LUT4 row_latch_state_1__I_0_i3_2_lut (.I0(row_latch_state[0]), .I1(row_latch_state[1]), 
            .I2(GND_net), .I3(GND_net), .O(row_latch_N_50));   // matrix_scan.v(34[21:50])
    defparam row_latch_state_1__I_0_i3_2_lut.LUT_INIT = 16'hbbbb;
    SB_LUT4 i36_3_lut_4_lut (.I0(brightness_counter[1]), .I1(n927), .I2(brightness_counter[0]), 
            .I3(brightness_counter[6]), .O(n23_adj_569));   // matrix_scan.v(98[25:87])
    defparam i36_3_lut_4_lut.LUT_INIT = 16'h33fe;
    SB_LUT4 row_latch_state_1__I_0_i4_1_lut_2_lut (.I0(row_latch_state[0]), 
            .I1(row_latch_state[1]), .I2(GND_net), .I3(GND_net), .O(pin11_c));   // matrix_scan.v(34[21:50])
    defparam row_latch_state_1__I_0_i4_1_lut_2_lut.LUT_INIT = 16'h4444;
    SB_LUT4 i1313_3_lut (.I0(ram_b_address[9]), .I1(ram_b_address[8]), .I2(n1563), 
            .I3(GND_net), .O(n21[3]));   // matrix_scan.v(125[20:38])
    defparam i1313_3_lut.LUT_INIT = 16'h6a6a;
    SB_LUT4 i1_2_lut_adj_9 (.I0(brightness_mask[2]), .I1(brightness_mask_5__N_30[3]), 
            .I2(GND_net), .I3(GND_net), .O(n6));
    defparam i1_2_lut_adj_9.LUT_INIT = 16'heeee;
    SB_LUT4 i1495_4_lut (.I0(brightness_mask_5__N_30[4]), .I1(brightness_mask_5__N_30[0]), 
            .I2(brightness_mask_5__N_30[2]), .I3(n6), .O(brightness_mask_5__N_30[5]));
    defparam i1495_4_lut.LUT_INIT = 16'h0001;
    SB_DFFNR brightness_mask_i4 (.Q(brightness_mask_5__N_30[3]), .C(row_latch_N_50), 
            .D(brightness_mask_5__N_30[4]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i1_2_lut_adj_10 (.I0(brightness_mask_5__N_30[5]), .I1(ram_b_address[6]), 
            .I2(GND_net), .I3(GND_net), .O(n1645));
    defparam i1_2_lut_adj_10.LUT_INIT = 16'h6666;
    SB_DFFNR brightness_mask_i3 (.Q(brightness_mask_5__N_30[2]), .C(row_latch_N_50), 
            .D(brightness_mask_5__N_30[3]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_DFFNR brightness_mask_i2 (.Q(brightness_mask[2]), .C(row_latch_N_50), 
            .D(brightness_mask_5__N_30[2]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_DFFR state_i1 (.Q(state[1]), .C(clk_matrix), .D(state[0]), .R(pin17_ss_c_1));   // matrix_scan.v(105[8] 107[6])
    SB_LUT4 i855_1_lut (.I0(n1120), .I1(GND_net), .I2(GND_net), .I3(GND_net), 
            .O(counter_6__N_86));   // matrix_scan.v(105[8] 107[6])
    defparam i855_1_lut.LUT_INIT = 16'h5555;
    SB_LUT4 equal_15_i12_1_lut (.I0(n920), .I1(GND_net), .I2(GND_net), 
            .I3(GND_net), .O(brightness_timeout[9]));   // matrix_scan.v(79[3:40])
    defparam equal_15_i12_1_lut.LUT_INIT = 16'h5555;
    SB_LUT4 i2_3_lut_4_lut_adj_11 (.I0(n10), .I1(brightness_mask[0]), .I2(brightness_mask_5__N_30[0]), 
            .I3(brightness_mask_active[0]), .O(n821));   // matrix_scan.v(74[3:40])
    defparam i2_3_lut_4_lut_adj_11.LUT_INIT = 16'hfeff;
    SB_DFFNR brightness_mask_i1 (.Q(brightness_mask_5__N_30[0]), .C(row_latch_N_50), 
            .D(brightness_mask[2]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_DFFNER row_address_active_i4 (.Q(pin6_c_3), .C(row_latch_N_50), .E(VCC_net), 
            .D(ram_b_address[9]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_DFFNER row_address_active_i3 (.Q(pin5_c_2), .C(row_latch_N_50), .E(VCC_net), 
            .D(ram_b_address[8]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i2_3_lut (.I0(n918), .I1(brightness_mask_5__N_30[2]), .I2(brightness_mask_5__N_30[3]), 
            .I3(GND_net), .O(n920));   // matrix_scan.v(79[3:40])
    defparam i2_3_lut.LUT_INIT = 16'hefef;
    SB_LUT4 brightness_mask_active_5__I_0_46_i10_2_lut_3_lut (.I0(brightness_mask[2]), 
            .I1(brightness_mask_5__N_30[2]), .I2(brightness_mask_5__N_30[3]), 
            .I3(GND_net), .O(n10));   // matrix_scan.v(74[3:40])
    defparam brightness_mask_active_5__I_0_46_i10_2_lut_3_lut.LUT_INIT = 16'hfefe;
    SB_LUT4 i1_3_lut (.I0(state[0]), .I1(start_latch), .I2(state[1]), 
            .I3(GND_net), .O(n1120));   // matrix_scan.v(105[8] 107[6])
    defparam i1_3_lut.LUT_INIT = 16'hefef;
    SB_LUT4 brightness_mask_active_5__I_0_46_i9_2_lut (.I0(brightness_mask_5__N_30[2]), 
            .I1(brightness_mask_5__N_30[3]), .I2(GND_net), .I3(GND_net), 
            .O(n9));   // matrix_scan.v(74[3:40])
    defparam brightness_mask_active_5__I_0_46_i9_2_lut.LUT_INIT = 16'heeee;
    SB_DFFNER row_address_active_i2 (.Q(pin4_c_1), .C(row_latch_N_50), .E(VCC_net), 
            .D(ram_b_address[7]), .R(pin17_ss_c_1));   // matrix_scan.v(118[8] 130[6])
    SB_LUT4 i2_3_lut_4_lut_adj_12 (.I0(brightness_mask_active[0]), .I1(n10), 
            .I2(brightness_mask[0]), .I3(brightness_mask_5__N_30[0]), .O(n926));   // matrix_scan.v(76[3:40])
    defparam i2_3_lut_4_lut_adj_12.LUT_INIT = 16'hffef;
    SB_LUT4 i931_2_lut (.I0(n920), .I1(n824), .I2(GND_net), .I3(GND_net), 
            .O(brightness_timeout[7]));
    defparam i931_2_lut.LUT_INIT = 16'h7777;
    SB_LUT4 i956_3_lut (.I0(n925), .I1(n926), .I2(n824), .I3(GND_net), 
            .O(brightness_timeout[3]));
    defparam i956_3_lut.LUT_INIT = 16'h7f7f;
    SB_LUT4 equal_14_i12_1_lut_3_lut (.I0(n918), .I1(brightness_mask_5__N_30[2]), 
            .I2(brightness_mask_5__N_30[3]), .I3(GND_net), .O(brightness_timeout[8]));   // matrix_scan.v(78[3:40])
    defparam equal_14_i12_1_lut_3_lut.LUT_INIT = 16'h0404;
    SB_LUT4 i941_2_lut_3_lut (.I0(n926), .I1(n821), .I2(n925), .I3(GND_net), 
            .O(brightness_timeout[2]));
    defparam i941_2_lut_3_lut.LUT_INIT = 16'h7f7f;
    SB_LUT4 i917_1_lut_2_lut (.I0(n926), .I1(n821), .I2(GND_net), .I3(GND_net), 
            .O(brightness_timeout[1]));
    defparam i917_1_lut_2_lut.LUT_INIT = 16'h7777;
    SB_LUT4 i2_3_lut_4_lut_adj_13 (.I0(brightness_mask_active[0]), .I1(n10), 
            .I2(brightness_mask[0]), .I3(brightness_mask_5__N_30[0]), .O(n925));   // matrix_scan.v(76[3:40])
    defparam i2_3_lut_4_lut_adj_13.LUT_INIT = 16'hfeff;
    SB_LUT4 brightness_mask_active_5__I_0_46_i7_2_lut (.I0(brightness_mask[0]), 
            .I1(brightness_mask_5__N_30[0]), .I2(GND_net), .I3(GND_net), 
            .O(n7));   // matrix_scan.v(74[3:40])
    defparam brightness_mask_active_5__I_0_46_i7_2_lut.LUT_INIT = 16'heeee;
    SB_LUT4 i1299_2_lut_3_lut (.I0(brightness_mask_5__N_30[5]), .I1(ram_b_address[6]), 
            .I2(ram_b_address[7]), .I3(GND_net), .O(n21[1]));   // matrix_scan.v(125[20:38])
    defparam i1299_2_lut_3_lut.LUT_INIT = 16'h7878;
    \timeout(COUNTER_WIDTH=6)  timeout_column_address (.clk_state(clk_state), 
            .start_latch(start_latch), .clk_matrix(clk_matrix), .pin17_ss_c_1(pin17_ss_c_1)) /* synthesis syn_module_defined=1 */ ;   // matrix_scan.v(56[4] 63[3])
    \timeout(COUNTER_WIDTH=7)  timeout_clk_pixel_load_en (.clk_matrix(clk_matrix), 
            .pin17_ss_c_1(pin17_ss_c_1), .GND_net(GND_net), .n1120(n1120), 
            .counter_6__N_86(counter_6__N_86), .clk_pixel_load_en(clk_pixel_load_en)) /* synthesis syn_module_defined=1 */ ;   // matrix_scan.v(42[4] 49[3])
    \timeout(COUNTER_WIDTH=10)  brightness_counter_9__I_0_51 (.row_latch_state({row_latch_state}), 
            .GND_net(GND_net), .n927(n927), .\brightness_counter[0] (brightness_counter[0]), 
            .clk_matrix(clk_matrix), .pin17_ss_c_1(pin17_ss_c_1), .row_latch_N_50(row_latch_N_50), 
            .\brightness_counter[6] (brightness_counter[6]), .\brightness_timeout[6] (brightness_timeout[6]), 
            .\brightness_timeout[4] (brightness_timeout[4]), .\brightness_counter[7] (brightness_counter[7]), 
            .\brightness_counter[1] (brightness_counter[1]), .\brightness_timeout[1] (brightness_timeout[1]), 
            .n37(n37), .n821(n821), .\brightness_timeout[3] (brightness_timeout[3]), 
            .\brightness_timeout[7] (brightness_timeout[7]), .output_enable(output_enable), 
            .\brightness_counter[9] (brightness_counter[9]), .\brightness_timeout[9] (brightness_timeout[9]), 
            .\brightness_counter[8] (brightness_counter[8]), .\brightness_timeout[8] (brightness_timeout[8]), 
            .\brightness_timeout[5] (brightness_timeout[5]), .\brightness_timeout[2] (brightness_timeout[2]), 
            .n4(n4)) /* synthesis syn_module_defined=1 */ ;   // matrix_scan.v(87[4] 94[3])
    VCC i1 (.Y(VCC_net));
    
endmodule
//
// Verilog Description of module \timeout(COUNTER_WIDTH=6) 
//

module \timeout(COUNTER_WIDTH=6)  (clk_state, start_latch, clk_matrix, 
            pin17_ss_c_1) /* synthesis syn_module_defined=1 */ ;
    input clk_state;
    output start_latch;
    input clk_matrix;
    input pin17_ss_c_1;
    
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    
    SB_DFFR start_latch_14 (.Q(start_latch), .C(clk_matrix), .D(clk_state), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    
endmodule
//
// Verilog Description of module \timeout(COUNTER_WIDTH=7) 
//

module \timeout(COUNTER_WIDTH=7)  (clk_matrix, pin17_ss_c_1, GND_net, 
            n1120, counter_6__N_86, clk_pixel_load_en) /* synthesis syn_module_defined=1 */ ;
    input clk_matrix;
    input pin17_ss_c_1;
    input GND_net;
    input n1120;
    input counter_6__N_86;
    output clk_pixel_load_en;
    
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    wire [6:0]counter_6__N_72;
    
    wire n951;
    wire [6:0]counter;   // timeout.v(17[35:42])
    
    wire VCC_net, n1593, n1598, n1597, n12, n1596, n1595, n1594;
    
    SB_DFFER counter_i6 (.Q(counter[6]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[6]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_LUT4 sub_29_add_2_2_lut (.I0(n1120), .I1(counter[0]), .I2(GND_net), 
            .I3(VCC_net), .O(counter_6__N_72[0])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_2_lut.LUT_INIT = 16'h8228;
    SB_DFFER counter_i5 (.Q(counter[5]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[5]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_CARRY sub_29_add_2_2 (.CI(VCC_net), .I0(counter[0]), .I1(GND_net), 
            .CO(n1593));
    SB_DFFER counter_i4 (.Q(counter[4]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[4]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFER counter_i3 (.Q(counter[3]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[3]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFER counter_i2 (.Q(counter[2]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[2]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFER counter_i1 (.Q(counter[1]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[1]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_DFFER counter_i0 (.Q(counter[0]), .C(clk_matrix), .E(n951), .D(counter_6__N_72[0]), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_LUT4 sub_29_add_2_8_lut (.I0(counter_6__N_86), .I1(counter[6]), .I2(VCC_net), 
            .I3(n1598), .O(counter_6__N_72[6])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_8_lut.LUT_INIT = 16'hebbe;
    SB_LUT4 sub_29_add_2_7_lut (.I0(n1120), .I1(counter[5]), .I2(VCC_net), 
            .I3(n1597), .O(counter_6__N_72[5])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_7_lut.LUT_INIT = 16'h8228;
    SB_CARRY sub_29_add_2_7 (.CI(n1597), .I0(counter[5]), .I1(VCC_net), 
            .CO(n1598));
    SB_LUT4 i5_4_lut (.I0(counter[6]), .I1(counter[4]), .I2(counter[5]), 
            .I3(counter[1]), .O(n12));   // timeout.v(34[13:25])
    defparam i5_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i6_4_lut (.I0(counter[3]), .I1(n12), .I2(counter[2]), .I3(counter[0]), 
            .O(clk_pixel_load_en));   // timeout.v(34[13:25])
    defparam i6_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 sub_29_add_2_6_lut (.I0(n1120), .I1(counter[4]), .I2(VCC_net), 
            .I3(n1596), .O(counter_6__N_72[4])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_6_lut.LUT_INIT = 16'h8228;
    SB_CARRY sub_29_add_2_6 (.CI(n1596), .I0(counter[4]), .I1(VCC_net), 
            .CO(n1597));
    SB_LUT4 sub_29_add_2_5_lut (.I0(n1120), .I1(counter[3]), .I2(VCC_net), 
            .I3(n1595), .O(counter_6__N_72[3])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_5_lut.LUT_INIT = 16'h8228;
    SB_CARRY sub_29_add_2_5 (.CI(n1595), .I0(counter[3]), .I1(VCC_net), 
            .CO(n1596));
    SB_LUT4 sub_29_add_2_4_lut (.I0(n1120), .I1(counter[2]), .I2(VCC_net), 
            .I3(n1594), .O(counter_6__N_72[2])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_4_lut.LUT_INIT = 16'h8228;
    SB_CARRY sub_29_add_2_4 (.CI(n1594), .I0(counter[2]), .I1(VCC_net), 
            .CO(n1595));
    SB_LUT4 sub_29_add_2_3_lut (.I0(n1120), .I1(counter[1]), .I2(VCC_net), 
            .I3(n1593), .O(counter_6__N_72[1])) /* synthesis syn_instantiated=1 */ ;
    defparam sub_29_add_2_3_lut.LUT_INIT = 16'h8228;
    SB_CARRY sub_29_add_2_3 (.CI(n1593), .I0(counter[1]), .I1(VCC_net), 
            .CO(n1594));
    SB_LUT4 i1_2_lut (.I0(clk_pixel_load_en), .I1(n1120), .I2(GND_net), 
            .I3(GND_net), .O(n951));
    defparam i1_2_lut.LUT_INIT = 16'hbbbb;
    VCC i1 (.Y(VCC_net));
    
endmodule
//
// Verilog Description of module \timeout(COUNTER_WIDTH=10) 
//

module \timeout(COUNTER_WIDTH=10)  (row_latch_state, GND_net, n927, \brightness_counter[0] , 
            clk_matrix, pin17_ss_c_1, row_latch_N_50, \brightness_counter[6] , 
            \brightness_timeout[6] , \brightness_timeout[4] , \brightness_counter[7] , 
            \brightness_counter[1] , \brightness_timeout[1] , n37, n821, 
            \brightness_timeout[3] , \brightness_timeout[7] , output_enable, 
            \brightness_counter[9] , \brightness_timeout[9] , \brightness_counter[8] , 
            \brightness_timeout[8] , \brightness_timeout[5] , \brightness_timeout[2] , 
            n4) /* synthesis syn_module_defined=1 */ ;
    input [1:0]row_latch_state;
    input GND_net;
    output n927;
    output \brightness_counter[0] ;
    input clk_matrix;
    input pin17_ss_c_1;
    input row_latch_N_50;
    output \brightness_counter[6] ;
    input \brightness_timeout[6] ;
    input \brightness_timeout[4] ;
    output \brightness_counter[7] ;
    output \brightness_counter[1] ;
    input \brightness_timeout[1] ;
    input n37;
    input n821;
    input \brightness_timeout[3] ;
    input \brightness_timeout[7] ;
    output output_enable;
    output \brightness_counter[9] ;
    input \brightness_timeout[9] ;
    output \brightness_counter[8] ;
    input \brightness_timeout[8] ;
    input \brightness_timeout[5] ;
    input \brightness_timeout[2] ;
    input n4;
    
    wire clk_matrix /* synthesis SET_AS_NETWORK=clk_matrix, is_clock=1 */ ;   // main.v(44[7:17])
    wire row_latch_N_50 /* synthesis is_clock=1, SET_AS_NETWORK=\matscan1/row_latch_N_50 */ ;   // matrix_scan.v(30[13:31])
    
    wire start_latch, counter_9__N_124;
    wire [9:0]brightness_counter;   // matrix_scan.v(30[13:31])
    
    wire n1793;
    wire [9:0]n57;
    
    wire n1585, n1583, n1586, n1587, n1584, n1580;
    wire [9:0]n45;
    
    wire n1581, n1582, VCC_net, n1588, n1732;
    
    SB_LUT4 start_I_0_2_lut_3_lut (.I0(row_latch_state[0]), .I1(row_latch_state[1]), 
            .I2(start_latch), .I3(GND_net), .O(counter_9__N_124));   // timeout.v(31[8:29])
    defparam start_I_0_2_lut_3_lut.LUT_INIT = 16'h0b0b;
    SB_LUT4 i3_4_lut (.I0(brightness_counter[2]), .I1(brightness_counter[5]), 
            .I2(brightness_counter[3]), .I3(brightness_counter[4]), .O(n927));   // timeout.v(34[13:25])
    defparam i3_4_lut.LUT_INIT = 16'hfffe;
    SB_LUT4 i1506_1_lut_2_lut_3_lut (.I0(row_latch_state[0]), .I1(row_latch_state[1]), 
            .I2(start_latch), .I3(GND_net), .O(n1793));   // timeout.v(31[8:29])
    defparam i1506_1_lut_2_lut_3_lut.LUT_INIT = 16'hf4f4;
    SB_DFFR counter_353__i0 (.Q(\brightness_counter[0] ), .C(clk_matrix), 
            .D(n57[0]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR start_latch_14 (.Q(start_latch), .C(clk_matrix), .D(row_latch_N_50), 
            .R(pin17_ss_c_1));   // timeout.v(30[8] 38[6])
    SB_LUT4 counter_353_add_4_8_lut (.I0(\brightness_timeout[6] ), .I1(n1793), 
            .I2(\brightness_counter[6] ), .I3(n1585), .O(n57[6])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_8_lut.LUT_INIT = 16'hE22E;
    SB_LUT4 counter_353_add_4_6_lut (.I0(\brightness_timeout[4] ), .I1(n1793), 
            .I2(brightness_counter[4]), .I3(n1583), .O(n57[4])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_6_lut.LUT_INIT = 16'hE22E;
    SB_CARRY counter_353_add_4_9 (.CI(n1586), .I0(n1793), .I1(\brightness_counter[7] ), 
            .CO(n1587));
    SB_CARRY counter_353_add_4_6 (.CI(n1583), .I0(n1793), .I1(brightness_counter[4]), 
            .CO(n1584));
    SB_LUT4 counter_353_add_4_3_lut (.I0(\brightness_timeout[1] ), .I1(n1793), 
            .I2(\brightness_counter[1] ), .I3(n1580), .O(n57[1])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_3_lut.LUT_INIT = 16'hE22E;
    SB_LUT4 counter_353_mux_6_i1_4_lut (.I0(n45[0]), .I1(n37), .I2(counter_9__N_124), 
            .I3(n821), .O(n57[0]));   // timeout.v(35[16:29])
    defparam counter_353_mux_6_i1_4_lut.LUT_INIT = 16'h3afa;
    SB_CARRY counter_353_add_4_3 (.CI(n1580), .I0(n1793), .I1(\brightness_counter[1] ), 
            .CO(n1581));
    SB_LUT4 counter_353_add_4_5_lut (.I0(\brightness_timeout[3] ), .I1(n1793), 
            .I2(brightness_counter[3]), .I3(n1582), .O(n57[3])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_5_lut.LUT_INIT = 16'hE22E;
    SB_CARRY counter_353_add_4_5 (.CI(n1582), .I0(n1793), .I1(brightness_counter[3]), 
            .CO(n1583));
    SB_LUT4 counter_353_add_4_9_lut (.I0(\brightness_timeout[7] ), .I1(n1793), 
            .I2(\brightness_counter[7] ), .I3(n1586), .O(n57[7])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_9_lut.LUT_INIT = 16'hE22E;
    SB_LUT4 counter_353_add_4_2_lut (.I0(GND_net), .I1(output_enable), .I2(\brightness_counter[0] ), 
            .I3(VCC_net), .O(n45[0])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_2_lut.LUT_INIT = 16'hC33C;
    SB_LUT4 counter_353_add_4_11_lut (.I0(\brightness_timeout[9] ), .I1(n1793), 
            .I2(\brightness_counter[9] ), .I3(n1588), .O(n57[9])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_11_lut.LUT_INIT = 16'hE22E;
    SB_CARRY counter_353_add_4_7 (.CI(n1584), .I0(n1793), .I1(brightness_counter[5]), 
            .CO(n1585));
    SB_CARRY counter_353_add_4_8 (.CI(n1585), .I0(n1793), .I1(\brightness_counter[6] ), 
            .CO(n1586));
    SB_LUT4 counter_353_add_4_10_lut (.I0(\brightness_timeout[8] ), .I1(n1793), 
            .I2(\brightness_counter[8] ), .I3(n1587), .O(n57[8])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_10_lut.LUT_INIT = 16'hE22E;
    SB_DFFR counter_353__i9 (.Q(\brightness_counter[9] ), .C(clk_matrix), 
            .D(n57[9]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_CARRY counter_353_add_4_10 (.CI(n1587), .I0(n1793), .I1(\brightness_counter[8] ), 
            .CO(n1588));
    SB_DFFR counter_353__i8 (.Q(\brightness_counter[8] ), .C(clk_matrix), 
            .D(n57[8]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_LUT4 i2_3_lut (.I0(\brightness_counter[1] ), .I1(n927), .I2(\brightness_counter[0] ), 
            .I3(GND_net), .O(n1732));   // timeout.v(34[13:25])
    defparam i2_3_lut.LUT_INIT = 16'hfefe;
    SB_LUT4 counter_353_add_4_7_lut (.I0(\brightness_timeout[5] ), .I1(n1793), 
            .I2(brightness_counter[5]), .I3(n1584), .O(n57[5])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_7_lut.LUT_INIT = 16'hE22E;
    SB_CARRY counter_353_add_4_2 (.CI(VCC_net), .I0(output_enable), .I1(\brightness_counter[0] ), 
            .CO(n1580));
    SB_DFFR counter_353__i7 (.Q(\brightness_counter[7] ), .C(clk_matrix), 
            .D(n57[7]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i6 (.Q(\brightness_counter[6] ), .C(clk_matrix), 
            .D(n57[6]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i5 (.Q(brightness_counter[5]), .C(clk_matrix), 
            .D(n57[5]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i4 (.Q(brightness_counter[4]), .C(clk_matrix), 
            .D(n57[4]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i3 (.Q(brightness_counter[3]), .C(clk_matrix), 
            .D(n57[3]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i2 (.Q(brightness_counter[2]), .C(clk_matrix), 
            .D(n57[2]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_DFFR counter_353__i1 (.Q(\brightness_counter[1] ), .C(clk_matrix), 
            .D(n57[1]), .R(pin17_ss_c_1));   // timeout.v(35[16:29])
    SB_LUT4 counter_353_add_4_4_lut (.I0(\brightness_timeout[2] ), .I1(n1793), 
            .I2(brightness_counter[2]), .I3(n1581), .O(n57[2])) /* synthesis syn_instantiated=1 */ ;
    defparam counter_353_add_4_4_lut.LUT_INIT = 16'hE22E;
    SB_CARRY counter_353_add_4_4 (.CI(n1581), .I0(n1793), .I1(brightness_counter[2]), 
            .CO(n1582));
    SB_LUT4 i1485_4_lut (.I0(n1732), .I1(\brightness_counter[6] ), .I2(\brightness_counter[8] ), 
            .I3(n4), .O(output_enable));   // timeout.v(35[16:29])
    defparam i1485_4_lut.LUT_INIT = 16'h0001;
    VCC i1 (.Y(VCC_net));
    
endmodule
