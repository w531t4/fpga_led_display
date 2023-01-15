//*****************************************************
//Title:    sb_ice_syn.v library verilog models
//Design:   sb_ice_syn.v
//Author:
//Function: Verilog behavioral models for
//          sb_ice_syn.v synthesis library
//Company:  SiliconBlue Technologies, Inc.
//Revision History:
// Aug06,2015 Correct SB_IO_I3C pin direction. Jayakumar Sundaram,
// Aug07,2015 Add SB_DELAY_50NS and SB_FILTER_50NS. Brian Tai
// Aug18,2015 Added SCL_INPUT_FILTERED attrib to SB_I2C.Fix minor issues. Jayakumar Sundaram,
// Aug28,2015 Remove primitives SB_DELAY_50NS and SB_FILTER_50NS. Brian Tai
//*************************************************************************

module SB_GB (
GLOBAL_BUFFER_OUTPUT,
USER_SIGNAL_TO_GLOBAL_BUFFER) /* synthesis syn_black_box syn_lib_cell=1*/;

input USER_SIGNAL_TO_GLOBAL_BUFFER;
output GLOBAL_BUFFER_OUTPUT;


endmodule	//SB_GB


/****** ice40 PLL prims*****/
module SB_PLL40_CORE (
		REFERENCECLK,		//Driven by core logic
		PLLOUTCORE,		//PLL output to core logic
		PLLOUTGLOBAL,	   	//PLL output to global network
		EXTFEEDBACK,  			//Driven by core logic
		DYNAMICDELAY,		//Driven by core logic
		LOCK,				//Output of PLL
		BYPASS,				//Driven by core logic
		RESETB,				//Driven by core logic
		SDI,				//Driven by core logic. Test Pin
		SDO,				//Output to RB Logic Tile. Test Pin
		SCLK,				//Driven by core logic. Test Pin
		LATCHINPUTVALUE 	//iCEGate signal
) /* synthesis syn_black_box syn_lib_cell=1*/;
input 	REFERENCECLK;		//Driven by core logic
output 	PLLOUTCORE;		//PLL output to core logic
output	PLLOUTGLOBAL;	   	//PLL output to global network
input	EXTFEEDBACK;  			//Driven by core logic
input	[7:0] DYNAMICDELAY;  	//Driven by core logic
output	LOCK;				//Output of PLL
input	BYPASS;				//Driven by core logic
input	RESETB;				//Driven by core logic
input	LATCHINPUTVALUE; 	//iCEGate signal
//Test Pins
output	SDO;				//Output of PLL
input	SDI;				//Driven by core logic
input	SCLK;				//Driven by core logic


//Feedback
parameter FEEDBACK_PATH = "SIMPLE";	//String  (simple, delay, phase_and_delay, external)
parameter DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
parameter DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
parameter SHIFTREG_DIV_MODE = 2'b0; //0-->Divide by 4, 1-->Divide by 7.
parameter FDA_FEEDBACK = 0; 		//Integer.
parameter FDA_RELATIVE = 0; 		//Integer.
parameter PLLOUT_SELECT = "GENCLK"; //

//Use the Spreadsheet to populate the values below.
parameter DIVR = 4'b0000; 	//determine a good default value
parameter DIVF = 7'b0000000; //determine a good default value
parameter DIVQ = 3'b000; 	//determine a good default value
parameter FILTER_RANGE = 3'b000; 	//determine a good default value

//Additional cbits
parameter ENABLE_ICEGATE = 1'b0;

//Test Mode parameter
parameter TEST_MODE = 1'b0;
parameter EXTERNAL_DIVIDE_FACTOR = 1; //Not used by model. Added for PLL Config GUI.

endmodule // SB_PLL40_CORE


`timescale 1ps/1ps
module SB_RAM4K (RDATA, RCLK, RCLKE, RE, RADDR, WCLK, WCLKE, WE, WADDR, MASK, WDATA);
output [15:0] RDATA;
input RCLK;
input RCLKE;
input RE;
input [7:0] RADDR;
input WCLK;
input WCLKE;
input WE;
input [7:0] WADDR;
input [15:0] MASK;
input [15:0] WDATA;

assign (weak0, weak1) MASK = 16'b0;

parameter INIT_0 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_1 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_2 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_3 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_4 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_5 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_6 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_7 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_8 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_9 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_F = 256'h0000000000000000000000000000000000000000000000000000000000000000;

// local Parameters
localparam			CLOCK_PERIOD = 200;	//
localparam 			DELAY	= (CLOCK_PERIOD/10);		// Clock-to-output delay. Zero
							// time delays can be confusing
							// and sometimes cause problems.
localparam 			BUS_WIDTH = 16;		// Width of RAM (number of bits)

localparam 			ADDRESS_BUS_SIZE = 8;	// Number of bits required to
							// represent the RAM address

localparam   ADDRESSABLE_SPACE  = 2**ADDRESS_BUS_SIZE;	// Decimal address range [2^Size:0]


// SIGNAL DECLARATIONS
wire			   	WCLK_g, RCLK_g;
reg 				WCLKE_sync, RCLKE_sync;
assign (weak0, weak1) RCLKE =1'b1 ;
assign (weak0, weak1) RE =1'b0 ;
assign (weak0, weak1) WCLKE =1'b1 ;
assign (weak0, weak1) WE =1'b0 ;
//reg  [BUS_WIDTH-1:0] Memory [ADDRESSABLE_SPACE-1:0];	// The RAM
reg	Memory	[BUS_WIDTH*ADDRESSABLE_SPACE-1:0];
//
event Read_e, Write_e;

//////////////////// Collision detect begins here ///////////////////////////////
localparam 	TRUE = 1'b1;
localparam	FALSE = 1'b0;
reg 		Time_Collision_Detected = 1'b0;
wire		Address_Collision_Detected;

event Collision_e;

time COLLISION_TIME_WINDOW = (CLOCK_PERIOD/8); // This is an arbitray value, but is better than using an absolute
						    // value, because the actual time window depends on the actual silicon
						    // implementation. Thus the test is indicative of an Error and not
						    // guaranteed to be an error. Even so this is usefull.
time time_WCLK_RCLK, time_WCLK, time_RCLK;


//function reg Check_Timed_Window_Violation;
function	Check_Timed_Window_Violation;	//	by Jeffrey
input T1, T2, Minimum_Time_Window;
time T1, T2;
time Minimum_Time_Window;
time Difference;
	begin
		Difference = (T1 - T2);
		if (Difference < 0) Difference = -Difference;
		Check_Timed_Window_Violation = (Difference < Minimum_Time_Window);
	end
endfunction


initial begin
       time_WCLK = CLOCK_PERIOD;	// Arbitrary initialisation value, ensure no window collison error on first clock edge.
       time_RCLK = (CLOCK_PERIOD*8);	// Arbitrary initialisation difference value, ensure no collision error on first clock edge.
end

integer	i,j;

genvar k;
wire [7:0] RADDR_g;
wire [7:0] WADDR_g;
wire [15:0] WDATA_g;
for (k = 0; k < 8; k = k + 1) begin
	assign RADDR_g[k] = (RADDR[k] === 1'bz)? 1'b0 : RADDR[k];
	assign WADDR_g[k] = (WADDR[k] === 1'bz)? 1'b0 : WADDR[k];
	assign WDATA_g[k] = (WDATA[k] === 1'bz)? 1'b0 : WDATA[k];
	assign WDATA_g[k+8] = (WDATA[k+8] === 1'bz)? 1'b0 : WDATA[k+8];
end

initial	//	initialize ram_4k by parameter, section by section
begin
	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[BUS_WIDTH*i+j]	=	INIT_0[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*1+BUS_WIDTH*i+j]	=	INIT_1[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*2+BUS_WIDTH*i+j]	=	INIT_2[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*3+BUS_WIDTH*i+j]	=	INIT_3[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*4+BUS_WIDTH*i+j]	=	INIT_4[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*5+BUS_WIDTH*i+j]	=	INIT_5[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*6+BUS_WIDTH*i+j]	=	INIT_6[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*7+BUS_WIDTH*i+j]	=	INIT_7[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*8+BUS_WIDTH*i+j]	=	INIT_8[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*9+BUS_WIDTH*i+j]	=	INIT_9[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*10+BUS_WIDTH*i+j]	=	INIT_A[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*11+BUS_WIDTH*i+j]	=	INIT_B[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*12+BUS_WIDTH*i+j]	=	INIT_C[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*13+BUS_WIDTH*i+j]	=	INIT_D[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*14+BUS_WIDTH*i+j]	=	INIT_E[BUS_WIDTH*i+j];
	end

	for	(i=0; i<=256/BUS_WIDTH -1; i=i+1)
	begin
		for	(j=0; j<=BUS_WIDTH-1; j=j+1)
			Memory[256*15+BUS_WIDTH*i+j]	=	INIT_F[BUS_WIDTH*i+j];
	end

end

assign Address_Collision_Detected = ((RE & WE & WCLKE & RCLKE)&(WADDR == RADDR));

always @(WCLK or WCLKE)
begin
	if(~WCLK)
	WCLKE_sync = WCLKE;
end

always @(RCLK or RCLKE)
begin
	if (~RCLK)
	RCLKE_sync = RCLKE;
end

assign WCLK_g = WCLK & WCLKE_sync;
assign RCLK_g = RCLK & RCLKE_sync;

always @(posedge WCLK_g) begin
	time_WCLK = $time;
end

always @(posedge RCLK_g) begin
    	time_RCLK = $time;
end
integer	SB_RAM4K_RDATA_log_file;									//.....................
initial	SB_RAM4K_RDATA_log_file=("SB_RAM4K_RDATA_log_file.txt");	//.....................
always @(posedge WCLK_g) begin

	Time_Collision_Detected = Check_Timed_Window_Violation(time_WCLK,time_RCLK,COLLISION_TIME_WINDOW);
        if (Time_Collision_Detected & Address_Collision_Detected)begin
        	$display("Warning: Write-Read collision detected, Data read value is XXXX\n");
 		$display("WCLK Time: %.3f   RCLK Time:%.3f  ",time_WCLK, time_RCLK,"WADDR: %d   RADDR:%d\n",WADDR, RADDR);
 		$fdisplay(SB_RAM4K_RDATA_log_file,"Warning: Write-Read collision detected, Data read value is XXXX\n");
		$fdisplay(SB_RAM4K_RDATA_log_file,"WCLK Time: %.3f   RCLK Time:%.3f  ",time_WCLK, time_RCLK, "WADDR: %d   RADDR:%d\n",WADDR, RADDR);
 		-> Collision_e;
	end
end




//	code modify for universal verilog compiler

always @ (posedge WCLK_g)
begin
	if	(WE)
	begin
		-> Write_e;
		for	(i=0;i<=BUS_WIDTH-1; i=i+1)
		begin
			if	(MASK[i] !=1)
				Memory[WADDR_g*BUS_WIDTH+i]	<=	WDATA_g[i];
			else
				Memory[WADDR_g*BUS_WIDTH+i]	<=	Memory[WADDR_g*BUS_WIDTH+i];
		end
	end
end

//reg	[15:0]	RDATA = 0;
reg	[15:0]	RDATA;

initial
begin
   RDATA = $random;
end

// Look at the rising edge of the clock

always @ (posedge RCLK_g)
begin
	if	(RE)
	begin
		-> Read_e;
		if	(Time_Collision_Detected & Address_Collision_Detected)
			RDATA <= 16'hXXXX;
		else
			for	(i=0;i<=BUS_WIDTH-1;i=i+1)
				RDATA[i]	<= Memory[RADDR_g*BUS_WIDTH+i];
	end
end

`ifdef TIMINGCHECK
specify
   (RCLK *> RDATA[0]) = (1.0, 1.0);
   (RCLK *> RDATA[1]) = (1.0, 1.0);
   (RCLK *> RDATA[2]) = (1.0, 1.0);
   (RCLK *> RDATA[3]) = (1.0, 1.0);
   (RCLK *> RDATA[4]) = (1.0, 1.0);
   (RCLK *> RDATA[5]) = (1.0, 1.0);
   (RCLK *> RDATA[6]) = (1.0, 1.0);
   (RCLK *> RDATA[7]) = (1.0, 1.0);
   (RCLK *> RDATA[8]) = (1.0, 1.0);
   (RCLK *> RDATA[9]) = (1.0, 1.0);
   (RCLK *> RDATA[10]) = (1.0, 1.0);
   (RCLK *> RDATA[11]) = (1.0, 1.0);
   (RCLK *> RDATA[12]) = (1.0, 1.0);
   (RCLK *> RDATA[13]) = (1.0, 1.0);
   (RCLK *> RDATA[14]) = (1.0, 1.0);
   (RCLK *> RDATA[15]) = (1.0, 1.0);
   $setup(posedge MASK[0], posedge WCLK, 1.0);
   $setup(negedge MASK[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[0], 1.0);
   $hold(posedge WCLK, negedge MASK[0], 1.0);
   $setup(posedge MASK[1], posedge WCLK, 1.0);
   $setup(negedge MASK[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[1], 1.0);
   $hold(posedge WCLK, negedge MASK[1], 1.0);
   $setup(posedge MASK[2], posedge WCLK, 1.0);
   $setup(negedge MASK[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[2], 1.0);
   $hold(posedge WCLK, negedge MASK[2], 1.0);
   $setup(posedge MASK[3], posedge WCLK, 1.0);
   $setup(negedge MASK[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[3], 1.0);
   $hold(posedge WCLK, negedge MASK[3], 1.0);
   $setup(posedge MASK[4], posedge WCLK, 1.0);
   $setup(negedge MASK[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[4], 1.0);
   $hold(posedge WCLK, negedge MASK[4], 1.0);
   $setup(posedge MASK[5], posedge WCLK, 1.0);
   $setup(negedge MASK[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[5], 1.0);
   $hold(posedge WCLK, negedge MASK[5], 1.0);
   $setup(posedge MASK[6], posedge WCLK, 1.0);
   $setup(negedge MASK[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[6], 1.0);
   $hold(posedge WCLK, negedge MASK[6], 1.0);
   $setup(posedge MASK[7], posedge WCLK, 1.0);
   $setup(negedge MASK[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[7], 1.0);
   $hold(posedge WCLK, negedge MASK[7], 1.0);
   $setup(posedge MASK[8], posedge WCLK, 1.0);
   $setup(negedge MASK[8], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[8], 1.0);
   $hold(posedge WCLK, negedge MASK[8], 1.0);
   $setup(posedge MASK[9], posedge WCLK, 1.0);
   $setup(negedge MASK[9], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[9], 1.0);
   $hold(posedge WCLK, negedge MASK[9], 1.0);
   $setup(posedge MASK[10], posedge WCLK, 1.0);
   $setup(negedge MASK[10], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[10], 1.0);
   $hold(posedge WCLK, negedge MASK[10], 1.0);
   $setup(posedge MASK[11], posedge WCLK, 1.0);
   $setup(negedge MASK[11], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[11], 1.0);
   $hold(posedge WCLK, negedge MASK[11], 1.0);
   $setup(posedge MASK[12], posedge WCLK, 1.0);
   $setup(negedge MASK[12], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[12], 1.0);
   $hold(posedge WCLK, negedge MASK[12], 1.0);
   $setup(posedge MASK[13], posedge WCLK, 1.0);
   $setup(negedge MASK[13], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[13], 1.0);
   $hold(posedge WCLK, negedge MASK[13], 1.0);
   $setup(posedge MASK[14], posedge WCLK, 1.0);
   $setup(negedge MASK[14], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[14], 1.0);
   $hold(posedge WCLK, negedge MASK[14], 1.0);
   $setup(posedge MASK[15], posedge WCLK, 1.0);
   $setup(negedge MASK[15], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[15], 1.0);
   $hold(posedge WCLK, negedge MASK[15], 1.0);
   $setup(posedge WADDR[0], posedge WCLK, 1.0);
   $setup(negedge WADDR[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[0], 1.0);
   $hold(posedge WCLK, negedge WADDR[0], 1.0);
   $setup(posedge WADDR[1], posedge WCLK, 1.0);
   $setup(negedge WADDR[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[1], 1.0);
   $hold(posedge WCLK, negedge WADDR[1], 1.0);
   $setup(posedge WADDR[2], posedge WCLK, 1.0);
   $setup(negedge WADDR[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[2], 1.0);
   $hold(posedge WCLK, negedge WADDR[2], 1.0);
   $setup(posedge WADDR[3], posedge WCLK, 1.0);
   $setup(negedge WADDR[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[3], 1.0);
   $hold(posedge WCLK, negedge WADDR[3], 1.0);
   $setup(posedge WADDR[4], posedge WCLK, 1.0);
   $setup(negedge WADDR[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[4], 1.0);
   $hold(posedge WCLK, negedge WADDR[4], 1.0);
   $setup(posedge WADDR[5], posedge WCLK, 1.0);
   $setup(negedge WADDR[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[5], 1.0);
   $hold(posedge WCLK, negedge WADDR[5], 1.0);
   $setup(posedge WADDR[6], posedge WCLK, 1.0);
   $setup(negedge WADDR[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[6], 1.0);
   $hold(posedge WCLK, negedge WADDR[6], 1.0);
   $setup(posedge WADDR[7], posedge WCLK, 1.0);
   $setup(negedge WADDR[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[7], 1.0);
   $hold(posedge WCLK, negedge WADDR[7], 1.0);
   $setup(posedge WDATA[0], posedge WCLK, 1.0);
   $setup(negedge WDATA[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[0], 1.0);
   $hold(posedge WCLK, negedge WDATA[0], 1.0);
   $setup(posedge WDATA[1], posedge WCLK, 1.0);
   $setup(negedge WDATA[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[1], 1.0);
   $hold(posedge WCLK, negedge WDATA[1], 1.0);
   $setup(posedge WDATA[2], posedge WCLK, 1.0);
   $setup(negedge WDATA[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[2], 1.0);
   $hold(posedge WCLK, negedge WDATA[2], 1.0);
   $setup(posedge WDATA[3], posedge WCLK, 1.0);
   $setup(negedge WDATA[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[3], 1.0);
   $hold(posedge WCLK, negedge WDATA[3], 1.0);
   $setup(posedge WDATA[4], posedge WCLK, 1.0);
   $setup(negedge WDATA[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[4], 1.0);
   $hold(posedge WCLK, negedge WDATA[4], 1.0);
   $setup(posedge WDATA[5], posedge WCLK, 1.0);
   $setup(negedge WDATA[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[5], 1.0);
   $hold(posedge WCLK, negedge WDATA[5], 1.0);
   $setup(posedge WDATA[6], posedge WCLK, 1.0);
   $setup(negedge WDATA[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[6], 1.0);
   $hold(posedge WCLK, negedge WDATA[6], 1.0);
   $setup(posedge WDATA[7], posedge WCLK, 1.0);
   $setup(negedge WDATA[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[7], 1.0);
   $hold(posedge WCLK, negedge WDATA[7], 1.0);
   $setup(posedge WDATA[8], posedge WCLK, 1.0);
   $setup(negedge WDATA[8], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[8], 1.0);
   $hold(posedge WCLK, negedge WDATA[8], 1.0);
   $setup(posedge WDATA[9], posedge WCLK, 1.0);
   $setup(negedge WDATA[9], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[9], 1.0);
   $hold(posedge WCLK, negedge WDATA[9], 1.0);
   $setup(posedge WDATA[10], posedge WCLK, 1.0);
   $setup(negedge WDATA[10], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[10], 1.0);
   $hold(posedge WCLK, negedge WDATA[10], 1.0);
   $setup(posedge WDATA[11], posedge WCLK, 1.0);
   $setup(negedge WDATA[11], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[11], 1.0);
   $hold(posedge WCLK, negedge WDATA[11], 1.0);
   $setup(posedge WDATA[12], posedge WCLK, 1.0);
   $setup(negedge WDATA[12], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[12], 1.0);
   $hold(posedge WCLK, negedge WDATA[12], 1.0);
   $setup(posedge WDATA[13], posedge WCLK, 1.0);
   $setup(negedge WDATA[13], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[13], 1.0);
   $hold(posedge WCLK, negedge WDATA[13], 1.0);
   $setup(posedge WDATA[14], posedge WCLK, 1.0);
   $setup(negedge WDATA[14], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[14], 1.0);
   $hold(posedge WCLK, negedge WDATA[14], 1.0);
   $setup(posedge WDATA[15], posedge WCLK, 1.0);
   $setup(negedge WDATA[15], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[15], 1.0);
   $hold(posedge WCLK, negedge WDATA[15], 1.0);
   $setup(posedge WCLKE, posedge WCLK, 1.0);
   $setup(negedge WCLKE, posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WCLKE, 1.0);
   $hold(posedge WCLK, negedge WCLKE, 1.0);
   $setup(posedge WE, posedge WCLK, 1.0);
   $setup(negedge WE, posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WE, 1.0);
   $hold(posedge WCLK, negedge WE, 1.0);
   $setup(posedge RADDR[0], posedge RCLK, 1.0);
   $setup(negedge RADDR[0], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[0], 1.0);
   $hold(posedge RCLK, negedge RADDR[0], 1.0);
   $setup(posedge RADDR[1], posedge RCLK, 1.0);
   $setup(negedge RADDR[1], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[1], 1.0);
   $hold(posedge RCLK, negedge RADDR[1], 1.0);
   $setup(posedge RADDR[2], posedge RCLK, 1.0);
   $setup(negedge RADDR[2], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[2], 1.0);
   $hold(posedge RCLK, negedge RADDR[2], 1.0);
   $setup(posedge RADDR[3], posedge RCLK, 1.0);
   $setup(negedge RADDR[3], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[3], 1.0);
   $hold(posedge RCLK, negedge RADDR[3], 1.0);
   $setup(posedge RADDR[4], posedge RCLK, 1.0);
   $setup(negedge RADDR[4], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[4], 1.0);
   $hold(posedge RCLK, negedge RADDR[4], 1.0);
   $setup(posedge RADDR[5], posedge RCLK, 1.0);
   $setup(negedge RADDR[5], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[5], 1.0);
   $hold(posedge RCLK, negedge RADDR[5], 1.0);
   $setup(posedge RADDR[6], posedge RCLK, 1.0);
   $setup(negedge RADDR[6], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[6], 1.0);
   $hold(posedge RCLK, negedge RADDR[6], 1.0);
   $setup(posedge RADDR[7], posedge RCLK, 1.0);
   $setup(negedge RADDR[7], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[7], 1.0);
   $hold(posedge RCLK, negedge RADDR[7], 1.0);
   $setup(posedge RCLKE, posedge RCLK, 1.0);
   $setup(negedge RCLKE, posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RCLKE, 1.0);
   $hold(posedge RCLK, negedge RCLKE, 1.0);
   $setup(posedge RE, posedge RCLK, 1.0);
   $setup(negedge RE, posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RE, 1.0);
   $hold(posedge RCLK, negedge RE, 1.0);
   // $recovery(posedge RCLK, posedge WCLK, 1.0);
   // $recovery(negedge RCLK, posedge WCLK, 1.0);
   // $removal(posedge RCLK, posedge WCLK, 1.0);
   // $removal(negedge RCLK, posedge WCLK, 1.0);
   // $recovery(posedge WCLK, posedge RCLK, 1.0);
   // $recovery(negedge WCLK, posedge RCLK, 1.0);
   // $removal(posedge WCLK, posedge RCLK, 1.0);
   // $removal(negedge WCLK, posedge RCLK, 1.0);

endspecify
`endif

endmodule	 //	SB_RAM4K

`timescale 1ps/1ps
module SB_RAM40_4K (RDATA, RCLK, RCLKE, RE, RADDR, WCLK, WCLKE, WE, WADDR, MASK, WDATA);
output [15:0] RDATA;
input RCLK;
input RCLKE;
input RE;
input [10:0] RADDR;
input WCLK;
input WCLKE;
input WE;
input [10:0] WADDR;
input [15:0] MASK;
input [15:0] WDATA;

assign (weak0, weak1) MASK = 16'b0;

parameter WRITE_MODE = 0; /// can be integer 0(256X16 mode) or 1(512X8 mode) or 2(1024X4 mode) or 3(2048X2 mode)
parameter READ_MODE = 0;  /// can be integer 0(256X16 mode) or 1(512X8 mode) or 2(1024X4 mode) or 3(2048X2 mode)


parameter INIT_0 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_1 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_2 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_3 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_4 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_5 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_6 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_7 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_8 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_9 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
parameter INIT_F = 256'h0000000000000000000000000000000000000000000000000000000000000000;

wire [15:0] RD;
wire [15:0] WD;
wire [15:0] MASK_RAM;

reg [10:8] RADDR_reg;
always @(posedge RCLK) begin
	RADDR_reg[10:8] <= RADDR[10:8];
end

read_data_decoder read_decoder_inst (
	.di(RD),
	.ai(RADDR_reg[10:8]),
	.ldo(RDATA)
);
defparam read_decoder_inst.READ_MODE = READ_MODE;

write_data_decoder write_decoder_inst (
	.di(WDATA),
	.ldo(WD)
);
defparam write_decoder_inst.WRITE_MODE = WRITE_MODE;

mask_decoder mask_decoder_inst(
	.mi(MASK),
	.ai(WADDR[10:8]),
	.mo(MASK_RAM)
);
defparam mask_decoder_inst.WRITE_MODE = WRITE_MODE;

SB_RAM4K ram_inst (
	.RDATA(RD),
	.RCLK(RCLK),
	.RCLKE(RCLKE),
	.RE(RE),
	.RADDR(RADDR[7:0]),
	.WCLK(WCLK),
	.WCLKE(WCLKE),
	.WE(WE),
	.WADDR(WADDR[7:0]),
	.MASK(MASK_RAM),
	.WDATA(WD));

defparam ram_inst.INIT_0 = INIT_0;
defparam ram_inst.INIT_1 = INIT_1;
defparam ram_inst.INIT_2 = INIT_2;
defparam ram_inst.INIT_3 = INIT_3;
defparam ram_inst.INIT_4 = INIT_4;
defparam ram_inst.INIT_5 = INIT_5;
defparam ram_inst.INIT_6 = INIT_6;
defparam ram_inst.INIT_7 = INIT_7;
defparam ram_inst.INIT_8 = INIT_8;
defparam ram_inst.INIT_9 = INIT_9;
defparam ram_inst.INIT_A = INIT_A;
defparam ram_inst.INIT_B = INIT_B;
defparam ram_inst.INIT_C = INIT_C;
defparam ram_inst.INIT_D = INIT_D;
defparam ram_inst.INIT_E = INIT_E;
defparam ram_inst.INIT_F = INIT_F;

`ifdef TIMINGCHECK
specify
   (RCLK *> RDATA[0]) = (1.0, 1.0);
   (RCLK *> RDATA[1]) = (1.0, 1.0);
   (RCLK *> RDATA[2]) = (1.0, 1.0);
   (RCLK *> RDATA[3]) = (1.0, 1.0);
   (RCLK *> RDATA[4]) = (1.0, 1.0);
   (RCLK *> RDATA[5]) = (1.0, 1.0);
   (RCLK *> RDATA[6]) = (1.0, 1.0);
   (RCLK *> RDATA[7]) = (1.0, 1.0);
   (RCLK *> RDATA[8]) = (1.0, 1.0);
   (RCLK *> RDATA[9]) = (1.0, 1.0);
   (RCLK *> RDATA[10]) = (1.0, 1.0);
   (RCLK *> RDATA[11]) = (1.0, 1.0);
   (RCLK *> RDATA[12]) = (1.0, 1.0);
   (RCLK *> RDATA[13]) = (1.0, 1.0);
   (RCLK *> RDATA[14]) = (1.0, 1.0);
   (RCLK *> RDATA[15]) = (1.0, 1.0);
   $setup(posedge MASK[0], posedge WCLK, 1.0);
   $setup(negedge MASK[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[0], 1.0);
   $hold(posedge WCLK, negedge MASK[0], 1.0);
   $setup(posedge MASK[1], posedge WCLK, 1.0);
   $setup(negedge MASK[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[1], 1.0);
   $hold(posedge WCLK, negedge MASK[1], 1.0);
   $setup(posedge MASK[2], posedge WCLK, 1.0);
   $setup(negedge MASK[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[2], 1.0);
   $hold(posedge WCLK, negedge MASK[2], 1.0);
   $setup(posedge MASK[3], posedge WCLK, 1.0);
   $setup(negedge MASK[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[3], 1.0);
   $hold(posedge WCLK, negedge MASK[3], 1.0);
   $setup(posedge MASK[4], posedge WCLK, 1.0);
   $setup(negedge MASK[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[4], 1.0);
   $hold(posedge WCLK, negedge MASK[4], 1.0);
   $setup(posedge MASK[5], posedge WCLK, 1.0);
   $setup(negedge MASK[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[5], 1.0);
   $hold(posedge WCLK, negedge MASK[5], 1.0);
   $setup(posedge MASK[6], posedge WCLK, 1.0);
   $setup(negedge MASK[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[6], 1.0);
   $hold(posedge WCLK, negedge MASK[6], 1.0);
   $setup(posedge MASK[7], posedge WCLK, 1.0);
   $setup(negedge MASK[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[7], 1.0);
   $hold(posedge WCLK, negedge MASK[7], 1.0);
   $setup(posedge MASK[8], posedge WCLK, 1.0);
   $setup(negedge MASK[8], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[8], 1.0);
   $hold(posedge WCLK, negedge MASK[8], 1.0);
   $setup(posedge MASK[9], posedge WCLK, 1.0);
   $setup(negedge MASK[9], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[9], 1.0);
   $hold(posedge WCLK, negedge MASK[9], 1.0);
   $setup(posedge MASK[10], posedge WCLK, 1.0);
   $setup(negedge MASK[10], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[10], 1.0);
   $hold(posedge WCLK, negedge MASK[10], 1.0);
   $setup(posedge MASK[11], posedge WCLK, 1.0);
   $setup(negedge MASK[11], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[11], 1.0);
   $hold(posedge WCLK, negedge MASK[11], 1.0);
   $setup(posedge MASK[12], posedge WCLK, 1.0);
   $setup(negedge MASK[12], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[12], 1.0);
   $hold(posedge WCLK, negedge MASK[12], 1.0);
   $setup(posedge MASK[13], posedge WCLK, 1.0);
   $setup(negedge MASK[13], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[13], 1.0);
   $hold(posedge WCLK, negedge MASK[13], 1.0);
   $setup(posedge MASK[14], posedge WCLK, 1.0);
   $setup(negedge MASK[14], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[14], 1.0);
   $hold(posedge WCLK, negedge MASK[14], 1.0);
   $setup(posedge MASK[15], posedge WCLK, 1.0);
   $setup(negedge MASK[15], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge MASK[15], 1.0);
   $hold(posedge WCLK, negedge MASK[15], 1.0);
   $setup(posedge WADDR[0], posedge WCLK, 1.0);
   $setup(negedge WADDR[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[0], 1.0);
   $hold(posedge WCLK, negedge WADDR[0], 1.0);
   $setup(posedge WADDR[1], posedge WCLK, 1.0);
   $setup(negedge WADDR[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[1], 1.0);
   $hold(posedge WCLK, negedge WADDR[1], 1.0);
   $setup(posedge WADDR[2], posedge WCLK, 1.0);
   $setup(negedge WADDR[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[2], 1.0);
   $hold(posedge WCLK, negedge WADDR[2], 1.0);
   $setup(posedge WADDR[3], posedge WCLK, 1.0);
   $setup(negedge WADDR[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[3], 1.0);
   $hold(posedge WCLK, negedge WADDR[3], 1.0);
   $setup(posedge WADDR[4], posedge WCLK, 1.0);
   $setup(negedge WADDR[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[4], 1.0);
   $hold(posedge WCLK, negedge WADDR[4], 1.0);
   $setup(posedge WADDR[5], posedge WCLK, 1.0);
   $setup(negedge WADDR[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[5], 1.0);
   $hold(posedge WCLK, negedge WADDR[5], 1.0);
   $setup(posedge WADDR[6], posedge WCLK, 1.0);
   $setup(negedge WADDR[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[6], 1.0);
   $hold(posedge WCLK, negedge WADDR[6], 1.0);
   $setup(posedge WADDR[7], posedge WCLK, 1.0);
   $setup(negedge WADDR[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[7], 1.0);
   $hold(posedge WCLK, negedge WADDR[7], 1.0);
   $setup(posedge WADDR[8], posedge WCLK, 1.0);
   $setup(negedge WADDR[8], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[8], 1.0);
   $hold(posedge WCLK, negedge WADDR[8], 1.0);
   $setup(posedge WADDR[9], posedge WCLK, 1.0);
   $setup(negedge WADDR[9], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[9], 1.0);
   $hold(posedge WCLK, negedge WADDR[9], 1.0);
   $setup(posedge WADDR[10], posedge WCLK, 1.0);
   $setup(negedge WADDR[10], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WADDR[10], 1.0);
   $hold(posedge WCLK, negedge WADDR[10], 1.0);
   $setup(posedge WDATA[0], posedge WCLK, 1.0);
   $setup(negedge WDATA[0], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[0], 1.0);
   $hold(posedge WCLK, negedge WDATA[0], 1.0);
   $setup(posedge WDATA[1], posedge WCLK, 1.0);
   $setup(negedge WDATA[1], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[1], 1.0);
   $hold(posedge WCLK, negedge WDATA[1], 1.0);
   $setup(posedge WDATA[2], posedge WCLK, 1.0);
   $setup(negedge WDATA[2], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[2], 1.0);
   $hold(posedge WCLK, negedge WDATA[2], 1.0);
   $setup(posedge WDATA[3], posedge WCLK, 1.0);
   $setup(negedge WDATA[3], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[3], 1.0);
   $hold(posedge WCLK, negedge WDATA[3], 1.0);
   $setup(posedge WDATA[4], posedge WCLK, 1.0);
   $setup(negedge WDATA[4], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[4], 1.0);
   $hold(posedge WCLK, negedge WDATA[4], 1.0);
   $setup(posedge WDATA[5], posedge WCLK, 1.0);
   $setup(negedge WDATA[5], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[5], 1.0);
   $hold(posedge WCLK, negedge WDATA[5], 1.0);
   $setup(posedge WDATA[6], posedge WCLK, 1.0);
   $setup(negedge WDATA[6], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[6], 1.0);
   $hold(posedge WCLK, negedge WDATA[6], 1.0);
   $setup(posedge WDATA[7], posedge WCLK, 1.0);
   $setup(negedge WDATA[7], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[7], 1.0);
   $hold(posedge WCLK, negedge WDATA[7], 1.0);
   $setup(posedge WDATA[8], posedge WCLK, 1.0);
   $setup(negedge WDATA[8], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[8], 1.0);
   $hold(posedge WCLK, negedge WDATA[8], 1.0);
   $setup(posedge WDATA[9], posedge WCLK, 1.0);
   $setup(negedge WDATA[9], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[9], 1.0);
   $hold(posedge WCLK, negedge WDATA[9], 1.0);
   $setup(posedge WDATA[10], posedge WCLK, 1.0);
   $setup(negedge WDATA[10], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[10], 1.0);
   $hold(posedge WCLK, negedge WDATA[10], 1.0);
   $setup(posedge WDATA[11], posedge WCLK, 1.0);
   $setup(negedge WDATA[11], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[11], 1.0);
   $hold(posedge WCLK, negedge WDATA[11], 1.0);
   $setup(posedge WDATA[12], posedge WCLK, 1.0);
   $setup(negedge WDATA[12], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[12], 1.0);
   $hold(posedge WCLK, negedge WDATA[12], 1.0);
   $setup(posedge WDATA[13], posedge WCLK, 1.0);
   $setup(negedge WDATA[13], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[13], 1.0);
   $hold(posedge WCLK, negedge WDATA[13], 1.0);
   $setup(posedge WDATA[14], posedge WCLK, 1.0);
   $setup(negedge WDATA[14], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[14], 1.0);
   $hold(posedge WCLK, negedge WDATA[14], 1.0);
   $setup(posedge WDATA[15], posedge WCLK, 1.0);
   $setup(negedge WDATA[15], posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WDATA[15], 1.0);
   $hold(posedge WCLK, negedge WDATA[15], 1.0);
   $setup(posedge WCLKE, posedge WCLK, 1.0);
   $setup(negedge WCLKE, posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WCLKE, 1.0);
   $hold(posedge WCLK, negedge WCLKE, 1.0);
   $setup(posedge WE, posedge WCLK, 1.0);
   $setup(negedge WE, posedge WCLK, 1.0);
   $hold(posedge WCLK, posedge WE, 1.0);
   $hold(posedge WCLK, negedge WE, 1.0);
   $setup(posedge RADDR[0], posedge RCLK, 1.0);
   $setup(negedge RADDR[0], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[0], 1.0);
   $hold(posedge RCLK, negedge RADDR[0], 1.0);
   $setup(posedge RADDR[1], posedge RCLK, 1.0);
   $setup(negedge RADDR[1], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[1], 1.0);
   $hold(posedge RCLK, negedge RADDR[1], 1.0);
   $setup(posedge RADDR[2], posedge RCLK, 1.0);
   $setup(negedge RADDR[2], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[2], 1.0);
   $hold(posedge RCLK, negedge RADDR[2], 1.0);
   $setup(posedge RADDR[3], posedge RCLK, 1.0);
   $setup(negedge RADDR[3], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[3], 1.0);
   $hold(posedge RCLK, negedge RADDR[3], 1.0);
   $setup(posedge RADDR[4], posedge RCLK, 1.0);
   $setup(negedge RADDR[4], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[4], 1.0);
   $hold(posedge RCLK, negedge RADDR[4], 1.0);
   $setup(posedge RADDR[5], posedge RCLK, 1.0);
   $setup(negedge RADDR[5], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[5], 1.0);
   $hold(posedge RCLK, negedge RADDR[5], 1.0);
   $setup(posedge RADDR[6], posedge RCLK, 1.0);
   $setup(negedge RADDR[6], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[6], 1.0);
   $hold(posedge RCLK, negedge RADDR[6], 1.0);
   $setup(posedge RADDR[7], posedge RCLK, 1.0);
   $setup(negedge RADDR[7], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[7], 1.0);
   $hold(posedge RCLK, negedge RADDR[7], 1.0);
   $setup(posedge RADDR[8], posedge RCLK, 1.0);
   $setup(negedge RADDR[8], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[8], 1.0);
   $hold(posedge RCLK, negedge RADDR[8], 1.0);
   $setup(posedge RADDR[9], posedge RCLK, 1.0);
   $setup(negedge RADDR[9], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[9], 1.0);
   $hold(posedge RCLK, negedge RADDR[9], 1.0);
   $setup(posedge RADDR[10], posedge RCLK, 1.0);
   $setup(negedge RADDR[10], posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RADDR[10], 1.0);
   $hold(posedge RCLK, negedge RADDR[10], 1.0);
   $setup(posedge RCLKE, posedge RCLK, 1.0);
   $setup(negedge RCLKE, posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RCLKE, 1.0);
   $hold(posedge RCLK, negedge RCLKE, 1.0);
   $setup(posedge RE, posedge RCLK, 1.0);
   $setup(negedge RE, posedge RCLK, 1.0);
   $hold(posedge RCLK, posedge RE, 1.0);
   $hold(posedge RCLK, negedge RE, 1.0);

endspecify
`endif

endmodule //SB_RAM40_4K



module read_data_decoder (
	di,
	ai,
	ldo
);

parameter READ_MODE = 0;

input [15:0] di;
input [2:0] ai;
output [15:0] ldo;
reg [15:0] ldo;

reg [1:0]mode;

initial
begin
	if(READ_MODE == 0)
		mode = 2'b00;
	else if(READ_MODE == 1)
		mode = 2'b01;
	else if(READ_MODE == 2)
		mode = 2'b10;
	else if(READ_MODE == 3)
		mode = 2'b11;
	else
	begin
		$display (" SBT ERROR :  Unknown RAM READ MODE\n");
		$display (" Valid Modes are : 0, 1, 2, 3\n");
		//$display (" 0 -- 256X16 mode \n 1-- 512X8 mode \n 2 -- 1024X4 mode \n 3 -- 2048X2  mode \n");
		$finish;
	end
end

always @(mode, di, ai)
begin
	casex({mode,ai})
		5'b00xxx: ldo = di;
		5'b01xx0: ldo = {1'b0,di[14],1'b0,di[12],1'b0,di[10],1'b0,di[8],1'b0,di[6],1'b0,di[4],1'b0,di[2],1'b0,di[0]};
		5'b01xx1: ldo = {1'b0,di[15],1'b0,di[13],1'b0,di[11],1'b0,di[9],1'b0,di[7],1'b0,di[5],1'b0,di[3],1'b0,di[1]};
		5'b10x00: ldo = {1'b0,1'b0,di[12],1'b0,1'b0,1'b0,di[8],1'b0,1'b0,1'b0,di[4],1'b0,1'b0,1'b0,di[0],1'b0};
		5'b10x01: ldo = {1'b0,1'b0,di[13],1'b0,1'b0,1'b0,di[9],1'b0,1'b0,1'b0,di[5],1'b0,1'b0,1'b0,di[1],1'b0};
		5'b10x10: ldo = {1'b0,1'b0,di[14],1'b0,1'b0,1'b0,di[10],1'b0,1'b0,1'b0,di[6],1'b0,1'b0,1'b0,di[2],1'b0};
		5'b10x11: ldo = {1'b0,1'b0,di[15],1'b0,1'b0,1'b0,di[11],1'b0,1'b0,1'b0,di[7],1'b0,1'b0,1'b0,di[3],1'b0};
		5'b11000: ldo = {1'b0,1'b0,1'b0,1'b0,di[8],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[0],1'b0,1'b0,1'b0};
		5'b11001: ldo = {1'b0,1'b0,1'b0,1'b0,di[9],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[1],1'b0,1'b0,1'b0};
		5'b11010: ldo = {1'b0,1'b0,1'b0,1'b0,di[10],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[2],1'b0,1'b0,1'b0};
		5'b11011: ldo = {1'b0,1'b0,1'b0,1'b0,di[11],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[3],1'b0,1'b0,1'b0};
		5'b11100: ldo = {1'b0,1'b0,1'b0,1'b0,di[12],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[4],1'b0,1'b0,1'b0};
		5'b11101: ldo = {1'b0,1'b0,1'b0,1'b0,di[13],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[5],1'b0,1'b0,1'b0};
		5'b11110: ldo = {1'b0,1'b0,1'b0,1'b0,di[14],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[6],1'b0,1'b0,1'b0};
		5'b11111: ldo = {1'b0,1'b0,1'b0,1'b0,di[15],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,di[7],1'b0,1'b0,1'b0};
		default:
		begin
			$display ("SBT ERROR: End up in unknown address\n");
			$finish;
		end
	endcase
end

endmodule  // read_data_decoder

`timescale 1ps/1ps
module write_data_decoder (
	di,
	ldo
);

parameter WRITE_MODE = 0;

input [15:0] di;
output [15:0] ldo;

reg [15:0] ldo;


reg [1:0]mode;

initial
begin
	if(WRITE_MODE == 0)
		mode = 2'b00;
	else if(WRITE_MODE == 1)
		mode = 2'b01;
	else if(WRITE_MODE == 2)
		mode = 2'b10;
	else if(WRITE_MODE == 3)
		mode = 2'b11;
	else
	begin
		$display (" SBT ERROR :  Unknown RAM WRITE MODE\n");
		$display (" Valid Modes are : 0, 1, 2, 3\n");
		//$display (" 0 -- 256X16 mode \n 1-- 512X8 mode \n 2 -- 1024X4 mode \n 3 -- 2048X2  mode \n");
		$finish;
	end
end

always @(mode, di )
begin
	case(mode)
		2'b00: ldo = di;
		2'b01: ldo = {di[14],di[14],di[12],di[12],di[10],di[10],di[8],di[8],di[6],di[6],di[4],di[4],di[2],di[2],di[0],di[0]};
		2'b10: ldo = {di[13],di[13],di[13],di[13],di[9],di[9],di[9],di[9],di[5],di[5],di[5],di[5],di[1],di[1],di[1],di[1]};
		2'b11: ldo = {di[11],di[11],di[11],di[11],di[11],di[11],di[11],di[11],di[3],di[3],di[3],di[3],di[3],di[3],di[3],di[3]};
	endcase
end

endmodule  // write_data_decoder

`timescale 1ps/1ps
module mask_decoder (
	mi,
	ai,
	mo
);

parameter WRITE_MODE = 0;

input [15:0] mi;
input [2:0] ai;
output [15:0] mo;

reg [15:0] mo;

reg [1:0]mode;

initial
begin
	if(WRITE_MODE == 0)
		mode = 2'b00;
	else if(WRITE_MODE == 1)
		mode = 2'b01;
	else if(WRITE_MODE == 2)
		mode = 2'b10;
	else if(WRITE_MODE == 3)
		mode = 2'b11;
	else
	begin
		$display (" SBT ERROR :  Unknown RAM WRITE MODE\n");
		$display (" Valid Modes are : 0, 1, 2, 3\n");
		//$display (" 0 -- 256X16 mode \n 1-- 512X8 mode \n 2 -- 1024X4 mode \n 3 -- 2048X2  mode \n");
		$finish;
	end
end

always @(mode, mi, ai )
begin
	casex({mode,ai})
		5'b00xxx: mo = mi;
		5'b01xx0: mo = 16'hAAAA;
		5'b01xx1: mo = 16'h5555;
		5'b10x00: mo = 16'hEEEE;
		5'b10x01: mo = 16'hDDDD;
		5'b10x10: mo = 16'hBBBB;
		5'b10x11: mo = 16'h7777;
		5'b11000: mo = 16'hFEFE;
		5'b11001: mo = 16'hFDFD;
		5'b11010: mo = 16'hFBFB;
		5'b11011: mo = 16'hF7F7;
		5'b11100: mo = 16'hEFEF;
		5'b11101: mo = 16'hDFDF;
		5'b11110: mo = 16'hBFBF;
		5'b11111: mo = 16'h7F7F;
		default :
		begin
			$display ("SBT ERROR: End up in unknown address\n");
			$finish;
		end
	endcase
end

endmodule  // mask_decoder
