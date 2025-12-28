// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module cocotb_spi_wrapper (
    input  wire       rstb,
    input  wire       clk,
    input  wire       mlb,
    input  wire       start,
    input  wire [7:0] m_tdat,
    input  wire [1:0] cdiv,
    input  wire       ten,
    input  wire [7:0] s_tdata,
    output wire       mdone,
    output wire [7:0] mrdata,
    output wire       slvdone,
    output wire [7:0] slvrdata
);
    wire din;
    wire ss;
    wire sck;
    wire dout;

    spi_master MAS (
        .rstb(rstb),
        .clk(clk),
        .mlb(mlb),
        .start(start),
        .tdat(m_tdat),
        .cdiv(cdiv),
        .din(din),
        .ss(ss),
        .sck(sck),
        .dout(dout),
        .done(mdone),
        .rdata(mrdata)
    );

    spi_slave SLV (
        .rstb(rstb),
        .ten(ten),
        .tdata(s_tdata),
        .mlb(mlb),
        .ss(ss),
        .sck(sck),
        .sdin(dout),
        .sdout(din),
        .done(slvdone),
        .rdata(slvrdata)
    );
endmodule
