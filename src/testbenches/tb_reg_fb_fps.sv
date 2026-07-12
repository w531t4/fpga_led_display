// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for reg_fb_fps.
//
// With DOUBLE_BUFFER (scope: the edge detector + plumbing; the sliding count
// runs at ROOT_CLOCK-sized bins, proven by tb_event_rate_meter):
//   - value is 0 after reset
//   - EVERY flip of toggle_signal produces exactly one internal pulse (both
//     edges counted, once each)
//   - the resulting quanta land in the still-open bin, so value stays 0
// Without DOUBLE_BUFFER: value is 0 always (the register is still present).
module tb_reg_fb_fps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
`ifdef DOUBLE_BUFFER
    logic toggle_signal;
`endif
    wire types::status_value_t value;

    reg_fb_fps dut (
        .clk          (clk),
        .reset        (reset),
`ifdef DOUBLE_BUFFER
        .toggle_signal(toggle_signal),
`endif
        .value        (value)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_fb_fps);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

`ifdef DOUBLE_BUFFER
    // Count internal edge pulses to verify the detector fires once per flip.
    int unsigned pulses_seen;
    always @(posedge clk) begin
        if (reset) pulses_seen <= 0;
        else if (dut.toggle_pulse) pulses_seen <= pulses_seen + 1;
    end

    // Flip toggle_signal once, then idle `gap` clks.
    task automatic flip(input int unsigned gap);
        toggle_signal = ~toggle_signal;
        @(posedge clk);
        #1;
        repeat (gap) begin
            @(posedge clk);
            #1;
        end
    endtask

    localparam int unsigned N_FLIPS = 40;
`endif

    initial begin
        reset = 1;
`ifdef DOUBLE_BUFFER
        toggle_signal = 0;
`endif
        repeat (4) @(posedge clk);
        #1;
        reset = 0;
        repeat (2) @(posedge clk);
        #1;

        if (value !== '0) $fatal(1, "value not 0 after reset: %0h", value);

`ifdef DOUBLE_BUFFER
        // Both edges count: N flips must yield exactly N pulses.
        for (int unsigned i = 0; i < N_FLIPS; i = i + 1) flip(3);
        if (pulses_seen !== N_FLIPS) $fatal(1, "edge count: got %0d pulses, expected %0d", pulses_seen, N_FLIPS);
        // Those quanta sit in the open bin, so value stays 0 (no bin boundary).
        if (value !== '0) $fatal(1, "value moved before a bin completed: %0h", value);
`else
        // No double buffering: the register is present but always reads 0.
        repeat (50) @(posedge clk);
        #1;
        if (value !== '0) $fatal(1, "value should be 0 without DOUBLE_BUFFER: %0h", value);
`endif

        $display("tb_reg_fb_fps: PASS");
        $finish;
    end

    initial begin
        #1000000 $fatal(1, "tb_reg_fb_fps: timeout");
    end

endmodule
