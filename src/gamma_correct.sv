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

    generate
        if (IN_BITS == 5) begin : gen_lut5
            `include "gamma_5bit.svh"
            const logic [7:0] gamma_lut[32] = `GAMMA_5BIT_LUT;
            assign out = gamma_lut[in][7-:OUT_BITS];
        end else if (IN_BITS == 6) begin : gen_lut6
            `include "gamma_6bit.svh"
            const logic [7:0] gamma_lut[64] = `GAMMA_6BIT_LUT;
            assign out = gamma_lut[in][7-:OUT_BITS];
        end else begin : gen_lut8
            `include "gamma_8bit.svh"
            const logic [7:0] gamma_lut[256] = `GAMMA_8BIT_LUT;
            assign out = gamma_lut[in][7-:OUT_BITS];
        end
    endgenerate
endmodule
