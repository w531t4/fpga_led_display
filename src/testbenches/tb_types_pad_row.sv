// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
`default_nettype none
module tb_types_pad_row;
    initial begin
        types::row_addr_field_t row_field;
        int unsigned row_pad_bits;

        row_pad_bits = calc::num_padding_bits_needed_to_reach_byte_boundry($bits(types::row_addr_t));
        if (row_pad_bits != 0)
            $fatal(1, "row pad bits expected 0, got %0d", row_pad_bits);

        row_field = '0;
        row_field.bytes[0] = 8'h3C;
        if (types::row_addr_from_field(row_field) != types::row_addr_t'(8'h3C))
            $fatal(1, "row bytes/raw mapping mismatch");

        $finish;
    end
endmodule
