// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module main #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params::PIXEL_HALFHEIGHT,
    parameter integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS,
    parameter integer unsigned DIVIDE_CLK_BY_X_FOR_MATRIX = params::DIVIDE_CLK_BY_X_FOR_MATRIX,
    parameter integer unsigned PLL_SPEED = params::PLL_SPEED,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned CTRLR_CLK_TICKS_PER_BIT = params::CTRLR_CLK_TICKS_PER_BIT,
    parameter integer unsigned DEBUG_MSGS_PER_SEC_TICKS = params::DEBUG_MSGS_PER_SEC_TICKS,
    parameter integer unsigned DEBUG_TX_UART_TICKS_PER_BIT = params::DEBUG_TX_UART_TICKS_PER_BIT,
    parameter integer unsigned WATCHDOG_SIGNATURE_BITS = params::WATCHDOG_SIGNATURE_BITS,
    parameter logic [WATCHDOG_SIGNATURE_BITS-1:0] WATCHDOG_SIGNATURE_PATTERN = params::WATCHDOG_SIGNATURE_PATTERN,
    parameter int unsigned WATCHDOG_CONTROL_TICKS = params::WATCHDOG_CONTROL_TICKS,
    parameter integer BRIGHTNESS_BASE_TIMEOUT = params::BRIGHTNESS_BASE_TIMEOUT,
    parameter integer BRIGHTNESS_STATE_TIMEOUT_OVERLAP = params::BRIGHTNESS_STATE_TIMEOUT_OVERLAP,
    // verilator lint_on UNUSEDPARAM
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // DP74HC245 710401
    // FM TC7258E. 5B855300 2X
    // CHIPONE ICN2028BP A06631HA

    // lessons
    // 1. Ensure that all unused IO are set to no pullup
`ifdef USE_BOARDLEDS_BRIGHTNESS
    output [7:0] led,
`endif
`ifdef SPI
`ifdef SPI_ESP32
    input  [3:0] sd_d,       // sd_d[0]=mosi
    input        sd_clk,     // clk
    input        sd_cmd,     // ce
`else
    input        gp17,       // miso
    //   output gp18, // mosi
    input        gp19,       // clk
    input        gp20,       // ce
`endif
`endif
    output       gp0,
    output       gp1,
    output       gp2,
    output       gp3,
    output       gp4,
    output       gp5,
    output       gp7,
    output       gp8,
    output       gp9,
    output       gp10,
    output       gp11,
    output       gp12,
    output       gp13,
    input        gp14,
    input        gp15,
    output       gp16,
    input        clk_25mhz,
    output       gn0,
    output       gn1,
    output       gn2,
    output       gn3,
    output       gn4,
    output       gn5,
    output       gn7,
    output       gn8,
    output       gn9,
    output       gn10,
    output       gn11,
    output       gn12,
    output       gn13,
    output       gn14
    // output gn15,
    // output gn16
);

    wire clk_root;
    wire clk_matrix;

    wire global_reset;
    logic global_reset_sync;

    wire clk_pixel_load;
    wire clk_pixel;
    wire row_latch;
    wire [7:0] ram_a_data_in;
    wire [7:0] ram_a_data_out_frame1;
    //  [11:0]
    wire types::mem_write_addr_t ram_a_address;
    wire ram_a_write_enable;
    wire ram_a_clk_enable;
    wire types::mem_read_data_t ram_b_data_out;
    wire types::mem_read_data_t ram_b_data_out_frame1;
`ifdef DOUBLE_BUFFER
    wire frame_select;
    wire [7:0] ram_a_data_out_frame2;
    wire types::mem_read_data_t ram_b_data_out_frame2;
`endif
    //  [10:0]
    wire types::mem_read_addr_t ram_b_address;
    wire ram_b_clk_enable;

    wire types::color_field_subpanel_t pixeldata_top;
    wire types::color_field_subpanel_t pixeldata_bottom;
    wire ctrl_busy;
    wire ctrl_ready_for_data;

`ifdef DEBUGGER
    // self
    localparam integer unsigned debug_data_width = 32;
    wire debugger_debug_start;
    wire [4:0] debugger_current_state;
    wire debugger_do_close;
    wire debugger_tx_start;
    wire [$clog2(debug_data_width)-1:0] debugger_current_position;
    // from controller
    wire [3:0] cmd_line_state2;
    wire ram_access_start;
    wire ram_access_start_latch;
    wire types::mem_write_addr_t cmd_line_addr2;
    wire [7:0] num_commands_processed;
    // end controller
    // from framebuffer_fetch
    wire [3:0] pixel_load_counter2;
    // end framebuffer_fetch
    // from matrix_scan
    wire state_advance;
    wire [1:0] row_latch_state;
    wire clk_pixel_load_en;
    wire matrix_row_latch2;
    // end matrix_scan
`endif

    // [5:0]
    wire types::col_addr_t column_address;
    wire [3:0] row_address;
    wire [3:0] row_address_active;
    wire types::brightness_level_t brightness_mask;

    wire [2:0] rgb_enable;
    wire types::brightness_level_t brightness_enable;
`ifdef USE_BOARDLEDS_BRIGHTNESS
    assign led = brightness_enable;
`endif
    wire [2:0] rgb1;  /* the current RGB value for the top-half of the display */

    wire [2:0] rgb2;  /* the current RGB value for the bottom-half of the display */


    wire output_enable;
    wire alt_reset;
    wire pll_locked;

    wire rxdata;
    wire rxdata_ready;
    wire rxdata_ready_level;
    wire rxdata_ready_pulse;
    wire [7:0] rxdata_to_controller;
`ifdef SPI
    wire spi_clk;
    wire spi_cs;
    wire spi_slave_sdout;
`else
    // uart rx for controller
    wire uart_rx_dataready;
`endif
`ifdef USE_WATCHDOG
    wire watchdog_reset;
`endif
    // No wires past here

    new_pll #(
        .SPEED(PLL_SPEED)
    ) new_pll_inst (
        .clock_in(clk_25mhz),
        .clock_out(clk_root),
        .locked(pll_locked)
    );

`ifdef USE_FM6126A
    wire [2:0] rgb1_fm6126init;
    wire [2:0] rgb2_fm6126init;
    wire row_latch_fm6126init;
    wire pixclock_fm6126init;
    wire output_enable_intermediary;
    wire [2:0] rgb2_intermediary;
    wire clk_pixel_intermediary;
    wire [2:0] rgb1_intermediary;
    wire row_latch_intermediary;
    wire init_reset_strobe;
    wire fm6126mask_en;
    fm6126init do_init (
        .clk_in(clk_matrix),
        .reset(alt_reset),
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
`endif

`ifdef DEBUGGER
    wire [7:0] debug_command;
    wire debug_command_pulse;
    wire debug_command_busy;
    wire debug_uart_tx;
    wire debug_uart_rx;
    wire [debug_data_width-1:0] ddata = {
        rxdata_to_controller[7:0],
        num_commands_processed[7:0],
        rgb_enable[2:0],
        cmd_line_state2[3:0],
        brightness_enable[7:0],
        2'b0
    };
`endif

    reset_on_start #() RoS_obj (
        .clock_in(clk_root),
        .reset(alt_reset)
    );
    // sd_d[1] was previously used as a way to reset the fpga, but has since been
    // retired in favor of the watchdog.
`ifdef USE_WATCHDOG
`ifdef SIM
    assign global_reset = alt_reset;
    wire _unused_watchdog_reset = &{1'b0, watchdog_reset, 1'b0};
`else
    assign global_reset = alt_reset | watchdog_reset;
`endif
`else
    assign global_reset = alt_reset;
`endif

    always_ff @(posedge clk_root) begin
        global_reset_sync <= global_reset;
    end

    /* produce signals to scan a 64x32 LED matrix, with 6-bit color */
    clock_divider #(
        .CLK_DIV_COUNT(DIVIDE_CLK_BY_X_FOR_MATRIX)
    ) clkdiv_baudrate (
        .reset  (global_reset_sync),
        .clk_in (clk_root),
        .clk_out(clk_matrix)
    );

    matrix_scan #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .BRIGHTNESS_BASE_TIMEOUT(BRIGHTNESS_BASE_TIMEOUT),
        .BRIGHTNESS_STATE_TIMEOUT_OVERLAP(BRIGHTNESS_STATE_TIMEOUT_OVERLAP),
        ._UNUSED('d0)
    ) matscan1 (
        .reset(global_reset_sync),
        .clk_in(clk_matrix),
        .column_address(column_address),
        .row_address(row_address),
        .row_address_active(row_address_active),
        .clk_pixel_load(clk_pixel_load),
`ifdef USE_FM6126A
        .clk_pixel(clk_pixel_intermediary),
        .row_latch(row_latch_intermediary),
        .output_enable(output_enable_intermediary),
`else
        .clk_pixel(clk_pixel),
        .row_latch(row_latch),
        .output_enable(output_enable),
`endif
        .brightness_mask(brightness_mask)
`ifdef DEBUGGER,
        .state_advance2(state_advance),
        .row_latch_state2(row_latch_state),
        .clk_pixel_load_en2(clk_pixel_load_en),
        .row_latch2(matrix_row_latch2)
`endif
    );

    /* the fetch controller */

    framebuffer_fetch #(
        ._UNUSED('d0)
    ) fb_f (
        .reset (global_reset_sync),
        .clk_in(clk_root),

        .column_address(column_address),
        .row_address(row_address),
        .pixel_load_start(clk_pixel_load),

        .ram_data_in(ram_b_data_out),
        .ram_address(ram_b_address),
        .ram_clk_enable(ram_b_clk_enable),

        .pixeldata_top(pixeldata_top),
        .pixeldata_bottom(pixeldata_bottom)
`ifdef DEBUGGER,
        .pixel_load_counter2(pixel_load_counter2)
`endif
    );

    // for controller
`ifdef SPI
    spi_slave spislave (
        .rstb (~global_reset),
        .ten  (1'b0),                 // transmit enable, 0 = disabled
        .tdata(8'b0),
        .mlb  (1'b1),                 // shift msb first
        .ss   (spi_cs),
        .sck  (spi_clk),
        .sdin (rxdata),               // data coming from master
        .sdout(spi_slave_sdout),
        .done (rxdata_ready),         // data ready
        .rdata(rxdata_to_controller)  // data
    );
`else
    uart_rx #(
        // we want 22MHz / 2,430,000 = 9.0534
        // 22MHz / 9 = 2,444,444 baud 2444444
        .TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
    ) mycontrol_rxuart (
        .reset(global_reset),
        .i_clk(clk_root),
        .i_enable(1'b1),
        .i_din_priortobuffer(rxdata),
        .o_rxdata(rxdata_to_controller),
        .o_recvdata(uart_rx_dataready),
        .o_busy(rxdata_ready)
    );
`endif

    // bring uart-data into main clock domain
    ff_sync #() uart_sync (
        .clk(clk_root),
        .signal(rxdata_ready),
        .sync_level(rxdata_ready_level),
        .sync_pulse(rxdata_ready_pulse),
        .reset(global_reset)
    );

    /* the control module */
    control_module #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .WATCHDOG_SIGNATURE_BITS(WATCHDOG_SIGNATURE_BITS),
        .WATCHDOG_SIGNATURE_PATTERN(WATCHDOG_SIGNATURE_PATTERN),
        .WATCHDOG_CONTROL_TICKS(WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) ctrl (
        .reset(global_reset),
        .clk_in(clk_root),
        /* clk_root =  133MHZ */
        .data_rx(rxdata_to_controller),
`ifdef SPI
        .data_ready_n(~rxdata_ready_pulse),
`else
        .data_ready_n(rxdata_ready_pulse),
`endif
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        .busy(ctrl_busy),
        .ready_for_data(ctrl_ready_for_data),
        .ram_data_out(ram_a_data_in),
        .ram_address(ram_a_address),
        .ram_write_enable(ram_a_write_enable),
`ifdef DOUBLE_BUFFER
        .frame_select(frame_select),
`endif
`ifdef USE_WATCHDOG
        .watchdog_reset(watchdog_reset),
`endif
        .ram_clk_enable(ram_a_clk_enable)
`ifdef DEBUGGER,
        .cmd_line_state2(cmd_line_state2),
        .ram_access_start2(ram_access_start),
        .ram_access_start_latch2(ram_access_start_latch),
        .cmd_line_addr2(cmd_line_addr2),
        .num_commands_processed(num_commands_processed)
`endif
    );

    multimem #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        ._UNUSED('d0)
    ) fb (
        .ClockA(clk_root),
        .AddressA(ram_a_address),
        .DataInA(ram_a_data_in),
`ifdef DOUBLE_BUFFER
        .WrA(ram_a_write_enable & frame_select),
`else
        .WrA(ram_a_write_enable),
`endif
        .ResetA(global_reset_sync),
        .ClockB(clk_root),
        .DataInB(16'b0),
        .AddressB(ram_b_address),
        .WrB(1'b0),
        .ResetB(global_reset_sync),
        .QA(ram_a_data_out_frame1),
        .QB(ram_b_data_out_frame1),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable)
    );
`ifdef DOUBLE_BUFFER
    multimem #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        ._UNUSED('d0)
    ) fb2 (
        .ClockA(clk_root),
        .AddressA(ram_a_address),
        .DataInA(ram_a_data_in),
        .WrA(ram_a_write_enable & ~frame_select),
        .ResetA(global_reset_sync),
        .ClockB(clk_root),
        .DataInB(16'b0),
        .AddressB(ram_b_address),
        .WrB(1'b0),
        .ResetB(global_reset_sync),
        .QA(ram_a_data_out_frame2),
        .QB(ram_b_data_out_frame2),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable)
    );
    assign ram_b_data_out = frame_select ? ram_b_data_out_frame2 : ram_b_data_out_frame1;
`else
    assign ram_b_data_out = ram_b_data_out_frame1;
`endif
    /* split the pixels and get the current brightness' bit */
    pixel_split #(
        ._UNUSED('d0)
    ) px_top (
        .pixel_data(pixeldata_top),
        .brightness_mask(brightness_mask),
        .brightness_enable(brightness_enable),
        .rgb_enable(rgb_enable),
`ifdef USE_FM6126A
        .rgb_output(rgb1_intermediary)
`else
        .rgb_output(rgb1)
`endif
    );
    pixel_split #(
        ._UNUSED('d0)
    ) px_bottom (
        .pixel_data(pixeldata_bottom),
        .brightness_mask(brightness_mask),
        .brightness_enable(brightness_enable),
        .rgb_enable(rgb_enable),
`ifdef USE_FM6126A
        .rgb_output(rgb2_intermediary)
`else
        .rgb_output(rgb2)
`endif
    );

`ifdef DEBUGGER
    debugger #(
        // Describes the sample rate of messages sent to debugger client
        .DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS),
        .DATA_WIDTH(debug_data_width),
        // Describes the baudrate for sending messages to debugger client
        .UART_TICKS_PER_BIT(DEBUG_TX_UART_TICKS_PER_BIT)
    ) mydebug (
        .clk_in(clk_root),
        .reset(global_reset),
        .data_in(ddata),
        .debug_uart_rx_in(debug_uart_rx),
        .debug_command(debug_command),
        .debug_command_pulse(debug_command_pulse),
        .debug_command_busy(debug_command_busy),
        .debug_start(debugger_debug_start),
        .currentState(debugger_current_state),
        .do_close(debugger_do_close),
        .tx_start(debugger_tx_start),
        .current_position(debugger_current_position),
        .tx_out(debug_uart_tx)
    );
    assign gp16 = debug_uart_tx;
    assign debug_uart_rx = gp15;
`else
    assign gp16 = 1'b0;
`endif

    assign gp0  = rgb1[0];  // Red   1
    assign gp1  = rgb1[2];  // Green 1 // switched with blue for my display
    assign gp2  = rgb1[1];  // Blue  1 // switched with green for my display
    assign gp3  = rgb2[0];  // Red   2
    assign gp4  = rgb2[2];  // Green 2 // switched with blue for my display
    assign gp5  = rgb2[1];  // Blue  2 // switched with green for my display
    assign gp11 = clk_pixel;  // Pixel Clk
    assign gp12 = row_latch;  // Row Latch
    assign gp13 = ~output_enable;  // #OE
    assign gp7  = row_address_active[0];  // A / Row[0]
    assign gp8  = row_address_active[1];  // B / Row[1]
    assign gp9  = row_address_active[2];  // C / Row[2]
    assign gp10 = row_address_active[3];  // D / Row[3]
`ifdef SPI
`ifdef SPI_ESP32
    assign spi_clk = sd_clk;
    assign spi_cs  = sd_cmd;
    assign rxdata  = sd_d[0];  // MOSI
`else
    assign spi_clk = gp19;
    assign spi_cs  = gp20;
    assign rxdata  = gp17;  // MOSI
`endif
`else
    assign rxdata = gp14;
`endif

    assign gn11 = clk_pixel;  // Pixel Clk
    assign gn12 = row_latch;  // Row Latch
    assign gn13 = ~output_enable;  // #OE
    assign gn7  = row_address_active[0];  // A / Row[0]
    assign gn8  = row_address_active[1];  // B / Row[1]
    assign gn9  = row_address_active[2];  // C / Row[2]
    assign gn10 = row_address_active[3];  // D / Row[3]
    assign gn0  = rgb1[0];  // Red   1
    assign gn1  = rgb1[1];  // Green 1
    assign gn2  = rgb1[2];  // Blue  1
    assign gn3  = rgb2[0];  // Red   2
    assign gn4  = rgb2[1];  // Green 2
    assign gn5  = rgb2[2];  // Blue  2
    assign gn14 = gp14;  // ctrl serial port RX

    // gtkw 20250714-part1 -- use this for digging into suspected ctrl/uartrx issues
    // assign gn1 = ram_access_start;
    // assign {gn15, gn12, gn10, gn5, gn4, gn3, gn2 } = {~cmd_line_addr2[6:1], cmd_line_addr2[0]};
    // assign {gn9, gn8, gn7, gn16} = ram_a_data_in[5:0];
    // assign gn0 = ram_a_write_enable;
    // assign gn11 = rx_running;
    // assign {gn14, gn13} = cmd_line_state;

    // template
    //     assign {gn15, gn14, gn13, gn12, gn11, gn10, gn9, gn8, gn7, gn16, gn5, gn4, gn3, gn2, gn1, gn0}
`ifdef DEBUGGER
    wire _unused_ok_debugger =  &{1'b0,
                            debugger_debug_start,
                            debugger_current_state,
                            debugger_do_close,
                            debugger_tx_start,
                            debugger_current_position,
                            debug_command_pulse,
                            debug_command_busy,
                            debug_uart_tx,
                            debug_uart_rx,
                            debug_command,
    //from controller
    ram_access_start, ram_access_start_latch, cmd_line_addr2, num_commands_processed,
    //end controller
    //from framebuffer_fetch
    pixel_load_counter2,
    //end framebuffer_fetch
    //from matrix_scan
    state_advance, row_latch_state, clk_pixel_load_en, matrix_row_latch2,
    // end matrix_scan
    1'b0};
`else
    wire _unused_ok_debugger = &{1'b0, gp15, 1'b0};
`endif
`ifdef DOUBLE_BUFFER
    wire _unused_ok_double_buffer = &{1'b0, ram_a_data_out_frame2, 1'b0};
`endif

`ifdef SPI
`ifdef SPI_ESP32
    wire _unused_ok_spi_esp32 = &{1'b0, sd_d[3:1], 1'b0};
`endif
`endif
`ifdef SPI
    wire _unused_ok_spi = &{1'b0, spi_slave_sdout, 1'b0};
`else
    wire _unused_ok_spi = &{1'b0, uart_rx_dataready, 1'b0};
`endif
`ifdef USE_FM6126A
    wire _unused_ok_fm6126a = &{1'b0, init_reset_strobe, 1'b0};
`endif
    wire _unused_ok = &{1'b0,
                        pll_locked,
                        rxdata_ready_level,
                        ctrl_busy,
                        ctrl_ready_for_data,
                        ram_a_data_out_frame1,
                        1'b0};
endmodule
