`default_nettype none
module main #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
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
    output gn14
    // output gn15,
    // output gn16
    `ifdef SPI
        ,
        `ifdef SPI_ESP32
            input [3:0] sd_d, // sd_d[0]=mosi
            input sd_clk,     // clk
            input sd_cmd      // ce
        `else
            input gp17,       // miso
            //   output gp18, // mosi
            input gp19,       // clk
            input gp20        // ce
        `endif
    `endif
);


    wire clk_root;
    wire clk_matrix;

    wire global_reset;

    wire clk_pixel_load;
    wire clk_pixel;
    wire row_latch;
    wire [7:0] ram_a_data_in;
    wire [7:0] ram_a_data_out;
    //  [11:0]
    wire [_NUM_ADDRESS_A_BITS-1:0] ram_a_address;
    wire ram_a_write_enable;
    wire ram_a_clk_enable;
    wire [_NUM_DATA_B_BITS-1:0] ram_b_data_out;
    //  [10:0]
    wire [_NUM_ADDRESS_B_BITS-1:0] ram_b_address;
    wire ram_b_clk_enable;

    wire [_NUM_BITS_PER_SUBPANEL-1:0] pixeldata_top;
    wire [_NUM_BITS_PER_SUBPANEL-1:0] pixeldata_bottom;

    `ifdef DEBUGGER
        // self
            localparam debug_data_width = 192;
            wire debugger_debug_start;
            wire [4:0] debugger_current_state;
            wire debugger_do_close;
            wire debugger_tx_start;
            wire [$clog2(debug_data_width):0] debugger_current_position;
        // from controller
        wire ram_access_start;
        wire ram_access_start_latch;
        wire [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr2;
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
    wire [$clog2(PIXEL_WIDTH)-1:0] column_address;
    wire [3:0] row_address;
    wire [3:0] row_address_active;
    wire [BRIGHTNESS_LEVELS-1:0] brightness_mask;

    wire [2:0] rgb_enable;
    wire [BRIGHTNESS_LEVELS-1:0] brightness_enable;
    `ifdef USE_BOARDLEDS_BRIGHTNESS
        assign led = brightness_enable;
    `endif
    wire [2:0] rgb1; /* the current RGB value for the top-half of the display */

    wire [2:0] rgb2; /* the current RGB value for the bottom-half of the display */


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
        wire [debug_data_width-1:0] ddata =  {
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
            1'b0, // rxdata_ready_sync
            row_latch,
            row_latch_state[1:0],
            2'b0, // cmd_line_state[1:0],
            1'b0, // uart_rx,
            ram_access_start_latch,
            ram_access_start,
            //								127
            pixeldata_top[_NUM_BITS_PER_SUBPANEL-1:0],
            pixeldata_bottom[_NUM_BITS_PER_SUBPANEL-1:0],
            brightness_mask[BRIGHTNESS_LEVELS-1:0],
            brightness_enable[BRIGHTNESS_LEVELS-1:0],
            rgb_enable[2:0],
            // [5:0]
            column_address[$clog2(PIXEL_WIDTH)-1:0],
            row_address[3:0],
            row_address_active[3:0],
            // [10:0]
            ram_b_address[_NUM_ADDRESS_B_BITS-1:0],
            ram_b_clk_enable,
            ram_b_data_out[_NUM_DATA_B_BITS-1:0],
            ram_a_write_enable,
            ram_a_data_out[7:0],
            //  [11:0]
            ram_a_address[_NUM_ADDRESS_A_BITS-1:0],
            ram_a_clk_enable,
            ram_a_data_in[7:0],
            8'd0 // uart_rx_data[7:0]
            };
    `endif

    reset_on_start #() RoS_obj (
        .clock_in(clk_root),
        .reset(alt_reset)
    );

    assign global_reset = alt_reset;

    /* produce signals to scan a 64x32 LED matrix, with 6-bit color */
    clock_divider #(
        .CLK_DIV_COUNT(DIVIDE_CLK_BY_X_FOR_MATRIX)
    ) clkdiv_baudrate (
        .reset(global_reset),
        .clk_in(clk_root),
        .clk_out(clk_matrix)
    );

    matrix_scan #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS)
    )  matscan1 (
        .reset(global_reset),
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
        `ifdef DEBUGGER
            ,
            .state_advance2(state_advance),
            .row_latch_state2(row_latch_state),
            .clk_pixel_load_en2(clk_pixel_load_en),
            .row_latch2(matrix_row_latch2)
        `endif
    );

    /* the fetch controller */

    framebuffer_fetch #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) fb_f (
        .reset(global_reset),
        .clk_in(clk_root),

        .column_address(column_address),
        .row_address(row_address),
        .pixel_load_start(clk_pixel_load),

        .ram_data_in(ram_b_data_out),
        .ram_address(ram_b_address),
        .ram_clk_enable(ram_b_clk_enable),

        .pixeldata_top(pixeldata_top),
        .pixeldata_bottom(pixeldata_bottom)
        `ifdef DEBUGGER
        ,
            .pixel_load_counter2(pixel_load_counter2)
        `endif
    );

    // for controller
    `ifdef SPI
        spi_slave spislave (
            .rstb(~global_reset),
            .ten(1'b0),     // transmit enable, 0 = disabled
            .tdata(8'b0),
            .mlb(1'b1),     // shift msb first
            .ss(spi_cs),
            .sck(spi_clk),
            .sdin(rxdata),    // data coming from master
            .sdout(spi_slave_sdout),
            .done(rxdata_ready),          // data ready
            .rdata(rxdata_to_controller)   // data
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
    ff_sync #(
    ) uart_sync (
        .clk(clk_root),
        .signal(rxdata_ready),
        .sync_level(rxdata_ready_level),
        .sync_pulse(rxdata_ready_pulse),
        .reset(global_reset)
    );

    /* the control module */
    control_module #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
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

        .ram_data_out(ram_a_data_in),
        .ram_address(ram_a_address),
        .ram_write_enable(ram_a_write_enable),
        .ram_clk_enable(ram_a_clk_enable)
        `ifdef DEBUGGER
            ,
            .ram_access_start2(ram_access_start),
            .ram_access_start_latch2(ram_access_start_latch),
            .cmd_line_addr2(cmd_line_addr2),
            .num_commands_processed(num_commands_processed)
        `endif
    );

    multimem #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) fb (
        .ClockA(clk_root),
        .AddressA(ram_a_address),
        .DataInA(ram_a_data_in),
        .WrA(ram_a_write_enable),
        .ResetA(global_reset),
        .ClockB(clk_root),
        .DataInB(16'b0),
        .AddressB(ram_b_address),
        .WrB(1'b0),
        .ResetB(global_reset),
        .QA(ram_a_data_out),
        .QB(ram_b_data_out),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable)
    );

    /* split the pixels and get the current brightness' bit */
    pixel_split #(
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) px_top (
        .pixel_data(pixeldata_top),
        .brightness_mask(brightness_mask & brightness_enable),
        .rgb_enable(rgb_enable),
        `ifdef USE_FM6126A
            .rgb_output(rgb1_intermediary)
        `else
            .rgb_output(rgb1)
        `endif
    );
    pixel_split #(
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) px_bottom (
        .pixel_data(pixeldata_bottom),
        .brightness_mask(brightness_mask & brightness_enable),
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

    assign gp0 = rgb1[0]; // Red   1
    assign gp1 = rgb1[2]; // Green 1 // switched with blue for my display
    assign gp2 = rgb1[1]; // Blue  1 // switched with green for my display
    assign gp3 = rgb2[0]; // Red   2
    assign gp4 = rgb2[2]; // Green 2 // switched with blue for my display
    assign gp5 = rgb2[1]; // Blue  2 // switched with green for my display
    assign gp11 = clk_pixel; // Pixel Clk
    assign gp12 = row_latch; // Row Latch
    assign gp13 = ~output_enable; // #OE
    assign gp7 = row_address_active[0]; // A / Row[0]
    assign gp8 = row_address_active[1]; // B / Row[1]
    assign gp9 = row_address_active[2]; // C / Row[2]
    assign gp10 = row_address_active[3]; // D / Row[3]
    `ifdef SPI
        `ifdef SPI_ESP32
            assign spi_clk = sd_clk;
            assign spi_cs = sd_cmd;
            assign rxdata = sd_d[0]; // MOSI
        `else
            assign spi_clk = gp19;
            assign spi_cs = gp20;
            assign rxdata = gp17; // MOSI
        `endif
    `else
        assign rxdata = gp14;
    `endif

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
    assign gn14 = gp14;   // ctrl serial port RX

    // gtkw 20250714-part1 -- use this for digging into suspected ctrl/uartrx issues
    // assign gn1 = ram_access_start;
    // assign {gn15, gn12, gn10, gn5, gn4, gn3, gn2 } = {~cmd_line_addr2[6:1], cmd_line_addr2[0]};
    // assign {gn9, gn8, gn7, gn16} = ram_a_data_in[5:0];
    // assign gn0 = ram_a_write_enable;
    // assign gn11 = rx_running;
    // assign {gn14, gn13} = cmd_line_state;

    // template
    //     assign {gn15, gn14, gn13, gn12, gn11, gn10, gn9, gn8, gn7, gn16, gn5, gn4, gn3, gn2, gn1, gn0}

    wire _unused_ok = &{1'b0,
                        pll_locked,
                        rxdata_ready_level,
                        `ifdef DEBUGGER
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
                            ram_access_start,
                            ram_access_start_latch,
                            cmd_line_addr2,
                            num_commands_processed,
                            //end controller
                            //from framebuffer_fetch
                            pixel_load_counter2,
                            //end framebuffer_fetch
                            //from matrix_scan
                            state_advance,
                            row_latch_state,
                            clk_pixel_load_en,
                            matrix_row_latch2,
                            // end matrix_scan
                        `else
                            gp15,
                        `endif
                        ram_a_data_out,
                        `ifdef SPI
                            `ifdef SPI_ESP32
                                sd_d[3:1],
                            `endif
                            spi_slave_sdout,
                        `else
                            uart_rx_dataready,
                        `endif
                        `ifdef USE_FM6126A
                            init_reset_strobe,
                        `endif
                        1'b0};
endmodule
