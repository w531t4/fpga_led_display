`timescale 1ns/10ps
module tb_newram2;
//iverilog -vvv -s tb_newram2 tb_newram2.v newram2.v brightness.v clock_divider.v main.v  timeout.v rgb565.v pixel_split.v matrix_scan.v framebuffer_fetch.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v Multiported-RAM/mpram.v Multiported-RAM/mrram.v  Multiported-RAM/dpram.v  Multiported-RAM/mpram_gen.v



	reg clk;
	reg reset;
	reg local_reset;
	reg [11:0] ram_a_address;
	reg [10:0] ram_b_address;
	reg [7:0] ram_a_data_in;
	reg ram_a_clk_enable;
	reg ram_b_clk_enable;
	wire [7:0] ram_a_data_out;
	wire [15:0] ram_b_data_out;
	newram2 fb (
		.PortAClk(clk),
		.PortAAddr(ram_a_address),
		.PortADataIn(ram_a_data_in),
		.PortAWriteEnable(1'b1),
		.PortAReset(reset),
		.PortBClk(clk),
		.PortBDataIn(16'b0),
		.PortBAddr(ram_b_address),
		.PortBWriteEnable(1'b0),
		.PortBReset(reset),
		.PortADataOut(ram_a_data_out),
		.PortBDataOut(ram_b_data_out),
		.PortAClkEnable(ram_a_clk_enable),
		.PortBClkEnable(ram_b_clk_enable)
	) /* synthesis syn_noprune=1 */ ;

	initial begin
		$dumpfile("tb_newram2.vcd");
		$dumpvars(0, tb_newram2);
		clk = 0;
		reset = 0;
		local_reset = 0;
		ram_a_address = 0;
		ram_b_address = 0;
		ram_a_data_in = 0;
		ram_a_clk_enable = 1;
		ram_b_clk_enable = 1;
		@(posedge clk)
			local_reset = ! local_reset;
		@(posedge clk)
			reset = ! reset;
		@(posedge clk)
			local_reset = ! local_reset;
		@(posedge clk)
			reset = !reset;
		@(posedge clk)
			local_reset = !local_reset;
		@(posedge clk)
			reset = !reset;
		@(posedge clk)
			local_reset = !local_reset;
		@(posedge clk)
			reset = !reset;

		@(posedge clk)
			ram_a_address = 0;
			ram_a_data_in = "A";
			ram_a_clk_enable = 1;
			ram_b_clk_enable = 1;
		@(posedge clk)
			ram_a_address = 1;
			ram_a_data_in = "B";
		@(posedge clk)
			ram_a_address = 2;
			ram_a_data_in = "C";
		@(posedge clk)
			ram_a_address = 3;
			ram_a_data_in = "D";
			ram_b_address = 1;
		@(posedge clk)
		@(posedge clk)
		@(posedge clk)
		@(posedge clk)
			$finish;
	end
	always
		#7.52  clk <=  ~clk;  // produces ~133MHz

endmodule