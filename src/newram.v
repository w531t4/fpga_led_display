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
 


`timescale 1ns/100ps
 //`ifdef synthesis 
     module newram
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
  wire [ADDRWIDTH:0] addr_a;
  wire [ADDRWIDTH:0] addr_b;
  wire [DATAWIDTH-1:0] data_a_in;
  wire [DATAWIDTH-1:0] data_b_in;
  wire [DATAWIDTH-1:0] data_a_out;
  wire [DATAWIDTH-1:0] data_b_out;
  wire  clk_a;
  wire  clk_b;

  assign addr_a = { PortAAddr[11:0], 1'bz};
  assign addr_b = { PortBAddr[10:0], 2'bz};
  assign data_a_in = { 8'b0, PortADataIn[DATA_A_WIDTH-1:0]};
  assign data_b_in = { PortBDataIn[DATA_B_WIDTH-1:0] };
  assign clk_a = PortAClk && PortAClkEnable;
  assign clk_b = PortBClk && PortBClkEnable;
 Syncore_ram
 #(	
				.SPRAM(0)
				,.READ_MODE_A(2)
				,.READ_MODE_B(2)
				,.READ_WRITE_A(1)
				,.READ_WRITE_B(1)
				,.DATAWIDTH(DATAWIDTH)
				,.ADDRWIDTH(ADDRWIDTH+1)
				,.ENABLE_WR_PORTA(1)
				,.REGISTER_RD_ADDR_PORTA(1)
				,.REGISTER_OUTPUT_PORTA(1)
				,.ENABLE_OUTPUT_REG_PORTA(0)
				,.RESET_OUTPUT_REG_PORTA(1)
				,.ENABLE_WR_PORTB(1)
				,.REGISTER_RD_ADDR_PORTB(1)
				,.REGISTER_OUTPUT_PORTB(1)
				,.ENABLE_OUTPUT_REG_PORTB(0)
				,.RESET_OUTPUT_REG_PORTB(1)	
				) 
			U1(
				.PortClk({clk_B, clk_a})
				,.PortReset({PortBReset, PortAReset})
				,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
				,.PortReadEnable({PortBReadEnable, PortAReadEnable})
				,.PortDataIn({data_b_in, data_a_in})
				,.PortAddr({addr_b, addr_a})
				,.PortDataOut({data_b_out, data_a_out})
				);
assign PortADataOut = { data_a_out[7:0] };
assign PortBDataOut = { data_b_out };

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
