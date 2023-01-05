

    VHI scuba_vhi_inst (.Z(scuba_vhi));
https://github.com/attie/led_matrix_tinyfpga_a2/blob/master/framebuffer.v

	/* the framebuffer */
	framebuffer fb (
		/* control module interface */
		.DataInA(ram_a_data_in),
		.AddressA(ram_a_address),
		.ClockA(clk_root),
		.ClockEnA(ram_a_clk_enable),
		.WrA(ram_a_write_enable),
		.ResetA(global_reset),
		.QA(ram_a_data_out),

		/* display interface */
		.DataInB(16'b0),
		.AddressB(ram_b_address),
		.ClockB(clk_root),
		.ClockEnB(ram_b_clk_enable),
		.WrB(1'b0),
		.ResetB(ram_b_reset),
		.QB(ram_b_data_out)
	);

module framebuffer (DataInA, DataInB, AddressA, AddressB, ClockA, ClockB,
    ClockEnA, ClockEnB, WrA, WrB, ResetA, ResetB, QA, QB)/* synthesis NGD_DRC_MASK=1 */;
    input wire [7:0] DataInA;
    input wire [15:0] DataInB;
    input wire [11:0] AddressA;
    input wire [10:0] AddressB;
    input wire ClockA;
    input wire ClockB;
    input wire ClockEnA;
    input wire ClockEnB;
    input wire WrA;
    input wire WrB;
    input wire ResetA;
    input wire ResetB;
    output wire [7:0] QA;
    output wire [15:0] QB;

    wire scuba_vhi;
    wire scuba_vlo;

# Simplified repeating thing
## in
### A
- AddressA (as `ram_a_address`) comes from control_module via `control_module.ram_address`
- DataInA (as `ram_a_data_in`) comes from control_module via `control_module.ram_data_out`
- ClockA - clk_root
- ClockEnA (as `ram_a_clk_enable`) comes from control_module via `control_module.ram_clk_enable`
- WrA (as `ram_a_write_enable`) comes from control_module via `control_module.ram_write_enable`
- ResetA comes from global_reset
### B
- AddressB (as `ram_b_address`) comes from frambuffer_fetch via `frambuffer_fetch.ram_address`
- DataInB comes from static 16'b0
- ClockB - clk_root
- ClockEnB (as `ram_b_clk_enable`) comes from framebuffer_fetch via `framebuffer_fetch.ram_clk_enable`
- WrB comes from static 1'b0
- Resetb (as `ram_b_reset`) comes from framebuffer_fetch via `framebuffer_fetch.ram_reset`
## out
- QA (from here) (as ram_a_data_out) goes to control_module via control_module.ram_data_in
- QB (from here) (as ram_b_data_out) goes to framebuffer_fetch via framebuffer_fetch.ram_data_in
Shared
	CEA: ClockEnA
	OCEA: ClockEnA
	CLKA: ClockA
	WEA: WrA
	CSA: {LO, LO, LO}
	RSTA: ResetA
    CEB: ClockEnB
	OCEB: ClockEnB
	CLKB: ClockB
	WEB: WrB
	CSB: {LO, LO, LO}
	RSTB: ResetB
	Alias: AddressA -> AA
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits
    defparam framebuffer_x.DATA_WIDTH_B = 4 ;
    defparam framebuffer_x.DATA_WIDTH_A = 2 ;
DP8KC framebuffer_0_0_3
	DIA: {LO, LO, LO, DataInA[1], LO, LO, DataInA[0], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[9], DataInB[8], DataInB[1], DataInB[0]} # 9 bits
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[1], QA[0]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, QB[9], QB[8], QB[1], QB[0]}  # 9 bits
DP8KC framebuffer_0_1_2
	DIA: {LO, LO, LO, DataInA[3], LO, LO, DataInA[2], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[11], DataInB[10], DataInB[3], DataInB[2]} # 9 bits
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[3], QA[2]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[11], QB[10], QB[3], QB[2]}  # 9 bits
DP8KC framebuffer_0_2_1
	DIA: {LO, LO, LO, DataInA[5], LO, LO, DataInA[4], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[13], DataInB[12], DataInB[5], DataInB[4]} # 9 bits
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[5], QA[4]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[13], QB[12], QB[5], QB[4]}  # 9 bits
DP8KC framebuffer_0_3_0
	DIA: {LO, LO, LO, DataInA[7], LO, LO, DataInA[6], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[15], DataInB[14], DataInB[7], DataInB[6]} # 9 bits
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[7], QA[6]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[15], QB[14], QB[7], QB[6]}  # 9 bits


# Extracted Attributes
DP8KC framebuffer_0_0_3
	DIA: {LO, LO, LO, DataInA[1], LO, LO, DataInA[0], LO, LO} # 9 bits
	Alias: AddressA -> AA
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	CEA: ClockEnA
	OCEA: ClockEnA
	CLKA: ClockA
	WEA: WrA
	CSA: {LO, LO, LO}
	RSTA: ResetA
	DIB: {LO, LO, LO, LO, LO, DataInB[9], DataInB[8], DataInB[1], DataInB[0]} # 9 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits
	CEB: ClockEnB
	OCEB: ClockEnB
	CLKB: ClockB
	WEB: WrB
	CSB: {LO, LO, LO}
	RSTB: ResetB
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[1], QA[0]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, QB[9], QB[8], QB[1], QB[0]}  # 9 bits
DP8KC framebuffer_0_1_2
	DIA: {LO, LO, LO, DataInA[3], LO, LO, DataInA[2], LO, LO} # 9 bits
	Alias: AddressA -> AA
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	CEA: ClockEnA
	OCEA: ClockEnA
	CLKA: ClockA
	WEA: WrA
	CSA: {LO, LO, LO}
	RSTA: ResetA
	DIB: {LO, LO, LO, LO, LO, DataInB[11], DataInB[10], DataInB[3], DataInB[2]} # 9 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits
	CEB: ClockEnB
	OCEB: ClockEnB
	CLKB: ClockB
	WEB: WrB
	CSB: {LO, LO, LO}
	RSTB: ResetB
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[3], QA[2]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[11], QB[10], QB[3], QB[2]}  # 9 bits
DP8KC framebuffer_0_2_1
	DIA: {LO, LO, LO, DataInA[5], LO, LO, DataInA[4], LO, LO} # 9 bits
	Alias: AddressA -> AA
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	CEA: ClockEnA
	OCEA: ClockEnA
	CLKA: ClockA
	WEA: WrA
	CSA: {LO, LO, LO}
	RSTA: ResetA
	DIB: {LO, LO, LO, LO, LO, DataInB[13], DataInB[12], DataInB[5], DataInB[4]} # 9 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits
	CEB: ClockEnB
	OCEB: ClockEnB
	CLKB: ClockB
	WEB: WrB
	CSB: {LO, LO, LO}
	RSTB: ResetB
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[5], QA[4]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[13], QB[12], QB[5], QB[4]}  # 9 bits
DP8KC framebuffer_0_3_0
	DIA: {LO, LO, LO, DataInA[7], LO, LO, DataInA[6], LO, LO} # 9 bits
	Alias: AddressA -> AA
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	CEA: ClockEnA
	OCEA: ClockEnA
	CLKA: ClockA
	WEA: WrA
	CSA: {LO, LO, LO}
	RSTA: ResetA
	DIB: {LO, LO, LO, LO, LO, DataInB[15], DataInB[14], DataInB[7], DataInB[6]} # 9 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits
	CEB: ClockEnB
	OCEB: ClockEnB
	CLKB: ClockB
	WEB: WrB
	CSB: {LO, LO, LO}
	RSTB: ResetB
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[7], QA[6]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[15], QB[14], QB[7], QB[6]}  # 9 bits


# Raw declarations
```
    DP8KC framebuffer_0_0_3 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo),
        .DIA5(DataInA[1]), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(DataInA[0]),
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(AddressA[11]), .ADA11(AddressA[10]),
        .ADA10(AddressA[9]), .ADA9(AddressA[8]), .ADA8(AddressA[7]), .ADA7(AddressA[6]),
        .ADA6(AddressA[5]), .ADA5(AddressA[4]), .ADA4(AddressA[3]), .ADA3(AddressA[2]),
        .ADA2(AddressA[1]), .ADA1(AddressA[0]), .ADA0(scuba_vlo), .CEA(ClockEnA),
        .OCEA(ClockEnA), .CLKA(ClockA), .WEA(WrA), .CSA2(scuba_vlo), .CSA1(scuba_vlo),
        .CSA0(scuba_vlo), .RSTA(ResetA), .DIB8(scuba_vlo), .DIB7(scuba_vlo),
        .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), .DIB3(DataInB[9]),
        .DIB2(DataInB[8]), .DIB1(DataInB[1]), .DIB0(DataInB[0]), .ADB12(AddressB[10]),
        .ADB11(AddressB[9]), .ADB10(AddressB[8]), .ADB9(AddressB[7]), .ADB8(AddressB[6]),
        .ADB7(AddressB[5]), .ADB6(AddressB[4]), .ADB5(AddressB[3]), .ADB4(AddressB[2]),
        .ADB3(AddressB[1]), .ADB2(AddressB[0]), .ADB1(scuba_vlo), .ADB0(scuba_vlo),
        .CEB(ClockEnB), .OCEB(ClockEnB), .CLKB(ClockB), .WEB(WrB), .CSB2(scuba_vlo),
        .CSB1(scuba_vlo), .CSB0(scuba_vlo), .RSTB(ResetB), .DOA8(), .DOA7(),
        .DOA6(), .DOA5(), .DOA4(), .DOA3(), .DOA2(), .DOA1(QA[1]), .DOA0(QA[0]),
        .DOB8(), .DOB7(), .DOB6(), .DOB5(), .DOB4(), .DOB3(QB[9]), .DOB2(QB[8]),
        .DOB1(QB[1]), .DOB0(QB[0]))
   DP8KC framebuffer_0_1_2 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo),
        .DIA5(DataInA[3]), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(DataInA[2]),
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(AddressA[11]), .ADA11(AddressA[10]),
        .ADA10(AddressA[9]), .ADA9(AddressA[8]), .ADA8(AddressA[7]), .ADA7(AddressA[6]),
        .ADA6(AddressA[5]), .ADA5(AddressA[4]), .ADA4(AddressA[3]), .ADA3(AddressA[2]),
        .ADA2(AddressA[1]), .ADA1(AddressA[0]), .ADA0(scuba_vlo), .CEA(ClockEnA),
        .OCEA(ClockEnA), .CLKA(ClockA), .WEA(WrA), .CSA2(scuba_vlo), .CSA1(scuba_vlo),
        .CSA0(scuba_vlo), .RSTA(ResetA), .DIB8(scuba_vlo), .DIB7(scuba_vlo),
        .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), .DIB3(DataInB[11]),
        .DIB2(DataInB[10]), .DIB1(DataInB[3]), .DIB0(DataInB[2]), .ADB12(AddressB[10]),
        .ADB11(AddressB[9]), .ADB10(AddressB[8]), .ADB9(AddressB[7]), .ADB8(AddressB[6]),
        .ADB7(AddressB[5]), .ADB6(AddressB[4]), .ADB5(AddressB[3]), .ADB4(AddressB[2]),
        .ADB3(AddressB[1]), .ADB2(AddressB[0]), .ADB1(scuba_vlo), .ADB0(scuba_vlo),
        .CEB(ClockEnB), .OCEB(ClockEnB), .CLKB(ClockB), .WEB(WrB), .CSB2(scuba_vlo),
        .CSB1(scuba_vlo), .CSB0(scuba_vlo), .RSTB(ResetB), .DOA8(), .DOA7(),
        .DOA6(), .DOA5(), .DOA4(), .DOA3(), .DOA2(), .DOA1(QA[3]), .DOA0(QA[2]),
        .DOB8(), .DOB7(), .DOB6(), .DOB5(), .DOB4(), .DOB3(QB[11]), .DOB2(QB[10]),
        .DOB1(QB[3]), .DOB0(QB[2]))
    DP8KC framebuffer_0_2_1 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo),
        .DIA5(DataInA[5]), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(DataInA[4]),
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(AddressA[11]), .ADA11(AddressA[10]),
        .ADA10(AddressA[9]), .ADA9(AddressA[8]), .ADA8(AddressA[7]), .ADA7(AddressA[6]),
        .ADA6(AddressA[5]), .ADA5(AddressA[4]), .ADA4(AddressA[3]), .ADA3(AddressA[2]),
        .ADA2(AddressA[1]), .ADA1(AddressA[0]), .ADA0(scuba_vlo), .CEA(ClockEnA),
        .OCEA(ClockEnA), .CLKA(ClockA), .WEA(WrA), .CSA2(scuba_vlo), .CSA1(scuba_vlo),
        .CSA0(scuba_vlo), .RSTA(ResetA), .DIB8(scuba_vlo), .DIB7(scuba_vlo),
        .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), .DIB3(DataInB[13]),
        .DIB2(DataInB[12]), .DIB1(DataInB[5]), .DIB0(DataInB[4]), .ADB12(AddressB[10]),
        .ADB11(AddressB[9]), .ADB10(AddressB[8]), .ADB9(AddressB[7]), .ADB8(AddressB[6]),
        .ADB7(AddressB[5]), .ADB6(AddressB[4]), .ADB5(AddressB[3]), .ADB4(AddressB[2]),
        .ADB3(AddressB[1]), .ADB2(AddressB[0]), .ADB1(scuba_vlo), .ADB0(scuba_vlo),
        .CEB(ClockEnB), .OCEB(ClockEnB), .CLKB(ClockB), .WEB(WrB), .CSB2(scuba_vlo),
        .CSB1(scuba_vlo), .CSB0(scuba_vlo), .RSTB(ResetB), .DOA8(), .DOA7(),
        .DOA6(), .DOA5(), .DOA4(), .DOA3(), .DOA2(), .DOA1(QA[5]), .DOA0(QA[4]),
        .DOB8(), .DOB7(), .DOB6(), .DOB5(), .DOB4(), .DOB3(QB[13]), .DOB2(QB[12]),
        .DOB1(QB[5]), .DOB0(QB[4]))
    DP8KC framebuffer_0_3_0 (.DIA8(scuba_vlo), .DIA7(scuba_vlo), .DIA6(scuba_vlo),
        .DIA5(DataInA[7]), .DIA4(scuba_vlo), .DIA3(scuba_vlo), .DIA2(DataInA[6]),
        .DIA1(scuba_vlo), .DIA0(scuba_vlo), .ADA12(AddressA[11]), .ADA11(AddressA[10]),
        .ADA10(AddressA[9]), .ADA9(AddressA[8]), .ADA8(AddressA[7]), .ADA7(AddressA[6]),
        .ADA6(AddressA[5]), .ADA5(AddressA[4]), .ADA4(AddressA[3]), .ADA3(AddressA[2]),
        .ADA2(AddressA[1]), .ADA1(AddressA[0]), .ADA0(scuba_vlo), .CEA(ClockEnA),
        .OCEA(ClockEnA), .CLKA(ClockA), .WEA(WrA), .CSA2(scuba_vlo), .CSA1(scuba_vlo),
        .CSA0(scuba_vlo), .RSTA(ResetA), .DIB8(scuba_vlo), .DIB7(scuba_vlo),
        .DIB6(scuba_vlo), .DIB5(scuba_vlo), .DIB4(scuba_vlo), .DIB3(DataInB[15]),
        .DIB2(DataInB[14]), .DIB1(DataInB[7]), .DIB0(DataInB[6]), .ADB12(AddressB[10]),
        .ADB11(AddressB[9]), .ADB10(AddressB[8]), .ADB9(AddressB[7]), .ADB8(AddressB[6]),
        .ADB7(AddressB[5]), .ADB6(AddressB[4]), .ADB5(AddressB[3]), .ADB4(AddressB[2]),
        .ADB3(AddressB[1]), .ADB2(AddressB[0]), .ADB1(scuba_vlo), .ADB0(scuba_vlo),
        .CEB(ClockEnB), .OCEB(ClockEnB), .CLKB(ClockB), .WEB(WrB), .CSB2(scuba_vlo),
        .CSB1(scuba_vlo), .CSB0(scuba_vlo), .RSTB(ResetB), .DOA8(), .DOA7(),
        .DOA6(), .DOA5(), .DOA4(), .DOA3(), .DOA2(), .DOA1(QA[7]), .DOA0(QA[6]),
        .DOB8(), .DOB7(), .DOB6(), .DOB5(), .DOB4(), .DOB3(QB[15]), .DOB2(QB[14]),
        .DOB1(QB[7]), .DOB0(QB[6]))
```