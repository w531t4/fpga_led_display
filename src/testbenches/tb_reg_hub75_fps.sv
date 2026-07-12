// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for reg_hub75_fps.
//
// Scope: plumbing + windowing, NOT full-scale rate. A real bin is
// ROOT_CLOCK ticks (a whole second) -- infeasible to sim -- so the sliding
// count is proven by tb_event_rate_meter at small scale. Here:
//   - value is 0 after reset
//   - synchronized frame edges land in the still-open (uncounted) bin, so
//     value stays 0 until a bin completes
module tb_reg_hub75_fps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
    logic frame_active;
    wire types::status_value_t value;

    reg_hub75_fps dut (
        .clk         (clk),
        .reset       (reset),
        .frame_active(frame_active),
        .value       (value)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_hub75_fps);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // One frame edge: raise frame_active (held long enough for the internal
    // ff_sync to catch the rising edge), then drop it, then idle `gap` clks.
    task automatic emit_frame(input int unsigned gap);
        frame_active = 1;
        repeat (3) @(posedge clk);
        #1;
        frame_active = 0;
        repeat (gap) begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        reset        = 1;
        frame_active = 0;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;
        repeat (2) @(posedge clk);
        #1;

        if (value !== '0) $fatal(1, "value not 0 after reset: %0h", value);

        // Frame edges land in the open bin (excluded), so value stays 0 until
        // a bin boundary (a full second -- not reached here).
        for (int unsigned i = 0; i < 100; i = i + 1) emit_frame(20);
        if (value !== '0) $fatal(1, "value moved before a bin completed: %0h", value);

        $display("tb_reg_hub75_fps: PASS");
        $finish;
    end

    initial begin
        #1000000 $fatal(1, "tb_reg_hub75_fps: timeout");
    end

endmodule
