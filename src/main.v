module main (
    // DP74HC245 710401
    // FM TC7258E. 5B855300 2X
    // CHIPONE ICN2028BP A06631HA

    // lessons
    // 1. Ensure that all unused IO are set to no pullup
  output gp0,
  output gp1,
  output gp2,
  output gp3,
  output gp4,
  output gp5,
  output gp7,
  output gp8,
  output gp9,
  output gp10,
  output gp11,
  output gp12,
  output gp13,
  input gp14,
  input gp15,
  output gp16,
  input clk_25mhz,
  output gn0,
  output gn1,
  output gn2,
  output gn3,
  output gn4,
  output gn5,
  output gn7,
  output gn8,
  output gn9,
  output gn10,
  output gn11,
  output gn12,
  output gn13,
    output gn14,
    output gn15,
    output gn16,
    output gn17,
    output gn18
);
// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
parameter CTRLR_CLK_TICKS_PER_BIT = 7'd65;
parameter CTRLR_CLK_TICKS_WIDTH = 3'd7;

// context: TX DEBUG baud
// 16000000hz / 115200hz = 138.8889 ticks width=8
// tgt_hz variation (after rounding): -0.08%
// 16000000hz / 115108hz = 139 ticks width=8
parameter DEBUG_TX_UART_TICKS_PER_BIT = 8'd139;
parameter DEBUG_TX_UART_TICKS_PER_BIT_WIDTH = 4'd8;

// context: Debug msg rate
// 16000000hz / 22hz = 727272.7273 ticks width=20
// tgt_hz variation (after rounding): -0.00%
// 16000000hz / 22hz = 727273 ticks width=20
parameter DEBUG_MSGS_PER_SEC_TICKS = 20'd727273;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH = 5'd20;

`ifdef SIM
// use smaller value in testbench so we don't infinitely sim
parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM = 3'd4;


// period = (1 / 16000000hz) / 2 = 31.25000
parameter SIM_HALF_PERIOD_NS = 31.25000;
`endif

    wire clk_root;
    wire clk_matrix;

    wire global_reset;
    reg global_reset_init;
    reg global_reset_debug;
    wire init_reset_strobe;
    wire buffered_global_reset;

    wire clk_pixel_load;
    wire clk_pixel;
    wire clk_pixel_load_en;
    wire [3:0] pixel_load_counter2;

    wire row_latch;
    wire row_latch_intermediary;
`ifndef USE_FM6126A
    wire [1:0] row_latch_state;
`else
    // TODO: Need to update bytes in python script and wire below.
    wire fm6126mask_en;
    wire [3:0] row_latch_state;
`endif

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
    wire debug_uart_tx;

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

    wire clk_pixel_intermediary;

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
        };

    // No wires past here

    pll new_pll_inst (
        .clock_in(clk_25mhz),
        .clock_out(clk_root)
    );

    reg [5:0] reset_cnt;
    reg last_init_enable;
    initial begin
        reset_cnt <= 6'b100111;
        last_init_enable <= 2'b0;
    end

    wire init_enable;
    assign init_enable = &reset_cnt;
    always @(posedge clk_root) begin
            reset_cnt <= reset_cnt + !init_enable;
    end

    wire init_trigger = last_init_enable ^ init_enable;

    always @(posedge clk_matrix) begin
        last_init_enable <= init_enable;
    end

`ifdef USE_FM6126A
    wire [2:0] rgb1_fm6126init;
    wire [2:0] rgb2_fm6126init;
    wire row_latch_fm6126init;
    wire pixclock_fm6126init;
fm6126init do_init (
    .clk_in(clk_matrix),
    .reset(init_trigger),
    .rgb1_out(rgb1_fm6126init),
    .rgb2_out(rgb2_fm6126init),
    .latch_out(row_latch_fm6126init),
    .mask_en(fm6126mask_en),
    .pixclock_out(pixclock_fm6126init),
    .reset_notify(init_reset_strobe)
);
    assign output_enable = output_enable_intermediary & fm6126mask_en;
    assign rgb1[0] = (rgb1_intermediary[0] & fm6126mask_en) | (rgb1_fm6126init[0] & ~fm6126mask_en);
    assign rgb1[1] = (rgb1_intermediary[1] & fm6126mask_en) | (rgb1_fm6126init[1] & ~fm6126mask_en);
    assign rgb1[2] = (rgb1_intermediary[2] & fm6126mask_en) | (rgb1_fm6126init[2] & ~fm6126mask_en);
    assign rgb2[0] = (rgb2_intermediary[0] & fm6126mask_en) | (rgb2_fm6126init[0] & ~fm6126mask_en);
    assign rgb2[1] = (rgb2_intermediary[1] & fm6126mask_en) | (rgb2_fm6126init[1] & ~fm6126mask_en);
    assign rgb2[2] = (rgb2_intermediary[2] & fm6126mask_en) | (rgb2_fm6126init[2] & ~fm6126mask_en);
    assign row_latch = (row_latch_intermediary & fm6126mask_en) | (row_latch_fm6126init & ~fm6126mask_en);
    assign clk_pixel = (clk_pixel_intermediary & fm6126mask_en) | (pixclock_fm6126init & ~fm6126mask_en);
`else
    assign output_enable = output_enable_intermediary;
    assign rgb1[0] = rgb1_intermediary[0];
    assign rgb1[1] = rgb1_intermediary[1];
    assign rgb1[2] = rgb1_intermediary[2];
    assign rgb2[0] = rgb2_intermediary[0];
    assign rgb2[1] = rgb2_intermediary[1];
    assign rgb2[2] = rgb2_intermediary[2];
    assign row_latch = row_latch_intermediary;
    assign clk_pixel = clk_pixel_intermediary;
`endif

    wire alt_reset;
    reset_on_start #() RoS_obj (
        .clock_in(clk_root),
        .reset(alt_reset)
    );

    timeout #(
        .COUNTER_WIDTH(1)
    ) timeout_global_reset (
        .reset(global_reset),
        .clk_in(clk_root),
        .start(~((debug_command == "H") && debug_command_pulse)),
        .value(1'd2),
        .counter(),
        .running(buffered_global_reset)
    );

    /* produce a clock for use on the LED matrix */
    reg [1:0] sync_fifo;
    // this is a buffer to transfer global reset across clock domains
    always @(posedge clk_root) begin
            { global_reset_debug, sync_fifo } <= { sync_fifo, buffered_global_reset };
    end

    assign global_reset = alt_reset || (global_reset_debug & ~buffered_global_reset);
    /* produce signals to scan a 64x32 LED matrix, with 6-bit color */
    clock_divider #(
        .CLK_DIV_COUNT(2'd3),
        .CLK_DIV_WIDTH(2'd3)
    ) clkdiv_baudrate (
        .reset(global_reset),
        .clk_in(clk_root),
        .clk_out(clk_matrix)
    );

    matrix_scan matscan1 (
        .reset(global_reset),
        .clk_in(clk_matrix),
        .column_address(column_address),
        .row_address(row_address),
        .row_address_active(row_address_active),
        .clk_pixel_load(clk_pixel_load),
        .clk_pixel(clk_pixel_intermediary),
        .row_latch(row_latch_intermediary),
        .output_enable(output_enable_intermediary),
        .brightness_mask(brightness_mask),
        .state_advance2(state_advance),
        .row_latch_state2(row_latch_state),
        .clk_pixel_load_en2(clk_pixel_load_en)
    );

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
    );

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
    );

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
    );

    /* split the pixels and get the current brightness' bit */
    pixel_split px_top (
        .pixel_rgb565(pixel_rgb565_top),
        .brightness_mask(brightness_mask & brightness_enable),
        .rgb_enable(rgb_enable),
        .rgb_output(rgb1_intermediary)
    );
    pixel_split px_bottom (
        .pixel_rgb565(pixel_rgb565_bottom),
        .brightness_mask(brightness_mask & brightness_enable),
        .rgb_enable(rgb_enable),
        .rgb_output(rgb2_intermediary)
    );

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
        .tx_out(debug_uart_tx)
    );

    assign gp11 = clk_pixel; // Pixel Clk
    assign gp12 = row_latch; // Row Latch
    assign gp13 = ~output_enable; // #OE
    assign gp7 = row_address_active[0]; // A / Row[0]
    assign gp8 = row_address_active[1]; // B / Row[1]
    assign gp9 = row_address_active[2]; // C / Row[2]
    assign gp10 = row_address_active[3]; // D / Row[3]
    assign gp0 = rgb1[0]; // Red   1
    assign gp1 = rgb1[1]; // Green 1
    assign gp2 = rgb1[2]; // Blue  1
    assign gp3 = rgb2[0]; // Red   2
    assign gp4 = rgb2[1]; // Green 2
    assign gp5 = rgb2[2]; // Blue  2

    assign uart_rx = gp14;
    assign gp16 = debug_uart_tx;
    assign debug_uart_rx = gp15;

    assign gn11 = clk_pixel; // Pixel Clk
    assign gn12 = row_latch; // Row Latch
    assign gn13 = ~output_enable; // #OE
    assign gn7 = row_address_active[0]; // A / Row[0]
    assign gn8 = row_address_active[1]; // B / Row[1]
    assign gn9 = row_address_active[2]; // C / Row[2]
    assign gn10 = row_address_active[3]; // D / Row[3]
    assign gn0 = rgb1[0]; // Red   1
    assign gn1 = rgb1[1]; // Green 1
    assign gn2 = rgb1[2]; // Blue  1
    assign gn3 = rgb2[0]; // Red   2
    assign gn4 = rgb2[1]; // Green 2
    assign gn5 = rgb2[2]; // Blue  2
    assign gn14 = clk_matrix;
    assign gn15 = gp14;
    assign gn16 = clk_root; // 6
    assign gn17 = clk_root; // T1
endmodule