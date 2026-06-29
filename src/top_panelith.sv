// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Selected by `make BOARD=panelith` (the default).
// This board drives two HUB75 connectors (conn1 + conn2) with the same image.
module top_panelith (
    input        gn27,         // mosi
    input        gp27,         // clk
    input        wifi_gpio21,  // ce
    output       wifi_gpio38,  // controller busy indicator (FPGA -> ESP32)
    output       wifi_gpio18,  // fpga reset notify
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
    output       gn0,
    output       gp1,
    output       gn1,
    output       gp2,
    output       gn2,
    output       gp3,
    output       gn3,
    output       gp4,
    output       gn4,
    output       gp5,
    output       gn5,
    output       gp6,
    output       gp7,
    output       gn7,
    output       gp8,
    output       gn8,
    output       gp9,
    output       gn9,
    output       gp10,
    output       gn10,
    output       gp11,
    output       gn11,
    output       gp12,
    output       gn12,
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
    wire                            nOE;
    wire types::row_subpanel_addr_t row_address_active;
    wire                            ctrl_busy;
    wire                            fpga_ready;

    display_core #(
        ._UNUSED('d0)
    ) core (
        .spi_clk(gp27),
        .spi_cs(wifi_gpio21),
        .mosi(gn27),
        .ctrl_busy(ctrl_busy),
        .fpga_ready(fpga_ready),
        .rgb(rgb),
        .clk_pixel(clk_pixel),
        .row_latch(row_latch),
        .nOE(nOE),
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
    assign wifi_gpio18 = fpga_ready;
    assign wifi_gpio38 = ctrl_busy;  // high while command executes

    // connector 1 (conn1)
    assign {gp0, gn0, gp1} = rgb[0];
    assign {gn1, gp2, gn2} = rgb[1];
    assign gp5 = clk_pixel;  // Pixel Clk
    assign gn5 = row_latch;  // Row Latch
    assign gp6 = nOE;  // #OE
    assign {gn4, gp4, gn3, gp3} = 4'(row_address_active);  // D, C, B, A

    // connector 2 (conn2)
    assign {gp7, gn7, gp8} = rgb[0];
    assign {gn8, gp9, gn9} = rgb[1];
    assign gp12 = clk_pixel;  // Pixel Clk
    assign gn12 = row_latch;  // Row Latch
    assign gp13 = nOE;  // #OE
    assign {gn11, gp11, gn10, gp10} = 4'(row_address_active);  // D, C, B, A

    // row_address_active is a wide type but only its low 4 bits drive the row pins
    // -- suppress the rest.
    wire _unused_ok = &{1'b0, row_address_active, 1'b0};
endmodule
