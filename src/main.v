//`include "/home/awhite/lscc/iCEcube2.2017.08/synpbase/lib/syncore/models/memories/ram/syncore_ram.v"
module main (
//while true; do for each in `seq -s " " -f %02g 0 31`; do echo L${each}11223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788 > /dev/ttyAMA0; done; done
	// DP74HC245 710401
	// FM TC7258E. 5B855300 2X
	// CHIPONE ICN2028BP A06631HA

	// lessons
	// 1. Ensure that all unused IO are set to no pullup

  inout pin1_usb_dp,
  inout pin2_usb_dn,
  input pin3_clk_16mhz,
  output pin3,
  output pin4,
  output pin5,
  output pin6,
  input pin7,
  output pin8,
  output pin9,
  output pin10,
  output pin11,
  output pin12,
  output pin13,
  inout pin14_sdo,
  inout pin15_sdi,
  inout pin16_sck,
  inout pin17_ss,
  output pin18,
  output pin19,
  output pin20,
  output pin21,
  output pin22,
  output pin23,
  input pin24,
  inout pinLED
//  output pin_usb_pu
);

	reg global_reset;

	//wire clk_root;
	wire clk_matrix;
	wire clk_pixel_load;
	wire clk_pixel;

	wire row_latch;

	wire [7:0] ram_a_data_in;
	wire [7:0] ram_a_data_out;
	wire [11:0] ram_a_address;
	wire ram_a_write_enable;
	wire ram_a_clk_enable;
	wire ram_a_reset;

	wire [15:0] ram_b_data_out;
	wire [10:0] ram_b_address;
	wire ram_b_clk_enable;
	wire ram_b_reset;

	wire [15:0] pixel_rgb565_top;
	wire [15:0] pixel_rgb565_bottom;

	wire uart_rx;
	wire debug_uart_rx;

	wire [5:0] column_address;
	wire [3:0] row_address;
	wire [3:0] row_address_active;
	wire [5:0] brightness_mask;

	wire [2:0] rgb_enable;
	wire [5:0] brightness_enable;
	wire [2:0] rgb1; /* the current RGB value for the top-half of the display */
	wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */
	wire [1:0] cmd_line_state;
	wire [7:0] uart_rx_data;
	wire ram_access_start;
	wire ram_access_start_latch;
	wire state_advance;
	wire [1:0] row_latch_state;
	wire clk_pixel_load_en;
	wire rx_running;
	wire [11:0] cmd_line_addr2;
	wire [3:0] pixel_load_counter2;
	wire [7:0] debug_command;
	wire debug_command_pulse;
    wire debug_command_busy;
  // Fin=12, Fout=133 (cct 132);
	// Fin=16 Fout=132
	//defparam usb_pll_inst.DIVR = 0;
	//defparam usb_pll_inst.DIVF = 7'b1000001;
	//defparam usb_pll_inst.DIVQ = 3'b011;
	// Fin=16 Fout=144
	/*
	defparam usb_pll_inst.DIVR = 0;
	defparam usb_pll_inst.DIVF = 7'b1000010;
	defparam usb_pll_inst.DIVQ = 3'b011;
	*/
	//Fin=16 Fout=132
	defparam usb_pll_inst.DIVR = 0;
	defparam usb_pll_inst.DIVF = 7'b1000001;
	defparam usb_pll_inst.DIVQ = 3'b011;

	wire clk_root_logic;

  SB_PLL40_CORE usb_pll_inst (
    .REFERENCECLK(pin3_clk_16mhz),
    .PLLOUTGLOBAL(clk_root_logic),
    .RESETB(1'b1),
    .BYPASS(1'b0),
	.EXTFEEDBACK(1'bz),
	.SDI(1'bz),
	.SCLK(1'bz),
	.LATCHINPUTVALUE(1'bz),
  	.DYNAMICDELAY(8'bz)
) /* synthesis syn_noprune=1 */ ;
	wire clk_root;
	//assign clk_root = clk_root_logic;
	//assign clk_root = ((debug_command == "S") && ~debug_command_pulse) ? 1'bz : clk_root_logic;


	SB_GB gbc(
		.USER_SIGNAL_TO_GLOBAL_BUFFER (clk_root_logic),
		.GLOBAL_BUFFER_OUTPUT ( clk_root ) ) /* synthesis syn_noprune=1 */ ;


	defparam usb_pll_inst.FILTER_RANGE = 3'b001;
	defparam usb_pll_inst.FEEDBACK_PATH = "SIMPLE";

	defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
	defparam usb_pll_inst.FDA_FEEDBACK = 4'b0000;
	defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
	defparam usb_pll_inst.FDA_RELATIVE = 4'b0000;
	defparam usb_pll_inst.SHIFTREG_DIV_MODE = 2'b00;
	defparam usb_pll_inst.PLLOUT_SELECT = "GENCLK";
  //defparam usb_pll_inst.ENABLE_ICEGATE = 1'b0;

	wire buffered_global_reset;
	timeout #(
		.COUNTER_WIDTH(4)
	) timeout_global_reset (
		.reset(1'b0),
		//.reset(debug_command == "H"),
		.clk_in(clk_root_logic),
		//.start(1'b1),
		.start(~((debug_command == "H") && debug_command_pulse)),
		.value(4'd15),
		.counter(),
		.running(buffered_global_reset)
	) /* synthesis syn_noprune=1 */;

	/* produce a clock for use on the LED matrix */
	reg [1:0] sync_fifo;
	always @(posedge clk_root_logic) begin
			{ global_reset, sync_fifo } <= { sync_fifo, buffered_global_reset };

	//always @(posedge clk_root_logic)

	end

	clock_divider #(
		.CLK_DIV_WIDTH(2),
		.CLK_DIV_COUNT(3)
	) clkdiv_matrix (
		.reset(global_reset),
		.clk_in(clk_root),
		.clk_out(clk_matrix)
	) /* synthesis syn_noprune=1 */ ;

	// yields 133MHZ/3 = 44.333MHz
	//        main.v     clk_matrix

	/* produce signals to scan a 64x32 LED matrix, with 6-bit color */

	matrix_scan matscan1 (
		.reset(global_reset),
		.clk_in(clk_matrix),
		.column_address(column_address),
		.row_address(row_address),
		.row_address_active(row_address_active),
		.clk_pixel_load(clk_pixel_load),
		.clk_pixel(clk_pixel),
		.row_latch(row_latch),
		.output_enable(output_enable),
		.brightness_mask(brightness_mask),

		.row_latch2(row_latch),
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
	control_module ctrl (
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
		.cmd_line_addr2(cmd_line_addr2)

	) /* synthesis syn_noprune=1 */ ;

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
	) /* synthesis syn_noprune=1 */ ;

	/* split the pixels and get the current brightness' bit */
	pixel_split px_top (
		.pixel_rgb565(pixel_rgb565_top),
		.brightness_mask(brightness_mask & brightness_enable),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb1)
	) /* synthesis syn_noprune=1 */ ;
	pixel_split px_bottom (
		.pixel_rgb565(pixel_rgb565_bottom),
		.brightness_mask(brightness_mask & brightness_enable),
		.rgb_enable(rgb_enable),
		.rgb_output(rgb2)
	) /* synthesis syn_noprune=1 */ ;

	wire tx_out;

	wire [183:0] ddata =  {
		//
		3'bz,
		//								181
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

	debugger #(
		.DIVIDER_TICKS_WIDTH(25),
		.DIVIDER_TICKS(6000000),
		.DATA_WIDTH_BASE2(8),
		.DATA_WIDTH(184)
	//.DATA_WIDTH_BASE2($clog2($size(ddata))),
		//.DATA_WIDTH($size(ddata))
	) mydebug (
		.clk_in(clk_root_logic),
		.reset(global_reset),
		.data_in(ddata),
		.debug_uart_rx_in(debug_uart_rx),
		.debug_command(debug_command),
		.debug_command_pulse(debug_command_pulse),
		.debug_command_busy(debug_command_busy),
		.tx_out(tx_out)
	);

	/* use this signal for insight! */

	assign pin1_usb_dp = 1'b1;
	assign pin2_usb_dn = 1'b1;
	// A/ Row[0]
	assign pin3 = row_address_active[0];
	// B / Row[1]
	assign pin4 = row_address_active[1];
	// C / Row[2]
	assign pin5 = row_address_active[2];
	// D / Row[3]
	assign pin6 = row_address_active[3];
	// Uart Rx
	//assign pin7 = 1'bz;
	assign uart_rx = pin7;
	// Debug LED
	//assign pinLED = ~debug;
	// Row Latch [don't use for debugging]
	assign pin8 = row_latch;
	// #OE
	assign pin9 = ~output_enable;
	// Pixel Clk
	assign pin10 = clk_pixel;
	//assign pin11 = ram_a_clk_enable;
	assign pin11 = ram_a_clk_enable;
	// Red   1
	assign pin12 = rgb2[0];
	// Green 1 [don't use for debugging]
	assign pin13 = rgb2[1];
	// Blue  1
	// 14,15,16,17 ==> JTAG

	assign pin14_sdo = 1'b1;
	assign pin15_sdi = 1'b1;
	assign pin16_sck = 1'b1;
	assign pin17_ss = 1'b1;
	assign pinLED = 1'b1;

	assign pin18 = rgb2[2];


	// Red   2
	assign pin19 = rgb1[0];
	// Green 2
	assign pin20 = rgb1[1];
	// Blue  2
	assign pin21 = rgb1[2];
	assign pin22 = ram_b_clk_enable;
	assign pin23 = tx_out;
	//assign pin24 = 1'bz;
	assign debug_uart_rx = pin24;


/*
	assign pin1_usb_dp = 1'b1;
	assign pin2_usb_dn = 1'b1;
	// A/ Row[0]
	assign pin3 = uart_rx_data[0];
	// B / Row[1]
	assign pin4 = uart_rx_data[1];
	// C / Row[2]
	assign pin5 = uart_rx_data[2];
	// D / Row[3]
	assign pin6 = uart_rx_data[3];
	// Uart Rx
	assign pin7 = 1'bz; assign uart_rx = pin7;
	// Debug LED
	//assign pinLED = ~debug;
	// Row Latch [don't use for debugging]
	assign pin8 = uart_rx_data[4];
	// #OE
	assign pin9 = uart_rx_data[5];
	// Pixel Clk
	assign pin10 = uart_rx_data[6];
	assign pin11 = 1'b1;
	// Red   1
	assign pin12 = uart_rx_data[7];
	// Green 1 [don't use for debugging]
	assign pin13 = rx_running2;
	// Blue  1
	// 14,15,16,17 ==> JTAG

	assign pin14_sdo = 1'b1;
	assign pin15_sdi = 1'b1;
	assign pin16_sck = 1'b1;
	assign pin17_ss = 1'b1;
	assign pinLED = 1'b1;

	assign pin18 = rx_invalid;


	// Red   2
	assign pin19 = uartclk;
	// Green 2
	assign pin20 = cmd_line_state[0];
	// Blue  2
	assign pin21 = cmd_line_state[1];
	assign pin22 = 1'b1;
	assign pin23 = tx_out;
	assign pin24 = 1'bz; assign debug_uart_rx = pin24;
*/
endmodule