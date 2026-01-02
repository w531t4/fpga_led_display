// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module brightness #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input types::brightness_level_t value,  /* the pixel's absolute value */
    input types::brightness_level_t mask,  /* a rolling brightness mask */
    input enable,

    output out
);
    /* apply the brightness mask to the calculated sub-pixel value */
    wire masked_value = (value & mask) != 0;
    assign out = masked_value && enable;
endmodule
