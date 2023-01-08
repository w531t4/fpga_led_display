`timescale 1ns/10ps
module tb_control_module;
// iverilog -vvvv -o blah.vvp t//b_control_module.v clock_divider.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v
// vvp blah.vvp
    // iverilog -s tb_control_module -vvvv -o blah.vvp tb_uart_rx.v tb_control_module.v uart_rx.v timeout.v clock_divider.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v

reg clk;
reg reset;
reg local_reset;
reg rx_line;
//20220106
//reg [7:0] ram_data_in = 8'b01100101;
wire rx_running;
wire [2:0] rgb_enable;
wire [5:0] brightness_enable;
wire [7:0] ram_data_out;
wire [11:0] ram_address;
wire ram_write_enable;
wire ram_clk_enable;
wire ram_reset;
wire [1:0 ] cmd_line_state2;
//20220106
//wire rx_invalid;


//reg [9:0] mycustom_uart_rx = 9'b1011001010;
//reg [1023:0] mycustom_uart_rx = "L0111223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788";
reg [1071:0] mystring = "01112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677-L Rrb";
//reg [1054:0] mystring = "0111223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667710L Rrb";

//reg [7:0] mycustom_ram_data_in = ;
wire tb_clk_baudrate;
reg start = 1'b0;
reg baudclock = 1'b0;

clock_divider #(
		.CLK_DIV_COUNT(25),
		.CLK_DIV_WIDTH(8)
	) clkdiv_baudrate (
		.reset(local_reset),
		.clk_in(clk),
		.clk_out(tb_clk_baudrate)
	);

control_module #(
    	// we want 22MHz / 2,430,000 = 9.0534
	    // 22MHz / 9 = 2,444,444 baud 2444444
		.UART_CLK_TICKS_PER_BIT(4'd9),
		.UART_CLK_TICKS_WIDTH(4)
	) control_module_instance (
		.reset(reset),
		.clk_in(clk),
		.uart_rx(rx_line),
		.rx_running(rx_running),
		.rgb_enable(rgb_enable),
		.brightness_enable(brightness_enable),
        //20220106
		//.ram_data_in(ram_data_in),
		.ram_data_out(ram_data_out),
		.ram_address(ram_address),
		.ram_write_enable(ram_write_enable),
		.ram_clk_enable(ram_clk_enable),
		.ram_reset(ram_reset),
        //20220106
		//.rx_invalid(rx_invalid),
		.cmd_line_state2(cmd_line_state2)
	);

  initial
  begin
      $dumpfile(`DUMP_FILE_NAME);
      $dumpvars(0, tb_control_module);
      clk = 0;
      reset = 0;
      local_reset = 0;
  end
reg [3:0] i = 'd0;
reg [10:0] j = 'd0;

always @(posedge tb_clk_baudrate) begin

    if (i == 'd10) begin
        rx_line <= 1'b0;
        if (j >= ($bits(mystring)-8)) begin
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

initial begin
    #4000 local_reset = !local_reset;
    #4000 reset = !reset;
end
initial begin
    #4001 local_reset = !local_reset;
    #4001 reset = !reset;
end
initial
    #10000000 $finish;

always begin
    #22.72727  clk <= ! clk; // 2 of these make a period, 22MHz
end

endmodule
