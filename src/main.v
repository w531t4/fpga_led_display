//`include "/home/awhite/lscc/iCEcube2.2017.08/synpbase/lib/syncore/models/memories/ram/syncore_ram.v"
module main (
//while true; do for each in `seq -s " " -f %02g 0 31`; do echo L${each}11223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788 > /dev/ttyAMA0; done; done
	// DP74HC245 710401
	// FM TC7258E. 5B855300 2X
	// CHIPONE ICN2028BP A06631HA

	// lessons
	// 1. Ensure that all unused IO are set to no pullup

  input pin3_clk_16mhz,
  output pin3,
  output pin4,
  output pin5,
  output pin6,
  input pin7,
  output pin8,
  output pin9,
  output pin10,
  //output pin11,
  output pin12,
  output pin13,
  output pin18,
  output pin19,
  output pin20,
  output pin21,
  // output pin22,
  output pin23,
  input pin24
);
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

	wire clk_root;

	reg global_reset;
	wire buffered_global_reset;

	wire clk_pixel_load;
	wire clk_pixel;
	wire clk_pixel_load_en;
	wire [3:0] pixel_load_counter2;

	wire row_latch;
	wire row_latch_intermediary;
	wire [1:0] row_latch_state;

	wire [7:0] ram_a_data_in;
	wire [7:0] ram_a_data_out;
	wire [11:0] ram_a_address;
	wire ram_a_write_enable;
	wire ram_a_clk_enable;
	wire ram_a_reset;

	wire ram_access_start;
	wire ram_access_start_latch;

	wire [15:0] ram_b_data_out;
	wire [10:0] ram_b_address;
	wire ram_b_clk_enable;
	wire ram_b_reset;

	wire [15:0] pixel_rgb565_top;
	wire [15:0] pixel_rgb565_bottom;

	wire state_advance;
	wire [1:0] cmd_line_state;
	wire [11:0] cmd_line_addr2;
	wire uart_rx;
	wire [7:0] uart_rx_data;
	wire rx_running;

	wire debug_uart_rx;
	wire [7:0] debug_command;
	wire debug_command_pulse;
    wire debug_command_busy;
	wire tx_out;

	wire [5:0] column_address;
	wire [3:0] row_address;
	wire [3:0] row_address_active;
	wire [5:0] brightness_mask;

	wire [2:0] rgb_enable;
	wire [5:0] brightness_enable;
	wire [2:0] rgb1; /* the current RGB value for the top-half of the display */
	wire [2:0] rgb1_intermediary;
	wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */
	wire [2:0] rgb2_intermediary;

	wire output_enable;
	wire output_enable_intermediary;

	wire [7:0] num_commands_processed;

	wire [191:0] ddata =  {
		//
		3'b0,
		//								181
		num_commands_processed[7:0],
		debug_command[7:0],
		pixel_load_counter2[3:0],
		clk_pixel_load_en,
		clk_pixel_load,
		cmd_line_addr2[11:7], 		// 5
		~cmd_line_addr2[6:1], cmd_line_addr2[0], //7
		//								155
		cmd_line_addr2[11:0],
		rgb2[2:0],
		rgb1[2:0],
		rx_running,
		row_latch,
		row_latch_state[1:0],
		ram_b_reset,
		cmd_line_state[1:0],
		uart_rx,
		ram_access_start_latch,
		ram_access_start,
		//								127
		pixel_rgb565_top[15:0],
		pixel_rgb565_bottom[15:0],
		brightness_mask[5:0],
		brightness_enable[5:0],
		rgb_enable[2:0],
		column_address[5:0],
		row_address[3:0],
		row_address_active[3:0],
		ram_b_address[10:0],
		ram_b_clk_enable,
		ram_b_data_out[15:0],
		ram_a_write_enable,
		ram_a_data_out[7:0],
		ram_a_address[11:0],
		ram_a_clk_enable,
		ram_a_data_in[7:0],
		uart_rx_data[7:0]
		}  /* synthesis syn_preserve = 1 */ ;

	// No wires past here

	pll new_pll_inst (
		.clock_in(pin3_clk_16mhz),
		.clock_out(clk_root)
	) /* synthesis syn_noprune=1 */ ;

fm6126init do_init (
	.clk_in(clk_root),
	//.reset(system_init_enable),
	.reset(global_reset),
	.output_enable_in(output_enable_intermediary),
	.rgb1_in(rgb1_intermediary),
	.rgb2_in(rgb2_intermediary),
	.latch_in(row_latch_intermediary),
	.output_enable_out(output_enable),
	.rgb1_out(rgb1),
	.rgb2_out(rgb2),
	.latch_out(row_latch)
) /* synthesis syn_noprune=1 */ ;

	timeout #(
		.COUNTER_WIDTH(4)
	) timeout_global_reset (
		.reset(1'b0),
		//.reset(debug_command == "H"),
		.clk_in(clk_root),
		//.start(1'b1),
		.start(~((debug_command == "H") && debug_command_pulse)),
		.value(4'd15),
		.counter(),
		.running(buffered_global_reset)
	) /* synthesis syn_noprune=1 */;

	/* produce a clock for use on the LED matrix */
	reg [1:0] sync_fifo;
	// this is a buffer to transfer global reset across clock domains
	// TODO: Is this still needed?
	always @(posedge clk_root) begin
			{ global_reset, sync_fifo } <= { sync_fifo, buffered_global_reset };

	//always @(posedge clk_root_logic)

	end

	/* produce signals to scan a 64x32 LED matrix, with 6-bit color */

	matrix_scan matscan1 (
		.reset(global_reset),
		.clk_in(clk_root),
		.column_address(column_address),
		.row_address(row_address),
		.row_address_active(row_address_active),
		.clk_pixel_load(clk_pixel_load),
		.clk_pixel(clk_pixel),
		.row_latch(row_latch_intermediary),
		.output_enable(output_enable_intermediary),
		.brightness_mask(brightness_mask),
		.state_advance2(state_advance),
		.row_latch_state2(row_latch_state),
		.clk_pixel_load_en2(clk_pixel_load_en)
	) /* synthesis syn_noprune=1 */ ;

	/* the fetch controller */
	framebuffer_fetch fb_f (
		.reset(global_reset),
		.clk_in(clk_root),

		.column_address(column_address),
		.row_address(row_address),
		.pixel_load_start(clk_pixel_load),

		.ram_data_in(ram_b_data_out),
		.ram_address(ram_b_address),
		.ram_clk_enable(ram_b_clk_enable),
		.ram_reset(ram_b_reset),

		.rgb565_top(pixel_rgb565_top),
		.rgb565_bottom(pixel_rgb565_bottom),

		.pixel_load_counter2(pixel_load_counter2)
	) /* synthesis syn_noprune=1 */ ;

	/* the control module */
	control_module #(
		// The baudrate that we will receive image data over
		.UART_CLK_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT),
		.UART_CLK_TICKS_WIDTH(CTRLR_CLK_TICKS_WIDTH)
	) ctrl (
		.reset(global_reset),
		.clk_in(clk_root),
		/* clk_root =  133MHZ */

		.uart_rx(uart_rx),
		.rx_running(rx_running),

		.rgb_enable(rgb_enable),
		.brightness_enable(brightness_enable),

		//.ram_data_in(ram_a_data_out),
		.ram_data_out(ram_a_data_in),
		.ram_address(ram_a_address),
		.ram_write_enable(ram_a_write_enable),
		.ram_clk_enable(ram_a_clk_enable),
		.ram_reset(ram_a_reset),

		.cmd_line_state2(cmd_line_state),
		.rx_data(uart_rx_data),
		.ram_access_start2(ram_access_start),
		.ram_access_start_latch2(ram_access_start_latch),
		.cmd_line_addr2(cmd_line_addr2),
        .num_commands_processed(num_commands_processed)

	) /* synthesis syn_noprune=1 */ ;

/*
	newram2 fb (
		.PortAClk(clk_root),
		.PortAAddr(ram_a_address),
		.PortADataIn(ram_a_data_in),
		.PortAWriteEnable(ram_a_write_enable),
		.PortAReset(global_reset),
		.PortBClk(clk_root),
		.PortBDataIn(16'b0),
		.PortBAddr(ram_b_address),
		.PortBWriteEnable(1'b0),
		.PortBReset(ram_b_reset),
		.PortADataOut(ram_a_data_out),
		.PortBDataOut(ram_b_data_out),
		.PortAClkEnable(ram_a_clk_enable),
		.PortBClkEnable(ram_b_clk_enable)
	) */ /* synthesis syn_noprune=1 */ //;
	multimem fb (
		.ClockA(clk_root),
		.AddressA(ram_a_address),
		.DataInA(ram_a_data_in),
		.WrA(ram_a_write_enable),
		.ResetA(global_reset),
		.ClockB(clk_root),
		.DataInB(16'b0),
		.AddressB(ram_b_address),
		.WrB(1'b0),
		.ResetB(ram_b_reset),
		.QA(ram_a_data_out),
		.QB(ram_b_data_out),
		.ClockEnA(ram_a_clk_enable),
		.ClockEnB(ram_b_clk_enable)
	)  /* synthesis syn_noprune=1 */ ;

	/* split the pixels and get the current brightness' bit */
	pixel_split px_top (
		.pixel_rgb565(pixel_rgb565_top),
		.brightness_mask(brightness_mask & brightness_enable),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb1_intermediary)
	) /* synthesis syn_noprune=1 */ ;
	pixel_split px_bottom (
		.pixel_rgb565(pixel_rgb565_bottom),
		.brightness_mask(brightness_mask & brightness_enable),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb2_intermediary)
	) /* synthesis syn_noprune=1 */ ;



	debugger #(
		// Describes the sample rate of messages sent to debugger client
		.DIVIDER_TICKS_WIDTH(DEBUG_MSGS_PER_SEC_TICKS_WIDTH),
		.DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS),
		.DATA_WIDTH_BASE2(8),
		.DATA_WIDTH(192),
		// Describes the baudrate for sending messages to debugger client
		.UART_TICKS_PER_BIT(DEBUG_TX_UART_TICKS_PER_BIT),
		.UART_TICKS_PER_BIT_SIZE(DEBUG_TX_UART_TICKS_PER_BIT_WIDTH)
	) mydebug (
		.clk_in(clk_root),
		.reset(global_reset),
		.data_in(ddata),
		.debug_uart_rx_in(debug_uart_rx),
		.debug_command(debug_command),
		.debug_command_pulse(debug_command_pulse),
		.debug_command_busy(debug_command_busy),
		.tx_out(tx_out)
	);

	/* use this signal for insight! */

	// A/ Row[0]
	assign pin3 = row_address_active[0];
	// B / Row[1]
	assign pin4 = row_address_active[1];
	// C / Row[2]
	assign pin5 = row_address_active[2];
	// D / Row[3]
	assign pin6 = row_address_active[3];
	// Uart Rx
	assign uart_rx = pin7;
	// Row Latch [don't use for debugging]
	assign pin8 = row_latch;
	// #OE
	assign pin9 = ~output_enable;
	// Pixel Clk
	assign pin10 = clk_pixel;
	//assign pin11 = 1'b1;
	// Red   1
	assign pin12 = rgb2[0];
	// Green 1 [don't use for debugging]
	assign pin13 = rgb2[1];
	// Blue  1

	assign pin18 = rgb2[2];


	// Red   2
	assign pin19 = rgb1[0];
	// Green 2
	assign pin20 = rgb1[1];
	// Blue  2
	assign pin21 = rgb1[2];
	//assign pin22 = 1'b1;
	assign pin23 = tx_out;
	assign debug_uart_rx = pin24;

endmodule