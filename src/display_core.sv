// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module display_core #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0,
    // verilator lint_on UNUSEDPARAM
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT)
) (
    // SPI slave: command stream from the host controller.
    input                             spi_clk,
    input                             spi_cs,
    input                             mosi,
    // Status Wires
    output                            ctrl_busy,                          // high while a command executes
    output logic                      fpga_ready,                         // fpga reset-notify / ready
    // READSTATUS read port: host-clocked CS-framed register readback
`ifdef USE_STATUS_SPI
    input                             status_sck,
    input                             status_cs_n,
    output                            status_miso,
`endif
    // HUB75 logical panel signals
    output types::rgb_signals_t       rgb               [NUM_SUBPANELS],  // 0=top, 1=bottom
    output                            clk_pixel,
    output                            row_latch,
    output                            nOE,                                // active-low #OE (already inverted here)
    output types::row_subpanel_addr_t row_address_active,                 // {D,C,B,A}
`ifdef USE_PASSTHRU
    input                             ftdi_txd,
    input                             wifi_txd,
    input                             ftdi_ndtr,
    input                             ftdi_nrts,
    output                            ftdi_rxd,
    output                            wifi_rxd,
    output                            wifi_en,
    output                            wifi_gpio0,
`endif
`ifdef DEBUGGER
    input                             debug_uart_rx,
    output                            debug_uart_tx,
`endif
    input                             clk_25mhz
    // output gn15,
    // output gn16
);

`ifdef USE_PASSTHRU
    // ESP32 flashing passthrough (shared with the standalone restore-flash build,
    // src/passthru/ulx3s_v20_passthru_wifi_modified.v).
    ulx3s_v20_passthru_wifi_modified passthru_inst (
        .ftdi_txd  (ftdi_txd),
        .wifi_txd  (wifi_txd),
        .ftdi_ndtr (ftdi_ndtr),
        .ftdi_nrts (ftdi_nrts),
        .ftdi_rxd  (ftdi_rxd),
        .wifi_rxd  (wifi_rxd),
        .wifi_en   (wifi_en),
        .wifi_gpio0(wifi_gpio0)
    );
`endif

    wire                         clk_root;
    wire                         clk_matrix;

    wire                         global_reset;
    logic                        global_reset_sync;
    types::ready_holdoff_count_t _unused_ok_ready_holdoff_counter;
    wire                         ready_holdoff_running;

    wire                         clk_pixel_load;
    wire types::mem_write_data_t ctrl_ram_data_out;
    wire types::mem_write_addr_t ctrl_ram_address;
    wire                         ctrl_ram_write_enable;
    wire                         ctrl_ram_clk_enable;
`ifdef DOUBLE_BUFFER
    mem_copy_if copy_int ();
    wire frame_select;
`endif
    types::mem_read_data_t ram_b_data_out;
    wire types::mem_read_addr_t ram_b_address;
    wire ram_b_clk_enable;

    // Per-subpanel pixeldata fetched from framebuffer.
    wire types::color_field_t pixeldata_subpanels[NUM_SUBPANELS];
    wire types::rgb_signals_t rgb_subpanels[NUM_SUBPANELS];
    wire types::rgb_signals_t rgb_pre_swap[NUM_SUBPANELS];  // final RGB before green/blue swap
    wire ctrl_ready_for_data;

`ifdef DEBUGGER
    debugger_if debug_if (clk_root);
    wire [4:0] debugger_current_state;
`endif

    // [5:0]
    wire types::col_addr_t          column_address;
    wire types::row_subpanel_addr_t row_address;
    wire types::brightness_level_t  brightness_mask;

    wire types::rgb_signals_t       rgb_enable;
    wire types::brightness_level_t  brightness_enable;
    wire                            output_enable;  // active-high internally
    assign nOE = ~output_enable;  // interface emits active-low #OE
    wire alt_reset;
    wire pll_locked;
    wire rxdata_ready;
    wire rxdata_ready_level;
    wire rxdata_ready_pulse;
    wire [7:0] rxdata_to_controller;
`ifdef USE_STATUS_SPI
    wire types::status_addr_t status_addr;
    wire status_request;
`endif
    wire spi_slave_sdout;
`ifdef USE_WATCHDOG
    wire watchdog_reset;
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

`ifdef DEBUGGER
    // TODO: Would be great if these signals were assigned in the module
    assign debug_if.rxdata_to_controller = rxdata_to_controller;
    assign debug_if.brightness_enable = brightness_enable;
    assign debug_if.rgb_enable = rgb_enable;
    wire [7:0] debug_command;
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

        .ram_data_in(ram_b_data_out),
        .ram_address(ram_b_address),
        .ram_clk_enable(ram_b_clk_enable),

        .pixeldata_subpanels(pixeldata_subpanels)
    );

    // for controller
    spi_slave spislave (
        .rstb (~global_reset),
        .ten  (1'b0),                 // transmit enable, 0 = disabled
        .tdata(8'b0),
        .mlb  (1'b1),                 // shift msb first
        .ss   (spi_cs),
        .sck  (spi_clk),
        .sdin (mosi),                 // data coming from master
        .sdout(spi_slave_sdout),
        .done (rxdata_ready),         // data ready
        .rdata(rxdata_to_controller)  // data
    );

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
        .data_ready_n(~rxdata_ready_pulse),
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
`ifdef USE_STATUS_SPI
        .status_addr(status_addr),
        .status_request(status_request),
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
            assign rgb_pre_swap[subpanel_idx] = (rgb_intermediary[subpanel_idx] & {3{fm6126mask_en}}) | (rgb_fm6126init & {3{~fm6126mask_en}});
`else
            // Directly drive the final RGB signals when no masking is needed.
            assign rgb_pre_swap[subpanel_idx] = rgb_subpanels[subpanel_idx];
`endif
            // Apply the optional green/blue swap here so the board wrappers wire rgb[] straight to pins.
            hub75_rgb_pack rgb_swap (
                .rgb_in (rgb_pre_swap[subpanel_idx]),
                .rgb_out(rgb[subpanel_idx])
            );
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
`endif

`ifdef USE_STATUS_SPI
    // Per-register value producers (each emits a full status_value_t).
    types::status_value_t rx_kbps_value;
    reg_spi_rx_kbps rx_kbps_reg (
        .clk       (clk_root),
        .reset     (global_reset),
        .byte_pulse(rxdata_ready_pulse),
        .value     (rx_kbps_value)
    );

    // Frame-emit rate: the row address MSB rises once per emitted frame; the
    // register synchronizes that clk_matrix edge into clk_root internally.
    wire frame_active = row_address_active[$bits(row_address_active)-1];
    types::status_value_t hub75_fps_value;
    reg_hub75_fps hub75_fps_reg (
        .clk         (clk_root),
        .reset       (global_reset),
        .frame_active(frame_active),
        .value       (hub75_fps_value)
    );

    // Framebuffer swap rate: frame_select flips once per swap (same domain);
    // without DOUBLE_BUFFER the register takes no toggle input and reads 0.
    types::status_value_t fb_fps_value;
    reg_fb_fps fb_fps_reg (
        .clk          (clk_root),
        .reset        (global_reset),
`ifdef DOUBLE_BUFFER
        .toggle_signal(frame_select),
`endif
        .value        (fb_fps_value)
    );

    // Select the one register named by the host's READSTATUS address byte (the
    // register map and wire format live in types.sv).
    types::status_value_t status_value;
    always_comb begin
        status_value = '0;  // reserved addresses read as zero; unused high bits stay zero
        case (status_addr)
            types::STATUS_ADDR_FLAGS:      status_value[2:0] = {fpga_ready, ctrl_busy, ctrl_ready_for_data};
            types::STATUS_ADDR_RGB:        status_value[$bits(rgb_enable)-1:0] = rgb_enable;
            types::STATUS_ADDR_BRIGHTNESS: status_value[$bits(brightness_enable)-1:0] = brightness_enable;
            types::STATUS_ADDR_RX_KBPS:    status_value = rx_kbps_value;
            types::STATUS_ADDR_HUB75_FPS:  status_value = hub75_fps_value;
            types::STATUS_ADDR_FB_FPS:     status_value = fb_fps_value;
            default:                       ;
        endcase
    end

    reg_spi_responder reg_spi_responder_inst (
        .clk_in  (clk_root),
        .reset   (global_reset),
        .latch   (status_request),
        .addr_in (status_addr),
        .value_in(status_value),
        .sck     (status_sck),
        .cs_n    (status_cs_n),
        .miso    (status_miso)
    );
`endif

    // template
    //     assign {gn15, gn14, gn13, gn12, gn11, gn10, gn9, gn8, gn7, gn16, gn5, gn4, gn3, gn2, gn1, gn0}
`ifdef DEBUGGER
    wire _unused_ok_debugger = &{1'b0, debugger_current_state, debug_uart_tx, debug_uart_rx, debug_command, 1'b0};
`endif
    wire _unused_ok_spi = &{1'b0, spi_slave_sdout, 1'b0};
`ifdef USE_FM6126A
    wire _unused_ok_fm6126a = &{1'b0, init_reset_strobe, 1'b0};
`endif
    wire _unused_ok = &{1'b0, pll_locked, rxdata_ready_level, ctrl_busy, ctrl_ready_for_data, 1'b0};
endmodule
