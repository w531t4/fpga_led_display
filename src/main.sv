// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module main #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
`ifdef USE_LITEDRAM_BIST
    output [7:0] led,
`elsif USE_LITEDRAM_WRITE_MIRROR
    output [7:0] led,
`elsif USE_BOARDLEDS_BRIGHTNESS
    output [7:0] led,
`endif
`ifdef SPI
`ifdef SPI_ESP32
    input             wifi_gpio13,  // mosi
    input             wifi_gpio14,  // clk
    input        wifi_gpio21,  // ce
    output       wifi_gpio35,  // controller busy indicator (FPGA -> ESP32)
    output       wifi_gpio27,  // fpga reset notify
`else
    input        gp17,         // miso
    //   output gp18, // mosi
    input        gp19,         // clk
    input        gp20,         // ce
`endif
`endif
`ifdef USE_PASSTHRU
    input        ftdi_txd,
    input        wifi_txd,
    input        ftdi_ndtr,
    input        ftdi_nrts,

    output       ftdi_rxd,
    output       wifi_rxd,
    output       wifi_en,
    output       wifi_gpio0,
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
`ifdef USE_LITEDRAM
    output       sdram_clk,
    output [12:0] sdram_a,
    output [1:0] sdram_ba,
    output       sdram_casn,
    output       sdram_cke,
    output       sdram_csn,
    output [1:0] sdram_dqm,
    input  [15:0] sdram_d,
    output       sdram_rasn,
    output       sdram_wen,
`endif
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

`ifdef USE_PASSTHRU
    assign ftdi_rxd = wifi_txd;
    assign wifi_rxd = ftdi_txd;
    wire [1:0] pass_in = {ftdi_ndtr, ftdi_nrts};
    wire [1:0] pass_out = (pass_in == 2'b10) ? 2'b01 : (pass_in == 2'b01) ? 2'b10 : 2'b11;
    assign wifi_en    = pass_out[1];
    assign wifi_gpio0 = pass_out[0];
`endif

    wire                         clk_root;
    wire                         clk_matrix;

    wire                         global_reset;
    logic                        global_reset_sync;
    types::ready_holdoff_count_t _unused_ok_ready_holdoff_counter;
    wire                         ready_holdoff_running;
    logic                        fpga_ready;

    wire                         clk_pixel_load;
    wire                         clk_pixel;
    wire                         row_latch;
    wire types::mem_write_data_t ctrl_ram_data_out;
    wire types::mem_write_addr_t ctrl_ram_address;
    wire                         ctrl_ram_write_enable;
    wire                         ctrl_ram_clk_enable;
`ifdef DOUBLE_BUFFER
    mem_copy_if copy_int ();
    wire  frame_select;
`endif
    types::mem_read_data_t ram_b_data_out;
    wire types::mem_read_addr_t ram_b_address;
    wire ram_b_clk_enable;

    // Display-side read port between framebuffer_fetch and row_prefetch
    // (row_prefetch then talks to framebuffer_fabric over ram_b_*).
    types::mem_read_data_t rowbuf_data_out;
    wire types::mem_read_addr_t rowbuf_address;
    wire rowbuf_clk_enable;
    // The matrix_scan-internal row_latch event (pre FM6126A-init blending),
    // used to trigger row_prefetch's bank swap/fill in sync with row_address.
    wire matrix_row_latch;

    // Per-subpanel pixeldata fetched from framebuffer.
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    wire types::color_field_t pixeldata_subpanels[NUM_SUBPANELS];
    wire types::rgb_signals_t rgb_subpanels[NUM_SUBPANELS];
    wire ctrl_busy;
    wire ctrl_ready_for_data;

`ifdef DEBUGGER
    debugger_if debug_if (clk_root);
    wire [4:0] debugger_current_state;
`endif

    // [5:0]
    wire types::col_addr_t column_address;
    wire types::row_subpanel_addr_t row_address;
    wire types::row_subpanel_addr_t row_address_active;
    wire types::brightness_level_t brightness_mask;

    wire types::rgb_signals_t rgb_enable;
    wire types::brightness_level_t brightness_enable;
    wire types::rgb_signals_t rgb[NUM_SUBPANELS];  // 0=top, 1=bottom
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
`ifdef USE_LITEDRAM
    wire        litedram_init_done;
    wire        litedram_init_error;
    wire        litedram_user_clk;
    wire        litedram_user_rst;
    wire        litedram_cmd_valid;
    wire        litedram_cmd_ready;
    wire        litedram_cmd_we;
    wire [23:0] litedram_cmd_addr;
    wire        litedram_wdata_valid;
    wire        litedram_wdata_ready;
    wire  [1:0] litedram_wdata_we;
    wire [15:0] litedram_wdata_data;
    wire        litedram_rdata_valid;
    wire        litedram_rdata_ready;
    wire [15:0] litedram_rdata_data;
    wire        litedram_bist_busy;
    wire        litedram_bist_done;
    wire        litedram_bist_error;
    wire        litedram_mirror_busy;
    wire        litedram_mirror_seen_write;
    wire        litedram_mirror_dropped;
    wire        litedram_mirror_dropped_before_init;
    wire        litedram_mirror_error;
`endif
`ifdef USE_LITEDRAM_BIST
    // BIST bring-up LEDs: [0]=init_done, [1]=init_error, [2]=busy,
    // [3]=done, [4]=error. Desired pass result is led[0] and led[3]
    // on, with led[1], led[2], and led[4] off. Upper LEDs are reserved
    // for later probes.
    assign led = {3'b000, litedram_bist_error, litedram_bist_done, litedram_bist_busy, litedram_init_error,
                  litedram_init_done};
`elsif USE_LITEDRAM_WRITE_MIRROR
    // Write-mirror LEDs: [0]=init_done, [1]=init_error, [2]=busy,
    // [3]=saw at least one mirrored write, [4]=dropped while busy,
    // [5]=mirror error, [6]=dropped before init. A clean active mirror is
    // led[0] and led[3] on, with led[1], led[4], led[5], and led[6] off.
    assign led = {1'b0, litedram_mirror_dropped_before_init, litedram_mirror_error, litedram_mirror_dropped,
                  litedram_mirror_seen_write, litedram_mirror_busy, litedram_init_error, litedram_init_done};
`elsif USE_BOARDLEDS_BRIGHTNESS
    assign led = brightness_enable;
`endif
    // No wires past here

    new_pll #(
        .SPEED(params::PLL_SPEED)
    ) new_pll_inst (
        .clock_in(clk_25mhz),
        .clock_out(clk_root),
        .locked(pll_locked)
    );

`ifdef USE_FM6126A
    wire types::rgb_signals_t rgb_fm6126init;
    wire row_latch_fm6126init;
    wire pixclock_fm6126init;
    wire output_enable_intermediary;
    wire types::rgb_signals_t rgb_intermediary[NUM_SUBPANELS];
    wire clk_pixel_intermediary;
    wire row_latch_intermediary;
    wire init_reset_strobe;
    wire fm6126mask_en;
    fm6126init do_init (
        .clk_in(clk_matrix),
        .reset(alt_reset),
        .rgb_out(rgb_fm6126init),
        .latch_out(row_latch_fm6126init),
        .mask_en(fm6126mask_en),
        .pixclock_out(pixclock_fm6126init),
        .reset_notify(init_reset_strobe)
    );
    assign output_enable = output_enable_intermediary & fm6126mask_en;
    assign row_latch = (row_latch_intermediary & fm6126mask_en) | (row_latch_fm6126init & ~fm6126mask_en);
    assign clk_pixel = (clk_pixel_intermediary & fm6126mask_en) | (pixclock_fm6126init & ~fm6126mask_en);
`endif
`ifdef USE_FM6126A
    assign matrix_row_latch = row_latch_intermediary;
`else
    assign matrix_row_latch = row_latch;
`endif

`ifdef DEBUGGER
    // TODO: Would be great if these signals were assigned in the module
    assign debug_if.rxdata_to_controller = rxdata_to_controller;
    assign debug_if.brightness_enable = brightness_enable;
    assign debug_if.rgb_enable = rgb_enable;
    wire [7:0] debug_command;
    wire debug_uart_tx;
    wire debug_uart_rx;
`endif

    reset_on_start #() RoS_obj (
        .clock_in(clk_root),
        .reset(alt_reset)
    );
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
    timeout #(
        .COUNTER_WIDTH($bits(types::ready_holdoff_count_t))
    ) fpga_ready_holdoff (
        .reset  (global_reset_sync | ~pll_locked),
        .clk_in (clk_root),
        .start  (1'b1),
        .value  (types::ready_holdoff_count_t'(params::READY_HOLDOFF_TICKS)),
        .counter(_unused_ok_ready_holdoff_counter),
        .running(ready_holdoff_running)
    );
    always_comb begin
        fpga_ready = pll_locked && !global_reset_sync && !ready_holdoff_running;
    end

`ifdef USE_LITEDRAM
    ulx3s_litedram_wrapper litedram (
        .clk(clk_root),
        .reset(global_reset_sync | ~pll_locked),
        .init_done(litedram_init_done),
        .init_error(litedram_init_error),
        .sdram_clk(sdram_clk),
        .sdram_a(sdram_a),
        .sdram_ba(sdram_ba),
        .sdram_casn(sdram_casn),
        .sdram_cke(sdram_cke),
        .sdram_csn(sdram_csn),
        .sdram_dqm(sdram_dqm),
        .sdram_d(sdram_d),
        .sdram_rasn(sdram_rasn),
        .sdram_wen(sdram_wen),
        .user_clk(litedram_user_clk),
        .user_rst(litedram_user_rst),
        .cmd_valid(litedram_cmd_valid),
        .cmd_ready(litedram_cmd_ready),
        .cmd_we(litedram_cmd_we),
        .cmd_addr(litedram_cmd_addr),
        .wdata_valid(litedram_wdata_valid),
        .wdata_ready(litedram_wdata_ready),
        .wdata_we(litedram_wdata_we),
        .wdata_data(litedram_wdata_data),
        .rdata_valid(litedram_rdata_valid),
        .rdata_ready(litedram_rdata_ready),
        .rdata_data(litedram_rdata_data)
    );

`ifdef USE_LITEDRAM_BIST
    litedram_bist litedram_probe (
        .clk(litedram_user_clk),
        .reset(global_reset_sync | ~pll_locked | litedram_user_rst),
        .init_done(litedram_init_done),
        .init_error(litedram_init_error),
        .busy(litedram_bist_busy),
        .done(litedram_bist_done),
        .error(litedram_bist_error),
        .cmd_valid(litedram_cmd_valid),
        .cmd_ready(litedram_cmd_ready),
        .cmd_we(litedram_cmd_we),
        .cmd_addr(litedram_cmd_addr),
        .wdata_valid(litedram_wdata_valid),
        .wdata_ready(litedram_wdata_ready),
        .wdata_we(litedram_wdata_we),
        .wdata_data(litedram_wdata_data),
        .rdata_valid(litedram_rdata_valid),
        .rdata_ready(litedram_rdata_ready),
        .rdata_data(litedram_rdata_data)
    );
    assign litedram_mirror_busy = 1'b0;
    assign litedram_mirror_seen_write = 1'b0;
    assign litedram_mirror_dropped = 1'b0;
    assign litedram_mirror_dropped_before_init = 1'b0;
    assign litedram_mirror_error = 1'b0;
`elsif USE_LITEDRAM_WRITE_MIRROR
`ifdef DOUBLE_BUFFER
    wire litedram_mirror_source_frame = ~frame_select;
`else
    wire litedram_mirror_source_frame = 1'b0;
`endif
    litedram_write_mirror litedram_mirror (
        .clk(litedram_user_clk),
        .reset(global_reset_sync | ~pll_locked | litedram_user_rst),
        .init_done(litedram_init_done),
        .init_error(litedram_init_error),
        .source_addr(ctrl_ram_address),
        .source_data(ctrl_ram_data_out),
        .source_write_valid(ctrl_ram_clk_enable & ctrl_ram_write_enable),
        .source_frame(litedram_mirror_source_frame),
        .busy(litedram_mirror_busy),
        .seen_write(litedram_mirror_seen_write),
        .dropped(litedram_mirror_dropped),
        .dropped_before_init(litedram_mirror_dropped_before_init),
        .error(litedram_mirror_error),
        .cmd_valid(litedram_cmd_valid),
        .cmd_ready(litedram_cmd_ready),
        .cmd_we(litedram_cmd_we),
        .cmd_addr(litedram_cmd_addr),
        .wdata_valid(litedram_wdata_valid),
        .wdata_ready(litedram_wdata_ready),
        .wdata_we(litedram_wdata_we),
        .wdata_data(litedram_wdata_data),
        .rdata_valid(litedram_rdata_valid),
        .rdata_ready(litedram_rdata_ready),
        .rdata_data(litedram_rdata_data)
    );
    assign litedram_bist_busy = 1'b0;
    assign litedram_bist_done = 1'b0;
    assign litedram_bist_error = 1'b0;
`else
    assign litedram_cmd_valid = 1'b0;
    assign litedram_cmd_we = 1'b0;
    assign litedram_cmd_addr = 24'h000000;
    assign litedram_wdata_valid = 1'b0;
    assign litedram_wdata_we = 2'b00;
    assign litedram_wdata_data = 16'h0000;
    assign litedram_rdata_ready = 1'b1;
    assign litedram_bist_busy = 1'b0;
    assign litedram_bist_done = 1'b0;
    assign litedram_bist_error = 1'b0;
    assign litedram_mirror_busy = 1'b0;
    assign litedram_mirror_seen_write = 1'b0;
    assign litedram_mirror_dropped = 1'b0;
    assign litedram_mirror_dropped_before_init = 1'b0;
    assign litedram_mirror_error = 1'b0;
`endif
`endif

    /* produce signals to scan a 64x32 LED matrix, with 6-bit color */
    clock_divider #(
        .CLK_DIV_COUNT(params::DIVIDE_CLK_BY_X_FOR_MATRIX)
    ) clkdiv_baudrate (
        .reset  (global_reset_sync),
        .clk_in (clk_root),
        .clk_out(clk_matrix)
    );

    matrix_scan #(
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
        .debug_if(debug_if)
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

        .ram_data_in(rowbuf_data_out),
        .ram_address(rowbuf_address),
        .ram_clk_enable(rowbuf_clk_enable),

        .pixeldata_subpanels(pixeldata_subpanels)
    );

    // Ping-pong row buffer: decouples framebuffer_fetch's per-pixel reads from
    // the framebuffer_fabric/multimem backing store. framebuffer_fabric is
    // unchanged; it still just serves ram_b_* reads, now issued by row_prefetch
    // instead of framebuffer_fetch directly.
    row_prefetch #(
        ._UNUSED('d0)
    ) row_buf (
        .reset (global_reset_sync),
        .clk_in(clk_root),

        .read_address(rowbuf_address),
        .read_clk_enable(rowbuf_clk_enable),
        .read_data_out(rowbuf_data_out),

        .row_address(row_address),
        .brightness_mask(brightness_mask),
        .row_latch(matrix_row_latch),

        .fill_address(ram_b_address),
        .fill_clk_enable(ram_b_clk_enable),
        .fill_data_in(ram_b_data_out)
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
        .TICKS_PER_BIT(params::CTRLR_CLK_TICKS_PER_BIT)
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
        .WATCHDOG_CONTROL_TICKS(params::WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) ctrl (
        .reset(global_reset),
        .clk_in(clk_root),
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
        .ram_data_out(ctrl_ram_data_out),
        .ram_address(ctrl_ram_address),
        .ram_write_enable(ctrl_ram_write_enable),
`ifdef DOUBLE_BUFFER
        .cmd_copyframe_if(copy_int),
        .frame_select(frame_select),
`endif
`ifdef USE_WATCHDOG
        .watchdog_reset(watchdog_reset),
`endif
`ifdef DEBUGGER
        .debug_if(debug_if),
`endif
        .ram_clk_enable(ctrl_ram_clk_enable)
    );

    // Framebuffer fabric (mux + multimem instances).
    framebuffer_fabric fb_fabric (
        .clk_root(clk_root),
        .reset(global_reset_sync),
        .ctrl_ram_address(ctrl_ram_address),
        .ctrl_ram_data_out(ctrl_ram_data_out),
        .ctrl_ram_write_enable(ctrl_ram_write_enable),
        .ctrl_ram_clk_enable(ctrl_ram_clk_enable),
        .ram_b_address(ram_b_address),
        .ram_b_clk_enable(ram_b_clk_enable),
        .ram_b_data_out(ram_b_data_out)
`ifdef DOUBLE_BUFFER,
        .frame_select(frame_select),
        .copy_if(copy_int)
`endif
    );

    genvar subpanel_idx;
    generate
        for (subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx = subpanel_idx + 1) begin : gen_subpanel_idx
            // Split the pixels and get the current brightness bit per subpanel.
            pixel_split #(
                ._UNUSED('d0)
            ) px (
                .pixel_data(pixeldata_subpanels[subpanel_idx]),
                .brightness_mask(brightness_mask),
                .brightness_enable(brightness_enable),
                .rgb_enable(rgb_enable),
                .rgb_output(rgb_subpanels[subpanel_idx])
            );
`ifdef USE_FM6126A
            // FM6126A masking happens later, so feed the intermediaries.
            assign rgb_intermediary[subpanel_idx] = rgb_subpanels[subpanel_idx];
            assign rgb[subpanel_idx] = (rgb_intermediary[subpanel_idx] & {3{fm6126mask_en}}) | (rgb_fm6126init & {3{~fm6126mask_en}});
`else
            // Directly drive the final RGB signals when no masking is needed.
            assign rgb[subpanel_idx] = rgb_subpanels[subpanel_idx];
`endif
        end
    endgenerate

`ifdef DEBUGGER
    debugger #(
        // Describes the sample rate of messages sent to debugger client
        .DIVIDER_TICKS(params::DEBUG_MSGS_PER_SEC_TICKS),
        // Describes the baudrate for sending messages to debugger client
        .UART_TICKS_PER_BIT(params::DEBUG_TX_UART_TICKS_PER_BIT)
    ) mydebug (
        .clk_in(clk_root),
        .reset(global_reset),
        .debug_if(debug_if),
        .debug_uart_rx_in(debug_uart_rx),
        .debug_command(debug_command),
        .currentState(debugger_current_state),
        .tx_out(debug_uart_tx)
    );
    assign gp16 = debug_uart_tx;
    assign debug_uart_rx = gp15;
`else
    assign gp16 = 1'b0;
`endif
`ifdef SWAP_BLUE_GREEN_CHAN
    assign {gp0, gp1, gp2} = {rgb[0].red, rgb[0].blue, rgb[0].green};
    assign {gp3, gp4, gp5} = {rgb[1].red, rgb[1].blue, rgb[1].green};
`else
    assign {gp0, gp1, gp2} = rgb[0];
    assign {gp3, gp4, gp5} = rgb[1];
`endif
    assign gp11 = clk_pixel;  // Pixel Clk
    assign gp12 = row_latch;  // Row Latch
    assign gp13 = ~output_enable;  // #OE
    assign {gp10, gp9, gp8, gp7} = 4'(row_address_active);  // D, C, B, A
`ifdef SPI
`ifdef SPI_ESP32
    assign spi_clk = wifi_gpio14;
    assign spi_cs = wifi_gpio21;
    assign rxdata = wifi_gpio13;  // MOSI
    assign wifi_gpio27 = fpga_ready;
    assign wifi_gpio35 = ctrl_busy;  // high while command executes
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
    assign {gn10, gn9, gn8, gn7} = 4'(row_address_active);  // D, C, B, A
`ifdef SWAP_BLUE_GREEN_CHAN
    assign {gn0, gn1, gn2} = {rgb[0].red, rgb[0].blue, rgb[0].green};
    assign {gn3, gn4, gn5} = {rgb[1].red, rgb[1].blue, rgb[1].green};
`else
    assign {gn0, gn1, gn2} = rgb[0];
    assign {gn3, gn4, gn5} = rgb[1];
`endif
    assign gn14 = gp14;  // ctrl serial port RX

    // gtkw 20250714-part1 -- use this for digging into suspected ctrl/uartrx issues
    // assign gn1 = debug_if.ram_access_start;
    // assign {gn15, gn12, gn10, gn5, gn4, gn3, gn2 } = {~cmd_line_addr2[6:1], cmd_line_addr2[0]};
    // assign {gn9, gn8, gn7, gn16} = ram_a_data_in[5:0];
    // assign gn0 = ram_a_write_enable;
    // assign gn11 = rx_running;
    // assign {gn14, gn13} = cmd_line_state;

    // template
    //     assign {gn15, gn14, gn13, gn12, gn11, gn10, gn9, gn8, gn7, gn16, gn5, gn4, gn3, gn2, gn1, gn0}
`ifdef DEBUGGER
    wire _unused_ok_debugger = &{1'b0, debugger_current_state, debug_uart_tx, debug_uart_rx, debug_command, 1'b0};
`else
    wire _unused_ok_debugger = &{1'b0, gp15, 1'b0};
`endif

`ifdef SPI
    wire _unused_ok_spi = &{1'b0, spi_slave_sdout, 1'b0};
`else
    wire _unused_ok_spi = &{1'b0, uart_rx_dataready, 1'b0};
`endif
`ifdef USE_FM6126A
    wire _unused_ok_fm6126a = &{1'b0, init_reset_strobe, 1'b0};
`endif
`ifdef USE_LITEDRAM
    wire _unused_ok_litedram = &{1'b0,
                                 litedram_init_done,
                                 litedram_init_error,
                                 litedram_user_clk,
                                 litedram_user_rst,
                                 litedram_cmd_ready,
                                 litedram_wdata_ready,
                                 litedram_rdata_valid,
                                 litedram_rdata_data,
                                 litedram_bist_busy,
                                 litedram_bist_done,
                                 litedram_bist_error,
                                 litedram_mirror_busy,
                                 litedram_mirror_seen_write,
                                 litedram_mirror_dropped,
                                 litedram_mirror_error,
                                 1'b0};
`endif
    wire _unused_ok = &{1'b0, pll_locked, rxdata_ready_level, ctrl_busy, ctrl_ready_for_data, 1'b0};
endmodule
