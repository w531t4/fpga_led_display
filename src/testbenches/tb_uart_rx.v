`timescale 1ns/10ps
module tb_uart_rx;
	//parameter UART_CLK_DIV_COUNT = 25, /* 133 MHz in / 50 = ~2.5 Mbaud (actually 2.66 Mbaud) */
	/* inbound clk_in is == 5.32MHz T=0.0000001879699 == 187.9699 ns */
	/* in DIV_COUNT=25 DIV_WIDTH=8 clk_in=133MHz period_clk_in=~7.52ns */
    // iverilog -s tb_uart_rx -vvvv -o blah.vvp tb_uart_rx.v tb_control_module.v uart_rx.v timeout.v clock_divider.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v

reg clk;
reg local_reset;
reg reset;
reg rx_line = 1'b1;
wire [7:0] rx_data;
wire rx_running;
wire rx_invalid;
wire tb_clk_baudrate;

// The following does NOT work
//reg [23:0] mystring = 24'b010000010100001001000011;
// while the following DOES work
reg [31:0] mystring = "ABC ";
//reg [31:0] mystring = 32'b01000001010000100100001111000010;
/*
>>> bin(ord('A'))
'0b1000001'
>>> bin(ord('B'))
'0b1000010'
>>> bin(ord('C'))
'0b1000011'
*/
	clock_divider #(
		.CLK_DIV_COUNT(25),
		.CLK_DIV_WIDTH(8)
	) clkdiv_baudrate (
		.reset(local_reset),
		.clk_in(clk),
		.clk_out(tb_clk_baudrate)
	);


uart_rx #(
		.CLK_DIV_COUNT(25),
		.CLK_DIV_WIDTH(8)
	) uart_rx_instance (
		.reset(reset),
		.clk_in(clk),
		.rx_line_beforesync(rx_line),
		.rx_data(rx_data),
		.rx_running(rx_running),
		.rx_invalid(rx_invalid)
	);

  initial 
  begin 
      $dumpfile("tb_uart_rx.vcd");
	  $dumpvars(0, tb_uart_rx);
	  clk = 0;
	  reset = 0;
	  local_reset = 0;
  end 
  reg [3:0] i = 'd0;
  reg [8:0] j = 'd0;

  always @(posedge tb_clk_baudrate) begin
	  if (i == 'd10) begin
		  rx_line <= 1'b0;
		  if (j >= 'd24) begin
			  j <= 'd0;
		  end
		  else begin
			  j <= j + 'd8;
		  end
		  i <= 'd0;
	  end
	  else if (i == 'd9) begin
		  rx_line <= 1'b1;
		  i <= i+1;
	  end
	  else if (i == 'd8) begin
		  rx_line <= 1'b1;
		  i <= i+1;
	  end
	  else begin
		  rx_line <= mystring[i + j];
		  i <= i+1;
	  end
  end

  initial begin
  #2 local_reset = ! local_reset;
  #2 reset = ! reset;
  end



  initial begin
  #3 local_reset = ! local_reset;
  #3 reset = !reset;
  end

  initial
  #4000 local_reset = !local_reset;
  initial
  #4001 local_reset = !local_reset;
  initial
  #10000000 $finish;
    
  always begin
     #7.52  clk <=  ! clk;  // produces ~133MHz
  end
endmodule
