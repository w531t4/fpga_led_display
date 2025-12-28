// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module rgb565 #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [15:0] data_in,
    input [ 5:0] brightness,

    output [5:0] red,
    output [5:0] green,
    output [5:0] blue
);

    wire [4:0] red_selected;
    wire [5:0] green_selected;
    wire [4:0] blue_selected;

    assign red_selected   = data_in[15:11];
    assign green_selected = data_in[10:5];
    assign blue_selected  = data_in[4:0];

    wire [6:0] k = {1'b0, brightness} + 7'd1;
    wire k_zero = (brightness == 6'd0);

    wire [10:0] r_prod = red_selected * k;
    wire [11:0] g_prod = green_selected * k;
    wire [10:0] b_prod = blue_selected * k;

    wire [4:0] r5_scaled = k_zero ? 5'd0 : ((r_prod + 11'd32) >> 6);
    wire [5:0] g6_scaled = k_zero ? 6'd0 : ((g_prod + 12'd32) >> 6);
    wire [4:0] b5_scaled = k_zero ? 5'd0 : ((b_prod + 11'd32) >> 6);

`ifdef GAMMA
    gamma_correct #(
        .IN_BITS (5),
        .OUT_BITS(6)
    ) gc_red (
        .in (r5_scaled),
        .out(red)
    );
    gamma_correct #(
        .IN_BITS (6),
        .OUT_BITS(6)
    ) gc_green (
        .in (g6_scaled),
        .out(green)
    );
    gamma_correct #(
        .IN_BITS (5),
        .OUT_BITS(6)
    ) gc_blue (
        .in (b5_scaled),
        .out(blue)
    );
`else
    assign red   = {r5_scaled, r5_scaled[0]};
    assign green = g6_scaled;
    assign blue  = {b5_scaled, b5_scaled[0]};
`endif
endmodule
