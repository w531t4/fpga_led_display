module control_module #(
	/* UART configuration */
	//parameter UART_CLK_DIV_COUNT = 30, /* 7 MHz in / 60 = ~115,200 baud (actually ~116,686 baud, +1.29%) */
	//parameter UART_CLK_DIV_COUNT = 231, /* 53.2 MHz in / 462 = ~115,200 baud (actually ~115,151 baud, -0.04%) */
	//parameter UART_CLK_DIV_COUNT = 10, /* 53.2 MHz in / 21 = ~2.5 Mbaud (actually 2.66 Mbaud) */
	parameter UART_CLK_DIV_COUNT = 25, /* 133 MHz in / 50 = ~2.5 Mbaud (actually 2.66 Mbaud) */
	// @25, 2.65Mhz
	// @25 2627450
	// 3/24 - saw uart clk at 2.684MHz
	//paameter UART_CLK_DIV_COUNT = 25,
						/* == 5.32MHz */
	parameter UART_CLK_DIV_WIDTH = 8
) (
	input reset,
	input clk_in, /* clk_root =  133MHZ */

	input uart_rx,
	output rx_running,

	output reg [2:0] rgb_enable = 3'b111,
	output reg [5:0] brightness_enable = 6'b111111,

	output reg [7:0] ram_data_out,
	output reg [11:0] ram_address,
	output reg ram_write_enable,
	output ram_clk_enable /* synthesis syn_preserve = 1 */,
	output ram_reset,
	output [1:0] cmd_line_state2,
	output [7:0] rx_data,
	output ram_access_start2,
	output ram_access_start_latch2,
	output [11:0] cmd_line_addr2

);

	wire [7:0] uart_rx_data;
	wire uart_rx_running;
	wire ram_clk_enable_real /* synthesis syn_noprune=1 syn_preserve=1 */;
	assign cmd_line_state2[1:0] = cmd_line_state[1:0];
	//assign rx_data[7:0] = uart_rx_data[7:0];

	reg ram_access_start = 1'b0 /* synthesis syn_noprune=1 syn_preserve=1 */;
	reg ram_access_start_latch = 1'b0 /* synthesis syn_noprune=1 syn_preserve=1 */;
	assign ram_access_start2 = ram_access_start;
	assign ram_access_start_latch2 = ram_access_start_latch;
	assign ram_reset = reset;
	reg  [1:0]  cmd_line_state = 2'b0;
	reg  [4:0]  cmd_line_addr_row = 5'd0;
	reg  [7:0]  cmd_line_addr_col = 7'd0 /* synthesis syn_preserve=1 */ ; // why is this written as 8 bits?
	wire [11:0] cmd_line_addr = { cmd_line_addr_row[4:0], ~cmd_line_addr_col[6:1], cmd_line_addr_col[0] };

	assign cmd_line_addr2 = cmd_line_addr[11:0];

	wire uart_rx_dataready;
	debug_uart_rx #(
		.TICKS_PER_BIT(6'd49),
		.TICKS_PER_BIT_SIZE(6)
	) mycontrol_rxuart (
	.reset(reset),
	.i_clk(clk_in),
	.i_enable(1'b1),
	.i_din_priortobuffer(uart_rx),
	.o_rxdata(uart_rx_data),
	.o_recvdata(uart_rx_dataready),
	.o_busy(uart_rx_running)
	) /* synthesis syn_noprune=1 */;

	/*
	uart_rx #(
		.CLK_DIV_COUNT(UART_CLK_DIV_COUNT),
		.CLK_DIV_WIDTH(UART_CLK_DIV_WIDTH)
	) urx (
		.reset(reset),
		.clk_in(clk_in),
		// in DIV_COUNT=25 DIV_WIDTH=8 clk_in=133MHz //
		.rx_line(uart_rx),
		//.rx_line_beforesync(uart_rx),
		.rx_data(uart_rx_data),
		.rx_running(uart_rx_running),
		.rx_invalid(uart_rx_invalid),

        .uartclk(test),
		.clkdiv_baudrate_reset2(clkdiv_baudrate_reset),
		.timeout_word_start2(timeout_word_start),
		.rx_running2(out_rx_running2)
	) // synthesis syn_noprune=1 // ;
*/
	// ^ is exclusive or
	timeout #(
		.COUNTER_WIDTH(2)
	) timeout_cmd_line_write (
		.reset(reset),
		.clk_in(~clk_in),
		.start(ram_access_start ^ ram_access_start_latch),
		.value(2'b10),
		.counter(),
		.running(ram_clk_enable_real)
	) /* synthesis syn_noprune=1 syn_preserve=1  */ ;
	assign ram_clk_enable = ram_clk_enable_real;
	assign rx_running = uart_rx_running;
	assign rx_data[7:0] = uart_rx_data[7:0];

	always @(posedge clk_in, posedge reset) begin
		if (reset) begin
			ram_access_start_latch <= 1'b0;
		end
		else begin
			if (ram_clk_enable_real) begin
				ram_access_start_latch <= ram_access_start;
			end
			else begin
			end
		end
	end

	always @(negedge uart_rx_running, posedge reset) begin
	//always @(negedge do_read, posedge reset) begin

		if (reset) begin
			rgb_enable <= 3'b111;
			brightness_enable <= 6'b111111;

			ram_data_out <= 8'd0;
			ram_address <= 12'd0;
			ram_write_enable <= 1'b0;
			ram_access_start <= 1'b0;

			cmd_line_state <= 2'd0;
			cmd_line_addr_row <= 5'd0;
			cmd_line_addr_col <= 8'd0;
		end


		/* CMD: Line */
		else if (cmd_line_state == 2'd2 && uart_rx_data != "L" ) begin
			/* first, get the row to write to */
			cmd_line_addr_row[4:0] <= uart_rx_data[4:0];

			/* and start clocking in the column data
			   64 pixels x 2 bytes each = 128 bytes */
			cmd_line_addr_col[7:0] <= 8'd127;
			cmd_line_state <= 2'd1;
		end
		else if (cmd_line_state == 2'd1) begin
			/* decrement the column address (or finish the load) */
			if (cmd_line_addr_col != 'd0) begin
				cmd_line_addr_col <= cmd_line_addr_col - 'd1;
			end
			else begin
				cmd_line_state <= 2'd0;
			end

			/* store this byte */
			ram_data_out <= uart_rx_data[7:0];
			ram_address <= cmd_line_addr;
			ram_write_enable <= 1'b1;
			ram_access_start <= !ram_access_start;
		end

		/* CMD: Main */
		else if (cmd_line_state != 2'd2 && !uart_rx_running) begin
		//else if (!uart_rx_invalid) begin
			//2650000
			case (uart_rx_data)
				"R": begin
					rgb_enable[0] <= 1'b1;
				end
				"r": begin
					rgb_enable[0] <= 1'b0;
				end
				"G": begin
					rgb_enable[1] <= 1'b1;
				end
				"g": begin
					rgb_enable[1] <= 1'b0;
				end
				"B": begin
					rgb_enable[2] <= 1'b1;
				end
				"b": begin
					rgb_enable[2] <= 1'b0;
				end

				"1": begin
					brightness_enable[5] <= ~brightness_enable[5];
				end
				"2": begin
					brightness_enable[4] <= ~brightness_enable[4];
				end
				"3": begin
					brightness_enable[3] <= ~brightness_enable[3];
				end
				"4":begin
					brightness_enable[2] <= ~brightness_enable[2];
				end
				"5": begin
					brightness_enable[1] <= ~brightness_enable[1];
				end
				"6": begin
					brightness_enable[0] <= ~brightness_enable[0];
				end

				"0": begin
					brightness_enable <= 6'b000000;
				end
				"9": begin
					brightness_enable <= 6'b111111;
				end

				"L": begin
					cmd_line_state <= 2'd2;
				end
				default: begin
					cmd_line_state <= 2'd0;
				end
			endcase
		end
	end
endmodule