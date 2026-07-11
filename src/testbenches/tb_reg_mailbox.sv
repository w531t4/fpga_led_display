// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for reg_mailbox.
//
// Coverage:
//   - reset sentinel: addr 0xFF, seq 0, zero value, valid CRC (converged)
//   - latch pipeline: frame is unchanged one edge after latch and complete
//     (with CRC) two edges after
//   - stability: frame holds across idle cycles (reads don't consume)
//   - overwrite: a second latch replaces the frame (last writer wins)
//   - seq: +1 per latch, wraps mod 256 THROUGH zero (0 is a live value)
module tb_reg_mailbox #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    // Sizes single-sourced from params:: / shapes from types::.
    localparam integer unsigned BODY_BITS = 8 * params::STATUS_BODY_BYTES;
    // Width-agnostic test values for the value field.
    localparam types::status_value_t TEST_VALUE_A = 'h12;
    localparam types::status_value_t TEST_VALUE_B = 'hBE;
    localparam types::status_value_t TEST_VALUE_C = 'h22;
    localparam types::status_value_t TEST_VALUE_D = 'h44;

    logic clk;
    logic reset;
    logic latch;
    logic [7:0] addr_in;
    types::status_value_t value_in;
    wire types::status_reply_t frame;

    reg_mailbox dut (
        .clk  (clk),
        .reset(reset),
        .latch(latch),
        .addr (addr_in),
        .value(value_in),
        .frame(frame)
    );

    // Reference CRC-16/XMODEM (poly 0x1021, init 0, MSB-first) over the body;
    // restated independently of crc16.sv on purpose.
    localparam types::status_crc_t REF_POLY = 'h1021;
    function automatic types::status_crc_t crc_ref(input logic [BODY_BITS-1:0] d);
        types::status_crc_t c;
        c = '0;
        for (int i = BODY_BITS - 1; i >= 0; i = i - 1) begin
            if (c[$bits(c)-1] ^ d[i]) c = {c[$bits(c)-2:0], 1'b0} ^ REF_POLY;
            else c = {c[$bits(c)-2:0], 1'b0};
        end
        return c;
    endfunction

    function automatic types::status_reply_t expected_frame(input logic [7:0] addr, input logic [7:0] seq,
                                                            input types::status_value_t value);
        return {addr, seq, value, crc_ref({addr, seq, value})};
    endfunction

    task automatic check_frame(input types::status_reply_t expected, input string when);
        if (frame !== expected) $fatal(1, "frame mismatch %s: got %08x, expected %08x", when, frame, expected);
    endtask

    // Latch a request and settle the two-stage pipeline.
    task automatic do_latch(input logic [7:0] addr, input types::status_value_t value);
        @(posedge clk);
        #1;
        addr_in  = addr;
        value_in = value;
        latch    = 1'b1;
        @(posedge clk);
        #1;
        latch = 1'b0;
        @(posedge clk);
        #1;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_mailbox);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    initial begin
        reset    = 1;
        latch    = 0;
        addr_in  = '0;
        value_in = '0;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;
        repeat (2) @(posedge clk);
        #1;

        // Reset sentinel, CRC converged.
        check_frame(expected_frame(8'hFF, 8'h00, '0), "reset sentinel");

        // Latch a request; the frame must lag one edge (old value) and be
        // complete after two.
        addr_in  = 8'h3C;
        value_in = TEST_VALUE_A;
        latch    = 1;
        @(posedge clk);
        #1;
        latch = 0;
        check_frame(expected_frame(8'hFF, 8'h00, '0), "one edge after latch (pipeline)");
        @(posedge clk);
        #1;
        check_frame(expected_frame(8'h3C, 8'h01, TEST_VALUE_A), "two edges after latch");

        // Reads don't consume: stable across idle cycles.
        repeat (5) @(posedge clk);
        #1;
        check_frame(expected_frame(8'h3C, 8'h01, TEST_VALUE_A), "after idle cycles");

        // Last writer wins; seq advances.
        do_latch(8'hA7, TEST_VALUE_B);
        check_frame(expected_frame(8'hA7, 8'h02, TEST_VALUE_B), "after overwrite");

        // seq wraps mod 256 THROUGH zero: 254 more latches take it 2 -> 0.
        for (int unsigned k = 0; k < 254; k = k + 1) begin
            do_latch(8'h11, TEST_VALUE_C);
        end
        check_frame(expected_frame(8'h11, 8'h00, TEST_VALUE_C), "seq wrapped through zero (live)");
        do_latch(8'h33, TEST_VALUE_D);
        check_frame(expected_frame(8'h33, 8'h01, TEST_VALUE_D), "seq past the wrap");

        $display("tb_reg_mailbox: PASS");
        $finish;
    end

    initial begin
        #100000 $fatal(1, "tb_reg_mailbox: timeout");
    end

endmodule
