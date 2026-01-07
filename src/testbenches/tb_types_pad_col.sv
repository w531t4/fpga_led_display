// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
`default_nettype none
module tb_types_pad_col;
    initial begin
        types::col_addr_field_t field;
        int unsigned pad_bits;

        pad_bits = calc::num_padding_bits_needed_to_reach_byte_boundry($bits(types::col_addr_t));
        if (pad_bits != 0)
            $fatal(1, "col pad bits expected 0, got %0d", pad_bits);

        field = '0;
        field.bytes[0] = 8'hA5;
        if (types::col_addr_from_field(field) != types::col_addr_t'(8'hA5))
            $fatal(1, "col bytes/raw mapping mismatch");

        $finish;
    end
endmodule
