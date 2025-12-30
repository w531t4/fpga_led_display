// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module gamma_correct #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned IN_BITS  = 5,
    parameter integer unsigned OUT_BITS = 8,
    parameter integer unsigned _UNUSED  = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  [ IN_BITS-1:0] in,
    output [OUT_BITS-1:0] out
);

    reg [7:0] gamma_lut[(1 << IN_BITS)];
    wire [OUT_BITS-1:0] color_gamma = gamma_lut[in][7-:OUT_BITS];
    assign out = color_gamma;
    initial $readmemh($sformatf("src/memory/gamma_%0dbit.mem", IN_BITS), gamma_lut);
endmodule
