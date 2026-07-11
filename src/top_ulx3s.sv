// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Selected by `make BOARD=ulx3s`.
module top_ulx3s (
    input        wifi_gpio13,  // mosi
    input        wifi_gpio14,  // clk
    input        wifi_gpio21,  // ce
    output       wifi_gpio35,  // controller busy indicator (FPGA -> ESP32)
    output       wifi_gpio27,  // fpga reset notify
`ifdef USE_STATUS_SPI
    input        wifi_gpio15,  // READSTATUS read port sck (sd_cmd trace, ESP32 GPIO15)
    input        wifi_gpio4,   // READSTATUS read port cs_n (sd_d1 trace, ESP32 GPIO4)
    output       wifi_gpio2,   // READSTATUS read port miso (sd_d0 trace, ESP32 GPIO2)
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
`ifdef DEBUGGER
    input        gp15,
    output       gp16,
`endif
    input        clk_25mhz
);

    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);

    // Logical signals to/from the board-agnostic core.
    wire types::rgb_signals_t       rgb[NUM_SUBPANELS];
    wire                            clk_pixel;
    wire                            row_latch;
    wire types::row_subpanel_addr_t row_address_active;
    wire                            ctrl_busy;
    wire                            fpga_ready;

    display_core #(
        ._UNUSED('d0)
    ) core (
        .spi_clk(wifi_gpio14),
        .spi_cs(wifi_gpio21),
        .mosi(wifi_gpio13),
        .ctrl_busy(ctrl_busy),
        .fpga_ready(fpga_ready),
`ifdef USE_STATUS_SPI
        .status_sck(wifi_gpio15),
        .status_cs_n(wifi_gpio4),
        .status_miso(wifi_gpio2),
`endif
        .rgb(rgb),
        .clk_pixel(clk_pixel),
        .row_latch(row_latch),
        .nOE(gp13),  // #OE straight to pin (already active-low from display_core)
        .row_address_active(row_address_active),
`ifdef USE_PASSTHRU
        .ftdi_txd(ftdi_txd),
        .wifi_txd(wifi_txd),
        .ftdi_ndtr(ftdi_ndtr),
        .ftdi_nrts(ftdi_nrts),
        .ftdi_rxd(ftdi_rxd),
        .wifi_rxd(wifi_rxd),
        .wifi_en(wifi_en),
        .wifi_gpio0(wifi_gpio0),
`endif
`ifdef DEBUGGER
        .debug_uart_rx(gp15),
        .debug_uart_tx(gp16),
`endif
        .clk_25mhz(clk_25mhz)
    );

    // SPI status outputs.
    assign wifi_gpio27 = fpga_ready;
    assign wifi_gpio35 = ctrl_busy;  // high while command executes


    // connector 1 (conn1) -- single connector on ULX3S gp header
    assign {gp0, gp1, gp2} = rgb[0];
    assign {gp3, gp4, gp5} = rgb[1];
    assign gp11 = clk_pixel;  // Pixel Clk
    assign gp12 = row_latch;  // Row Latch
    assign {gp10, gp9, gp8, gp7} = 4'(row_address_active);  // D, C, B, A

    // row_address_active is a wide type but only its low 4 bits drive the row pins
    // -- suppress the rest.
    wire _unused_ok = &{1'b0, row_address_active, 1'b0};
endmodule
