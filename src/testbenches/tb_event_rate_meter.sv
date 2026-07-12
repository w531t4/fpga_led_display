// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for event_rate_meter.
//
// Coverage:
//   - count sums only COMPLETED bins (in-progress bin excluded)
//   - count updates at bin boundaries and holds in between
//   - oldest bin ages out of the window (sliding, not cumulative)
//   - an idle window decays count to 0
//   - an event landing exactly on a bin boundary is counted (in the closing bin)
//   - reset empties the history
module tb_event_rate_meter #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    localparam integer unsigned BIN_TICKS = 10;
    localparam integer unsigned BINS = 3;

    logic clk;
    logic reset;
    logic event_pulse;
    wire [calc::safe_clog2(BINS*BIN_TICKS+1)-1:0] count;

    event_rate_meter #(
        .BIN_TICKS(BIN_TICKS),
        .BINS(BINS)
    ) dut (
        .clk        (clk),
        .reset      (reset),
        .event_pulse(event_pulse),
        .count      (count)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_event_rate_meter);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    task automatic check_count(input logic [$bits(count)-1:0] expected, input string when);
        if (count !== expected) $fatal(1, "count mismatch %s: got %0d, expected %0d", when, count, expected);
    endtask

    // Emit n events, one per clk, then idle for the rest of the bin.
    task automatic run_bin(input int unsigned n_events);
        for (int unsigned t = 0; t < BIN_TICKS; t = t + 1) begin
            event_pulse = (t < n_events);
            @(posedge clk);
            #1;
        end
        event_pulse = 0;
    endtask

    initial begin
        reset       = 1;
        event_pulse = 0;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;

        // Bins: 2, 3, 1 -> after each boundary the window sum grows.
        run_bin(2);
        check_count(2, "after bin1 (2 events)");
        run_bin(3);
        check_count(5, "after bin2 (+3)");
        run_bin(1);
        check_count(6, "after bin3 (+1), window full");

        // Sliding: a 4-event bin displaces the oldest (2).
        run_bin(4);
        check_count(8, "after bin4 (3+1+4, bin1 aged out)");

        // Hold between boundaries: mid-bin the count must not move.
        event_pulse = 1;
        @(posedge clk);
        #1;
        event_pulse = 0;
        check_count(8, "mid-bin (live bin excluded)");
        // Finish the bin: its single event replaces the 3-event bin.
        for (int unsigned t = 1; t < BIN_TICKS; t = t + 1) begin
            @(posedge clk);
            #1;
        end
        check_count(6, "after bin5 (1+4+1)");

        // Boundary-coincident event: pulse on the bin's last tick counts in
        // the CLOSING bin.
        for (int unsigned t = 0; t < BIN_TICKS - 1; t = t + 1) begin
            @(posedge clk);
            #1;
        end
        event_pulse = 1;
        @(posedge clk);
        #1;
        event_pulse = 0;
        check_count(6, "after bin6 (4+1+1, boundary event counted)");

        // Idle windows decay to zero.
        run_bin(0);
        run_bin(0);
        run_bin(0);
        check_count(0, "after idle window");

        // Reset empties the history mid-window.
        run_bin(2);
        check_count(2, "before reset");
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        check_count(0, "after reset");

        $display("tb_event_rate_meter: PASS");
        $finish;
    end

    initial begin
        #100000 $fatal(1, "tb_event_rate_meter: timeout");
    end

endmodule
