// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for spi_rx_kbps.
//
// Scope: plumbing + windowing, NOT full-scale rate. A real bin is
// ROOT_CLOCK ticks (a whole second) -- infeasible to sim -- so the sliding
// count is proven by tb_event_prescaler and tb_event_rate_meter at small
// scale. Here:
//   - value is 0 after reset
//   - bytes must accumulate into a quantum AND a bin must complete before
//     value moves: even ONE prescale-worth of bytes leaves value at 0,
//     because that quantum sits in the still-open (uncounted) bin
module tb_reg_spi_rx_kbps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
    logic byte_pulse;
    wire types::status_value_t value;

    reg_spi_rx_kbps dut (
        .clk       (clk),
        .reset     (reset),
        .byte_pulse(byte_pulse),
        .value     (value)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_spi_rx_kbps);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    initial begin
        reset      = 1;
        byte_pulse = 0;
        repeat (4) @(posedge clk);
        #1;
        reset = 0;
        repeat (2) @(posedge clk);
        #1;

        if (value !== '0) $fatal(1, "value not 0 after reset: %0h", value);

        // Feed more than one prescale-worth of bytes (>= 1 quantum), but stay
        // far short of a bin boundary: the quantum lands in the open bin,
        // which the meter excludes, so value must remain 0.
        for (int unsigned i = 0; i < params::STATUS_RX_KBPS_PRESCALE + 1000; i = i + 1) begin
            byte_pulse = 1;
            @(posedge clk);
            #1;
        end
        byte_pulse = 0;
        repeat (4) @(posedge clk);
        #1;
        if (value !== '0) $fatal(1, "value moved before a bin completed: %0h", value);

        $display("tb_reg_spi_rx_kbps: PASS");
        $finish;
    end

    initial begin
        #1000000 $fatal(1, "tb_reg_spi_rx_kbps: timeout");
    end

endmodule
