// -----------------------------------------------------------------------------
// ---
// ---                 (C) COPYRIGHT 2001-2010 SYNOPSYS, INC.
// ---                           ALL RIGHTS RESERVED
// ---
// --- This software and the associated documentation are confidential and
// --- proprietary to Synopsys, Inc.  Your use or disclosure of this
// --- software is subject to the terms and conditions of a written
// --- license agreement between you, or your company, and Synopsys, Inc.
// ---
// --- The entire notice above must be reproduced on all authorized copies.
// ---
// -----------------------------------------------------------------------------
//



 // Output ports are always registered to ensure Rams get packed into BlockRAM

//`include "Multiported-RAM/utils.vh"
//`include "Multiported-RAM/mpram.v"


`timescale 1ns/100ps
 //`ifdef synthesis
     module newram2
 //`else
 //    module newram_rtl
 //`endif
(
	 PortAClk
	,PortAAddr
	,PortADataIn
	,PortAWriteEnable
	,PortAReset
	,PortBClk
	,PortBDataIn
	,PortBAddr
	,PortBWriteEnable
	,PortBReset
	,PortADataOut
	,PortBDataOut
	,PortAClkEnable
	,PortBClkEnable
	);

  parameter	 DATAWIDTH = 16;
  parameter	 DATA_A_WIDTH = 8;
  parameter	 DATA_B_WIDTH = 16;
  parameter	 ADDRWIDTH = 12; 
  parameter	 MEMDEPTH = 2**(ADDRWIDTH);

  input PortAClk;
  input [ADDRWIDTH-1:0] PortAAddr;
  input [DATA_A_WIDTH-1:0] PortADataIn;
  input PortAWriteEnable;
  input PortAReset;
  input	PortAClkEnable;

  input PortBClk;
  input  [ADDRWIDTH-2:0] PortBAddr;
  input  [DATA_B_WIDTH-1:0] PortBDataIn;
  input PortBWriteEnable;
  input PortBReset;
  input	PortBClkEnable;

  output [DATA_A_WIDTH-1:0] PortADataOut;
  output [DATA_B_WIDTH-1:0] PortBDataOut;
  /*
	mparam #(
		.MEMD(2048),
  		.DATAW(8),
  		.nRPORTS(2),
  		.nWPORTS(1),
  		.TYPE("XOR"),
  		.BYP("RDW"),
  		.IFILE(""))
	mparam_inst ( .clk(clk),
					.WEnb());
					*/
  /*
  wire 	PortAClk;
  wire  [ADDRWIDTH-1:0] 	PortAAddr;
  wire  [DATA_A_WIDTH-1:0] 	PortADataIn;
  wire  [DATA_A_WIDTH-1:0] 	PortADataOut;
  wire 	PortAWriteEnable;
  wire 	PortAReadEnable;
  wire 	PortAReset;
  wire	PortAClkEnable;
  wire 	PortBClk;
  wire  [ADDRWIDTH-2:0] 	PortBAddr;
  wire  [DATA_B_WIDTH-1:0] 	PortBDataIn;
  wire  [DATA_B_WIDTH-1:0] 	PortBDataOut;
  wire 	PortBWriteEnable;
  wire 	PortBReadEnable;
  wire 	PortBReset;
  wire	PortBClkEnable;
  */
  wire [ADDRWIDTH-1:0] addr_a;
  wire [ADDRWIDTH-1:0] addr_b_p1;
  wire [ADDRWIDTH-1:0] addr_b_p2;
  wire [DATAWIDTH-1:0] data_a_in;
  wire [DATAWIDTH-1:0] data_b_in;
  wire [DATAWIDTH-1:0] data_a_out_p1;
  wire [DATAWIDTH-1:0] data_a_out_p2;
  wire [DATAWIDTH-1:0] data_b_out_p1;
  wire [DATAWIDTH-1:0] data_b_out_p2;
  wire  clk_a;
  wire  clk_b;

  assign addr_a = {PortAAddr[11:0]} ;
  assign addr_b_p1 = { PortBAddr[10:0], 1'b0};
  assign addr_b_p2 = { PortBAddr[10:0], 1'b1};
  assign data_a_in = { 8'b0, PortADataIn[DATA_A_WIDTH-1:0]};
  // irrellevant, since we don't write to port b
  assign data_b_in = { PortBDataIn[DATA_B_WIDTH-1:0] };
  assign clk_a = PortAClk & (PortAClkEnable | PortBClkEnable);
  //assign clk_b = PortBClk & PortBClkEnable;

  mpram #(
	  .MEMD(4096),
	  .DATAW(16),
	  .nRPORTS(2),
	  .nWPORTS(1),
	  .TYPE("XOR"),
	  .BYP("RDW"))
  mpram_ins_p1 ( .clk(clk_a),
				.WEnb(PortAWriteEnable & PortAClkEnable),
				.WAddr(addr_a),
				.WData(data_a_in),
				.RAddr({addr_a, addr_b_p1}),
				.RData({data_a_out_p1, data_b_out_p1})
) ;
  mpram #(
	  .MEMD(4096),
	  .DATAW(16),
	  .nRPORTS(2),
	  .nWPORTS(1),
	  .TYPE("XOR"),
	  .BYP("RDW"))
  mpram_ins_p2 ( .clk(clk_a),
	  .WEnb(PortAWriteEnable & PortAClkEnable),
	  .WAddr(addr_a),
	  .WData(data_a_in),
	  .RAddr({addr_a, addr_b_p2}),
	  .RData({data_a_out_p2,data_b_out_p2})
  ) ;
  assign PortADataOut = { data_a_out_p1[7:0] };
  assign PortBDataOut = { data_b_out_p1[7:0], data_b_out_p2[7:0] };
  /*
  .PortClk({clk_b, clk_a})
  ,.PortReset({PortBReset, PortAReset})
  ,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
  ,.PortReadEnable({PortBReadEnable, PortAReadEnable})
  ,.PortDataIn({data_b_in, data_a_in})
  ,.PortAddr({addr_b_p2, addr_a})
  ,.PortDataOut({data_b_out_p2, data_a_out_p2})
input                                 clk  ,  // clock
input       [nWPORTS-1:0            ] WEnb ,  // write enable for each writing port
input       [`log2(MEMD)*nWPORTS-1:0] WAddr,  // write addresses - packed from nWPORTS write ports
input       [DATAW      *nWPORTS-1:0] WData,  // write data - packed from nWPORTS read ports
input       [`log2(MEMD)*nRPORTS-1:0] RAddr,  // read  addresses - packed from nRPORTS  read  ports
output wire [DATAW      *nRPORTS-1:0] RData); // read  data - packed from nRPORTS read ports
*/
  /*
  Syncore_ram
 #(	
				.SPRAM(0)
				,.READ_MODE_A(2)
				,.READ_MODE_B(2)
				,.READ_WRITE_A(1)
				//				,.READ_WRITE_B(1)
				,.READ_WRITE_B(2)
				,.DATAWIDTH(DATAWIDTH)
				,.ADDRWIDTH(ADDRWIDTH+1)
				,.ENABLE_WR_PORTA(1)
				,.REGISTER_RD_ADDR_PORTA(1)
				,.REGISTER_OUTPUT_PORTA(1)
				,.ENABLE_OUTPUT_REG_PORTA(0)
				,.RESET_OUTPUT_REG_PORTA(1)
				//				,.ENABLE_WR_PORTB(1)
				,.ENABLE_WR_PORTB(0)
				,.REGISTER_RD_ADDR_PORTB(1)
				,.REGISTER_OUTPUT_PORTB(1)
				,.ENABLE_OUTPUT_REG_PORTB(0)
				,.RESET_OUTPUT_REG_PORTB(1)	
				) 
			U1(
				.PortClk({clk_b, clk_a})
				,.PortReset({PortBReset, PortAReset})
				,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
				,.PortReadEnable({PortBReadEnable, PortAReadEnable})
				,.PortDataIn({data_b_in, data_a_in})
				,.PortAddr({addr_b_p1, addr_a})
				,.PortDataOut({data_b_out_p1, data_a_out_p1})
				);
  Syncore_ram
  #(
	  .SPRAM(0)
	  ,.READ_MODE_A(2)
	  ,.READ_MODE_B(2)
	  ,.READ_WRITE_A(1)
	  //				,.READ_WRITE_B(1)
	  ,.READ_WRITE_B(2)
	  ,.DATAWIDTH(DATAWIDTH)
	  ,.ADDRWIDTH(ADDRWIDTH+1)
	  ,.ENABLE_WR_PORTA(1)
	  ,.REGISTER_RD_ADDR_PORTA(1)
	  ,.REGISTER_OUTPUT_PORTA(1)
	  ,.ENABLE_OUTPUT_REG_PORTA(0)
	  ,.RESET_OUTPUT_REG_PORTA(1)
	  //				,.ENABLE_WR_PORTB(1)
	  ,.ENABLE_WR_PORTB(0)
	  ,.REGISTER_RD_ADDR_PORTB(1)
	  ,.REGISTER_OUTPUT_PORTB(1)
	  ,.ENABLE_OUTPUT_REG_PORTB(0)
	  ,.RESET_OUTPUT_REG_PORTB(1)
  )
  U2(
	  .PortClk({clk_b, clk_a})
	  ,.PortReset({PortBReset, PortAReset})
	  ,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
	  ,.PortReadEnable({PortBReadEnable, PortAReadEnable})
	  ,.PortDataIn({data_b_in, data_a_in})
	  ,.PortAddr({addr_b_p2, addr_a})
	  ,.PortDataOut({data_b_out_p2, data_a_out_p2})
  );
*/


/*
 Syncore_ram
 #(
				.SPRAM(SPRAM)
				,.READ_MODE_A(READ_MODE_A)
				,.READ_MODE_B(READ_MODE_B)
				,.READ_WRITE_A(READ_WRITE_A)
				,.READ_WRITE_B(READ_WRITE_B)
				,.DATAWIDTH(DATAWIDTH)
				,.ADDRWIDTH(ADDRWIDTH)
				,.ENABLE_WR_PORTA(ENABLE_WR_PORTA)
				,.REGISTER_RD_ADDR_PORTA(REGISTER_RD_ADDR_PORTA)
				,.REGISTER_OUTPUT_PORTA(REGISTER_OUTPUT_PORTA)
				,.ENABLE_OUTPUT_REG_PORTA(ENABLE_OUTPUT_REG_PORTA)
				,.RESET_OUTPUT_REG_PORTA(RESET_OUTPUT_REG_PORTA)
				,.ENABLE_WR_PORTB(ENABLE_WR_PORTB)
				,.REGISTER_RD_ADDR_PORTB(REGISTER_RD_ADDR_PORTB)
				,.REGISTER_OUTPUT_PORTB(REGISTER_OUTPUT_PORTB)
				,.ENABLE_OUTPUT_REG_PORTB(ENABLE_OUTPUT_REG_PORTB)
				,.RESET_OUTPUT_REG_PORTB(RESET_OUTPUT_REG_PORTB)
				)
			U1(
				.PortClk({PortBClk, PortAClk})
				,.PortReset({PortBReset, PortAReset})
				,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
				,.PortReadEnable({PortBReadEnable, PortAReadEnable})
				,.PortDataIn({PortBDataIn, PortADataIn})
				,.PortAddr({PortBAddr, PortAAddr})
				,.PortDataOut({PortBDataOut, PortADataOut})
				);  */


endmodule
