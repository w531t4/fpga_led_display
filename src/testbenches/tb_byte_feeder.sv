// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for byte_feeder.
//
// Coverage:
//   - the first byte is presented as soon as reset releases, before any edge
//   - data_out advances at each 8th rising edge, walking the frame in order
//   - both HIGH_INDEX_FIRST settings: two DUTs are fed index-mirrored frames
//     and must produce the identical send sequence
//   - past the last frame byte data_out holds 8'hFF (over-clocked consumers)
//   - a reset pulse re-frames: the next frame starts at the first byte
//   - FRAME_BYTES=1: the calc::safe_clog2 elaboration edge ($clog2(1)=0);
//     serves its one byte then pads 0xFF
module tb_byte_feeder #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    localparam integer unsigned FRAME_BYTES = 3;
    // Send order: AA, 55, C3.
    localparam logic [FRAME_BYTES-1:0][7:0] FRAME_HI = {8'hAA, 8'h55, 8'hC3};
    localparam logic [FRAME_BYTES-1:0][7:0] FRAME_LO = {8'hC3, 8'h55, 8'hAA};
    localparam logic [7:0] SEND_ORDER[FRAME_BYTES] = '{8'hAA, 8'h55, 8'hC3};
    localparam real CLK_HALF_NS = 10.0;
    // Clock past the frame end to exercise the 0xFF pad region.
    localparam integer unsigned EXTRA_BYTES = 2;

    logic clk;
    logic reset;
    wire [7:0] data_out_hi;
    wire [7:0] data_out_lo;

    byte_feeder #(
        .FRAME_BYTES(FRAME_BYTES),
        .HIGH_INDEX_FIRST(1'b1)
    ) dut_hi (
        .clk     (clk),
        .reset   (reset),
        .frame_in(FRAME_HI),
        .data_out(data_out_hi)
    );

    byte_feeder #(
        .FRAME_BYTES(FRAME_BYTES),
        .HIGH_INDEX_FIRST(1'b0)
    ) dut_lo (
        .clk     (clk),
        .reset   (reset),
        .frame_in(FRAME_LO),
        .data_out(data_out_lo)
    );

    // Single-byte frame: witnesses the calc::safe_clog2 elaboration edge
    // (a one-bit index type instead of the degenerate $clog2(1)=0 width).
    localparam logic [7:0] FRAME_ONE = 8'h5A;
    wire [7:0] data_out_one;
    byte_feeder #(
        .FRAME_BYTES(1)
    ) dut_one (
        .clk     (clk),
        .reset   (reset),
        .frame_in(FRAME_ONE),
        .data_out(data_out_one)
    );

    // Send-order byte at idx, 0xFF past the end (mirrors the contract).
    function automatic logic [7:0] expected_byte(input int unsigned idx);
        if (idx < FRAME_BYTES) return SEND_ORDER[idx];
        else return 8'hFF;
    endfunction

    // The single-byte DUT serves its byte at idx 0 and pads 0xFF after.
    function automatic logic [7:0] expected_byte_one(input int unsigned idx);
        if (idx == 0) return FRAME_ONE;
        else return 8'hFF;
    endfunction

    task automatic check_data_out(input int unsigned idx, input string when);
        if (data_out_hi !== expected_byte(idx))
            $fatal(1, "data_out_hi mismatch %s: got %02x, expected %02x", when, data_out_hi, expected_byte(idx));
        if (data_out_lo !== expected_byte(idx))
            $fatal(1, "data_out_lo mismatch %s: got %02x, expected %02x", when, data_out_lo, expected_byte(idx));
        if (data_out_one !== expected_byte_one(idx))
            $fatal(1, "data_out_one mismatch %s: got %02x, expected %02x", when, data_out_one, expected_byte_one(idx));
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_byte_feeder);

        clk   = 1'b1;  // idle high, matching the mode-3 pairing in-tree
        reset = 1'b1;
        #(CLK_HALF_NS);

        // The first byte must be ready the moment reset releases.
        reset = 1'b0;
        #(CLK_HALF_NS);
        check_data_out(0, "at reset release");

        // Walk the frame plus the pad region; after p rising edges the
        // feeder serves send-order byte p/8 (saturated past the end).
        for (int unsigned p = 1; p <= (FRAME_BYTES + EXTRA_BYTES) * 8; p = p + 1) begin
            clk = 1'b0;
            #(CLK_HALF_NS);
            clk = 1'b1;
            #(CLK_HALF_NS);
            check_data_out(p / 8, "after rising edge");
        end

        // A reset pulse re-frames to the first byte.
        reset = 1'b1;
        #(CLK_HALF_NS);
        reset = 1'b0;
        #(CLK_HALF_NS);
        check_data_out(0, "after re-frame");
        for (int unsigned p = 1; p <= 8; p = p + 1) begin
            clk = 1'b0;
            #(CLK_HALF_NS);
            clk = 1'b1;
            #(CLK_HALF_NS);
        end
        check_data_out(1, "second byte after re-frame");

        $display("tb_byte_feeder: PASS");
        $finish;
    end

    initial begin
        #100000 $fatal(1, "tb_byte_feeder: timeout");
    end

endmodule
