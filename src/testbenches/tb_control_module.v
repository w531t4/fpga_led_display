`timescale 1ns/10ps
module tb_control_module;
	// RX image data @ 2.44Mbaud
	// 50MHz / 2444444 = 20.454549 -> 50Mhz/21 -> 2380952
	parameter CTRLR_CLK_TICKS_PER_BIT = 5'd21;
	parameter CTRLR_CLK_TICKS_WIDTH = 3'd5;

	// Debug TX @ 115k baud
	// 50MHz / 115183 = 434.02777
	parameter DEBUG_TX_UART_TICKS_PER_BIT = 9'd434;
	parameter DEBUG_TX_UART_TICKS_PER_BIT_WIDTH = 4'd9;
	//#10 clk <= !clk; // 50MHz (1/50000000./2 = 10 EE-8)

	// 50MHz / 22 = 2272727.27272
	// log2(6045455) = 21.1159929 -> 22
	parameter DEBUG_MSGS_PER_SEC_TICKS = 22'd2272727;
	parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH = 5'd22;

`ifdef SIM
	// use smaller value in testbench so we don't infinitely sim
	parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;
	parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM = 3'd4;

    parameter SIM_HALF_PERIOD_NS = 10; // 50MHz (1/50000000./2 = 10 EE-8)
`endif
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
		// Picture/Video data RX baud rate
		.UART_CLK_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT),
		.UART_CLK_TICKS_WIDTH(CTRLR_CLK_TICKS_WIDTH)
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
		.DATA_WIDTH_BASE2(11),
		.DATA_WIDTH(1072),
        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
		.DIVIDER_TICKS_WIDTH(DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM),
		.DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS_SIM),

		// We're using the debugger here as a data transmitter only. Need
		// to transmit at the same speed as the controller is expecting to
		// receive at
        .UART_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT),
        .UART_TICKS_PER_BIT_SIZE(CTRLR_CLK_TICKS_WIDTH)
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
	#SIM_HALF_PERIOD_NS clk <= !clk;
end

endmodule
