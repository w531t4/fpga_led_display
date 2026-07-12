// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for event_prescaler.
//
// Coverage:
//   - exactly one output per DIVISOR inputs (dense and sparse spacing)
//   - the remainder carries across outputs: long-run out == floor(in/DIVISOR)
//   - output is a one-clk pulse
//   - reset zeroes the remainder
module tb_event_prescaler #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    localparam integer unsigned DIVISOR = 5;

    logic clk;
    logic reset;
    logic pulse_in;
    wire  pulse_out;

    event_prescaler #(
        .DIVISOR(DIVISOR)
    ) dut (
        .clk      (clk),
        .reset    (reset),
        .pulse_in (pulse_in),
        .pulse_out(pulse_out)
    );

    int unsigned outputs_seen;
    always @(posedge clk) begin
        if (pulse_out) outputs_seen <= outputs_seen + 1;
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_event_prescaler);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // Send one input pulse followed by `gap` idle clks.
    task automatic send_pulse(input int unsigned gap);
        pulse_in = 1;
        @(posedge clk);
        #1;
        pulse_in = 0;
        repeat (gap) begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        reset        = 1;
        pulse_in     = 0;
        outputs_seen = 0;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;

        // Dense: 23 back-to-back inputs -> exactly floor(23/5) = 4 outputs.
        for (int unsigned i = 0; i < 23; i = i + 1) send_pulse(0);
        repeat (2) @(posedge clk);
        #1;
        if (outputs_seen !== 4) $fatal(1, "dense: got %0d outputs, expected 4", outputs_seen);

        // Remainder carried (23 mod 5 = 3): two more inputs complete the 5th.
        send_pulse(3);
        send_pulse(3);
        repeat (2) @(posedge clk);
        #1;
        if (outputs_seen !== 5) $fatal(1, "carry: got %0d outputs, expected 5", outputs_seen);

        // Sparse spacing behaves identically.
        for (int unsigned i = 0; i < 10; i = i + 1) send_pulse(4);
        repeat (2) @(posedge clk);
        #1;
        if (outputs_seen !== 7) $fatal(1, "sparse: got %0d outputs, expected 7", outputs_seen);

        // Reset zeroes the remainder: 4 inputs after reset produce nothing.
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        for (int unsigned i = 0; i < DIVISOR - 1; i = i + 1) send_pulse(0);
        repeat (2) @(posedge clk);
        #1;
        if (outputs_seen !== 7) $fatal(1, "post-reset: got %0d outputs, expected 7", outputs_seen);
        send_pulse(0);
        repeat (2) @(posedge clk);
        #1;
        if (outputs_seen !== 8) $fatal(1, "post-reset 5th input: got %0d outputs, expected 8", outputs_seen);

        $display("tb_event_prescaler: PASS");
        $finish;
    end

    initial begin
        #100000 $fatal(1, "tb_event_prescaler: timeout");
    end

endmodule
