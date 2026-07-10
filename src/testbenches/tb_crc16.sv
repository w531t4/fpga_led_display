// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for crc16.
//
// Coverage:
//   - standard check value: "123456789" -> 0x31C3 (XMODEM)
//   - known single-byte vectors
//   - leading-zero-pad property (init 0 => zero-padded data CRCs the same)
//     across all byte values and two widths
//   - non-byte-aligned widths (1, 4, 13 bits): the module is N-bit generic,
//     witnessed with hand-derived vectors and a 13-vs-16-bit pad equality
module tb_crc16 #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    localparam integer unsigned CHECK_BITS = 72;

    logic [CHECK_BITS-1:0] check_data;
    wire  [          15:0] check_crc;
    crc16 #(
        .DATA_BITS(CHECK_BITS)
    ) dut_check (
        .data_in(check_data),
        .crc_out(check_crc)
    );

    logic [ 7:0] byte_data;
    wire  [15:0] byte_crc;
    crc16 #(
        .DATA_BITS(8)
    ) dut_byte (
        .data_in(byte_data),
        .crc_out(byte_crc)
    );

    logic [15:0] padded_data;
    wire  [15:0] padded_crc;
    crc16 #(
        .DATA_BITS(16)
    ) dut_padded (
        .data_in(padded_data),
        .crc_out(padded_crc)
    );

    // Non-byte-aligned widths.
    logic bit1_data;
    wire [15:0] bit1_crc;
    crc16 #(
        .DATA_BITS(1)
    ) dut_bit1 (
        .data_in(bit1_data),
        .crc_out(bit1_crc)
    );

    logic [ 3:0] nibble_data;
    wire  [15:0] nibble_crc;
    crc16 #(
        .DATA_BITS(4)
    ) dut_nibble (
        .data_in(nibble_data),
        .crc_out(nibble_crc)
    );

    logic [12:0] bits13_data;
    wire  [15:0] bits13_crc;
    crc16 #(
        .DATA_BITS(13)
    ) dut_bits13 (
        .data_in(bits13_data),
        .crc_out(bits13_crc)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_crc16);

        // Standard check value: ASCII "123456789" -> 0x31C3.
        check_data = 72'h313233343536373839;
        #1;
        if (check_crc !== 16'h31C3) $fatal(1, "check value mismatch: got %04x, expected 31c3", check_crc);

        // Known single-byte vectors.
        byte_data = 8'h00;
        #1;
        if (byte_crc !== 16'h0000) $fatal(1, "crc(00) mismatch: got %04x, expected 0000", byte_crc);
        byte_data = 8'h01;
        #1;
        if (byte_crc !== 16'h1021) $fatal(1, "crc(01) mismatch: got %04x, expected 1021 (the poly)", byte_crc);

        // Leading zero pad must not change the result (init 0).
        for (int v = 0; v < 256; v = v + 1) begin
            byte_data   = v[7:0];
            padded_data = {8'h00, v[7:0]};
            #1;
            if (byte_crc !== padded_crc)
                $fatal(
                    1, "zero-pad property broken at %02x: 8-bit %04x vs 16-bit %04x", byte_data, byte_crc, padded_crc
                );
        end

        // Non-byte-aligned widths, hand-derived vectors.
        bit1_data = 1'b1;
        #1;
        if (bit1_crc !== 16'h1021) $fatal(1, "crc(1'b1) mismatch: got %04x, expected 1021", bit1_crc);
        // Pad-safety pins the 1-bit result to the byte vector above: crc(1'b1) == crc(8'h01).
        nibble_data = 4'hA;
        #1;
        if (nibble_crc !== 16'hA14A) $fatal(1, "crc(4'hA) mismatch: got %04x, expected a14a", nibble_crc);
        // Leading-zero invariance at a non-byte width: 13-bit value == the
        // same value in the 16-bit instance (needs no hand math).
        bits13_data = 13'h1234;
        padded_data = 16'h1234;
        #1;
        if (bits13_crc !== padded_crc)
            $fatal(1, "13-vs-16-bit pad equality broken: %04x vs %04x", bits13_crc, padded_crc);

        $display("tb_crc16: PASS");
        $finish;
    end

endmodule
