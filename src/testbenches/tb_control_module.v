`timescale 1ns/10ps
module tb_control_module;
// iverilog -vvvv -o blah.vvp t//b_control_module.v clock_divider.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v
// vvp blah.vvp
    // iverilog -s tb_control_module -vvvv -o blah.vvp tb_uart_rx.v tb_control_module.v uart_rx.v timeout.v clock_divider.v control_module.v syncore_ram.v /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v

reg clk;
reg reset;
reg local_reset;
wire rx_line;
//20220106
//reg [7:0] ram_data_in = 8'b01100101;
wire rx_running;
wire [2:0] rgb_enable;
wire [5:0] brightness_enable;
wire [7:0] ram_data_out;
wire [11:0] ram_address;
wire ram_write_enable;
wire [7:0] num_commands_processed;
wire ram_clk_enable;
wire ram_reset;
wire [1:0] cmd_line_state2;


// debugger stuff
wire debug_command_busy;
wire debug_command_pulse;
wire [7:0] debug_command;

//>>> "".join([a[i] for i in range(len(a)-1, -1, -1)])
//'brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110'
reg [1071:0] mystring = "brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110";
//reg tb_clk_baudrate;


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
		.cmd_line_state2(cmd_line_state2),
        .num_commands_processed(num_commands_processed)
	);

	debugger #(
		// 22MHz / 1000000 = 22
		//.DIVIDER_TICKS_WIDTH(20),
		//.DIVIDER_TICKS(1000000),
        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
		.DIVIDER_TICKS_WIDTH(4),
		.DIVIDER_TICKS(15),
		.DATA_WIDTH_BASE2(11),
		.DATA_WIDTH(1072),
        // override the below params to override the default transmit speeds
        .UART_TICKS_PER_BIT(4'd9),
        .UART_TICKS_PER_BIT_SIZE(4)
	) mydebug (
		.clk_in(clk),
		.reset(local_reset),
		.data_in(mystring),
		.debug_uart_rx_in(1'b0),
		.debug_command(debug_command),
		.debug_command_pulse(debug_command_pulse),
		.debug_command_busy(debug_command_busy),
		.tx_out(rx_line)
	);

  initial
  begin
      $dumpfile(`DUMP_FILE_NAME);
      $dumpvars(0, tb_control_module);
      clk = 0;
      reset = 0;
      local_reset = 0;
    repeat (20) begin
        @(posedge clk);
    end
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    repeat (20000) begin
        @(posedge clk);
    end
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    $finish;
  end

always begin
    #22.72727  clk <= ! clk; // 2 of these make a period, 22MHz
end

endmodule
