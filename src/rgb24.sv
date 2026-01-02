// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module rgb24 #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  [23:0] data_in,
    input  [ 7:0] brightness,
    output [ 7:0] red,
    output [ 7:0] green,
    output [ 7:0] blue
);
    wire [7:0] red_selected;
    wire [7:0] green_selected;
    wire [7:0] blue_selected;

    assign red_selected   = data_in[23:16];
    assign green_selected = data_in[15:8];
    assign blue_selected  = data_in[7:0];

    // Rounded multiply (force full product width for read_slang)
    wire [8:0] red_u = {1'b0, red_selected};
    wire [8:0] green_u = {1'b0, green_selected};
    wire [8:0] blue_u = {1'b0, blue_selected};
    wire [8:0] bright_u = {1'b0, brightness};

    wire [17:0] r_mul = red_u * bright_u;
    wire [17:0] g_mul = green_u * bright_u;
    wire [17:0] b_mul = blue_u * bright_u;

    wire [ 7:0] r_eff = (r_mul + 18'd127) >> 8;
    wire [ 7:0] g_eff = (g_mul + 18'd127) >> 8;
    wire [ 7:0] b_eff = (b_mul + 18'd127) >> 8;

`ifdef GAMMA
    gamma_correct #(
        .IN_BITS (8),
        .OUT_BITS(8)
    ) gc_red (
        .in (r_eff),
        .out(red)
    );
    gamma_correct #(
        .IN_BITS (8),
        .OUT_BITS(8)
    ) gc_green (
        .in (g_eff),
        .out(green)
    );
    gamma_correct #(
        .IN_BITS (8),
        .OUT_BITS(8)
    ) gc_blue (
        .in (b_eff),
        .out(blue)
    );
`else
    assign red   = r_eff;
    assign green = g_eff;
    assign blue  = b_eff;
`endif

endmodule
