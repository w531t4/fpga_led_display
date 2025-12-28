// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module cocotb_main_wrapper (
    input  wire       clk,
    input  wire       reset,
    input  wire       spi_start,
    input  wire       spi_clk_en,
    input  wire [7:0] thebyte,
    output wire       spi_master_txdone
);
    wire clk_pixel;
    wire row_latch;
    wire OE;
    wire ROA0;
    wire ROA1;
    wire ROA2;
    wire ROA3;
    wire rgb2_0;
    wire rgb2_1;
    wire rgb2_2;
    wire rgb1_0;
    wire rgb1_1;
    wire rgb1_2;
    wire debugger_txout;
    wire rxdata;

    wire spi_clk;
    wire spi_cs;
`ifdef SPI_ESP32
    wire [3:0] sd_d = {3'b0, rxdata};
`endif

    main u_main (
        .gp11     (clk_pixel),
        .gp12     (row_latch),
        .gp13     (OE),
        .clk_25mhz(clk),
        .gp7      (ROA0),
        .gp8      (ROA1),
        .gp9      (ROA2),
        .gp10     (ROA3),
        .gp0      (rgb1_0),
        .gp1      (rgb1_1),
        .gp2      (rgb1_2),
        .gp3      (rgb2_2),
        .gp4      (rgb2_0),
        .gp5      (rgb2_1),
        .gp14     (1'b0),
        .gp16     (debugger_txout),
        .gp15     (1'b0),
        .gn11     (),
        .gn12     (),
        .gn13     (),
        .gn7      (),
        .gn8      (),
        .gn9      (),
        .gn10     (),
        .gn0      (),
        .gn1      (),
        .gn2      (),
        .gn3      (),
        .gn4      (),
        .gn5      ()
`ifdef SPI,
`ifdef SPI_ESP32
        .sd_d     (sd_d),
        .sd_clk   (spi_clk),
        .sd_cmd   (spi_cs)
`else
        .gp17     (rxdata),
        .gp19     (spi_clk),
        .gp20     (spi_cs)
`endif
`endif
    );

`ifdef SPI
    spi_master #() spimaster (
        .rstb (~reset),
        .clk  (clk && spi_clk_en),
        .mlb  (1'b1),
        .start(spi_start),
        .tdat (thebyte),
        .cdiv (2'b0),
        .din  (1'b0),
        .ss   (spi_cs),
        .sck  (spi_clk),
        .dout (rxdata),
        .done (spi_master_txdone),
        .rdata()
    );
`else
    assign spi_master_txdone = 1'b0;
`endif
endmodule
