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
     module newram3
 //`else
 //    module newram3_rtl
 //`endif
(
	 PortAClk
	,PortAAddr
	,PortADataIn
	,PortAWriteEnable
	,PortAReset
	,PortBAddr
	,PortBReset
	,PortADataOut
	,PortBDataOut
	);


  parameter DATAWIDTH = 9;
  parameter ADDRWIDTH = 13;
  parameter MEMDEPTH  = 2**(ADDRWIDTH);


  parameter SPRAM                    = 0;
  parameter READ_MODE_A              = 2;
  parameter READ_WRITE_A             = 1;
  parameter ENABLE_WR_PORTA          = 1;

  parameter REGISTER_RD_ADDR_PORTA   = 1;

  parameter REGISTER_OUTPUT_PORTA    = 1;
  parameter ENABLE_OUTPUT_REG_PORTA  = 0;
  parameter RESET_OUTPUT_REG_PORTA   = 1;

  parameter READ_MODE_B              = 1;
  parameter READ_WRITE_B             = 2;
  parameter ENABLE_WR_PORTB          = 0;

  parameter REGISTER_RD_ADDR_PORTB 	= 1;

  parameter REGISTER_OUTPUT_PORTB   = 1;
  parameter ENABLE_OUTPUT_REG_PORTB = 0;
  parameter RESET_OUTPUT_REG_PORTB  = 1;

  input PortAClk;
  input [ADDRWIDTH-1:0] PortAAddr;
  input [DATAWIDTH-1:0] PortADataIn;
  input PortAWriteEnable;
  input PortAReset;

  input [ADDRWIDTH-1:0] PortBAddr;
  input PortBReset;

  output [DATAWIDTH-1:0] PortADataOut;
  output [DATAWIDTH-1:0] PortBDataOut;

  wire  PortAClk;
  wire  [ADDRWIDTH-1:0] PortAAddr;
  wire  [DATAWIDTH-1:0] PortADataIn;

  wire [DATAWIDTH-1:0] 		PortADataOut;

  wire  PortAWriteEnable;
  wire  PortAReadEnable;
  wire  PortAReset;

  wire  PortBClk;
  wire  [DATAWIDTH-1:0] PortBDataIn;
  wire  PortBWriteEnable;
  wire  [ADDRWIDTH-1:0] PortBAddr;

  wire [DATAWIDTH-1:0]  PortBDataOut;

  wire  PortBReadEnable;
  wire  PortBReset;

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
				.PortClk({PortAClk, PortAClk})
				,.PortReset({PortBReset, PortAReset})
				,.PortWriteEnable({PortBWriteEnable, PortAWriteEnable})
				,.PortReadEnable({PortBReadEnable, PortAReadEnable})
				,.PortDataIn({PortBDataIn, PortADataIn})
				,.PortAddr({PortBAddr, PortAAddr})
				,.PortDataOut({PortBDataOut, PortADataOut})
				);
endmodule
