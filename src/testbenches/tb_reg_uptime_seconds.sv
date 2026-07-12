// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for reg_uptime_seconds.
//
// Scope: plumbing, NOT full-scale timing. A real tick is ROOT_CLOCK clocks (a
// whole second) -- infeasible to sim -- so the 1 Hz cadence is proven by
// tb_event_prescaler at small scale. Here:
//   - value is 0 after reset
//   - value stays 0 well short of a second: no tick has fired, so the counter
//     has not advanced
module tb_reg_uptime_seconds #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
    wire types::status_value_t value;

    reg_uptime_seconds dut (
        .clk  (clk),
        .reset(reset),
        .value(value)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_uptime_seconds);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    initial begin
        reset = 1;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;
        repeat (2) @(posedge clk);
        #1;

        if (value !== '0) $fatal(1, "value not 0 after reset: %0h", value);

        // Run far short of a full second (ROOT_CLOCK clocks): no tick has
        // fired yet, so the counter must still read 0.
        repeat (10000) @(posedge clk);
        #1;
        if (value !== '0) $fatal(1, "value moved before a second elapsed: %0h", value);

        $display("tb_reg_uptime_seconds: PASS");
        $finish;
    end

    initial begin
        #1000000 $fatal(1, "tb_reg_uptime_seconds: timeout");
    end

endmodule
