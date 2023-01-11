`timescale 1 ns / 1 ps
module multimem (DataInA, DataInB, AddressA, AddressB, ClockA, ClockB,
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

	wire [12:0] translatedAddressA = { AddressA[11:0], 1'b0 };
	wire [12:0] translatedAddressB = { AddressB[10:0], 1'b0, 1'b0 };

//  parameter DATAWIDTH = 9;
//  parameter ADDRWIDTH = 13;
/*
	ADA: {AA[11], AA[10], AA[9], AA[8], AA[7], AA[6], AA[5], AA[4], AA[3], AA[2], AA[1], AA[0], LO} # 13 bits
	Alias: AddressB -> AB
	ADB: {AB[10], AB[9], AB[8], AB[7], AB[6], AB[5], AB[4], AB[3], AB[2], AB[1], AB[0], LO, LO} # 13 bits

DP8KC framebuffer_0_0_3
	DIA: {LO, LO, LO, DataInA[1], LO, LO, DataInA[0], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[9], DataInB[8], DataInB[1], DataInB[0]} # 9 bits <-- these don't matter, we always write 0
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[1], QA[0]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, QB[9], QB[8], QB[1], QB[0]}  # 9 bits
DP8KC framebuffer_0_1_2
	DIA: {LO, LO, LO, DataInA[3], LO, LO, DataInA[2], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[11], DataInB[10], DataInB[3], DataInB[2]} # 9 bits <-- these don't matter, we always write 0
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[3], QA[2]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[11], QB[10], QB[3], QB[2]}  # 9 bits
DP8KC framebuffer_0_2_1
	DIA: {LO, LO, LO, DataInA[5], LO, LO, DataInA[4], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[13], DataInB[12], DataInB[5], DataInB[4]} # 9 bits <-- these don't matter, we always write 0
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[5], QA[4]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[13], QB[12], QB[5], QB[4]}  # 9 bits
DP8KC framebuffer_0_3_0
	DIA: {LO, LO, LO, DataInA[7], LO, LO, DataInA[6], LO, LO} # 9 bits
	DIB: {LO, LO, LO, LO, LO, DataInB[15], DataInB[14], DataInB[7], DataInB[6]} # 9 bits <-- these don't matter, we always write 0
	DOA: {Null, Null, Null, Null, Null, Null, Null, QA[7], QA[6]} # 9 bits
	DOB: {Null, Null, Null, Null, Null, Q[15], QB[14], QB[7], QB[6]}  # 9 bits
*/
/*
		#0
		DIA:	{ 1'b0, 1'b0, 1'b0,  DataInA[1], 1'b0, 1'b0, DataInA[0], 1'b0, 1'b0 }
		//DIB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, DataInB[9], DataInB[8], DataInB[1], DataInB[0] }
		DOA:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QA[1], QA[0] }
		DOB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QB[8], QB[8], QB[1], QB[0] }

		#1
		DIA:	{ 1'b0, 1'b0, 1'b0,  DataInA[3], 1'b0, 1'b0, DataInA[2], 1'b0, 1'b0 }
		//DIB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, DataInB[11], DataInB[10], DataInB[3], DataInB[2] }
		DOA:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QA[3], QA[2] }
		DOB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QB[11], QB[10], QB[3], QB[2] }
		#2
		DIA:	{ 1'b0, 1'b0, 1'b0,  DataInA[5], 1'b0, 1'b0, DataInA[4], 1'b0, 1'b0 }
		//DIB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, DataInB[13], DataInB[12], DataInB[5], DataInB[4] }
		DOA:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QA[5], QA[4] }
		DOB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QB[13], QB[12], QB[5], QB[4] }
		#3
		DIA:	{ 1'b0, 1'b0, 1'b0,  DataInA[7], 1'b0, 1'b0, DataInA[6], 1'b0, 1'b0 }
		//DIB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, DataInB[15], DataInB[14], DataInB[7], DataInB[6] }
		DOA:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QA[7], QA[6] }
		DOB:	{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, QB[15], QB[14], QB[7], QB[6] }
*/
	wire [8:0] num0_porta_out;
	wire [8:0] num0_portb_out;
	wire [8:0] num1_porta_out;
	wire [8:0] num1_portb_out;
	wire [8:0] num2_porta_out;
	wire [8:0] num2_portb_out;
	wire [8:0] num3_porta_out;
	wire [8:0] num3_portb_out;

	newram3 num0 (
		.PortAClk(ClockA),
		.PortBClk(ClockB),
		.PortAAddr(translatedAddressA),
		.PortADataIn({ 1'b0, 1'b0, 1'b0, DataInA[1], 1'b0, 1'b0, DataInA[0], 1'b0, 1'b0 }),
		.PortAWriteEnable(WrA),
		.PortAReset(ResetA),
		.PortBAddr(translatedAddressB),
		.PortBReset(ResetB),
		.PortADataOut(num0_porta_out),
		.PortBDataOut(num0_portb_out)
	);
	newram3 num1 (
		.PortAClk(ClockA),
		.PortBClk(ClockB),
		.PortAAddr(translatedAddressA),
		.PortADataIn({ 1'b0, 1'b0, 1'b0, DataInA[3], 1'b0, 1'b0, DataInA[2], 1'b0, 1'b0 }),
		.PortAWriteEnable(WrA),
		.PortAReset(ResetA),
		.PortBAddr(translatedAddressB),
		.PortBReset(ResetB),
		.PortADataOut(num1_porta_out),
		.PortBDataOut(num1_portb_out)
	);

	newram3 num2 (
		.PortAClk(ClockA),
		.PortBClk(ClockB),
		.PortAAddr(translatedAddressA),
		.PortADataIn({ 1'b0, 1'b0, 1'b0, DataInA[5], 1'b0, 1'b0, DataInA[4], 1'b0, 1'b0 }),
		.PortAWriteEnable(WrA),
		.PortAReset(ResetA),
		.PortBAddr(translatedAddressB),
		.PortBReset(ResetB),
		.PortADataOut(num2_porta_out),
		.PortBDataOut(num2_portb_out)
	);

	newram3 num3 (
		.PortAClk(ClockA),
		.PortBClk(ClockB),
		.PortAAddr(translatedAddressA),
		.PortADataIn({ 1'b0, 1'b0, 1'b0, DataInA[7], 1'b0, 1'b0, DataInA[6], 1'b0, 1'b0 }),
		.PortAWriteEnable(WrA),
		.PortAReset(ResetA),
		.PortBAddr(translatedAddressB),
		.PortBReset(ResetB),
		.PortADataOut(num3_porta_out),
		.PortBDataOut(num3_portb_out)
	);

	assign QA = {num3_porta_out[1:0], num2_porta_out[1:0], num1_porta_out[1:0], num0_porta_out[1:0]};
	assign QB = {num3_portb_out[3:0], num2_portb_out[3:0], num1_portb_out[3:0], num0_portb_out[3:0]};


endmodule