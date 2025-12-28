// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_ff_sync;

    logic clk;
    logic reset;
    logic signal;
    logic sync_level;
    logic sync_pulse;

    ff_sync #() ff_sync_instance (
        .reset(reset),
        .clk(clk),
        .signal(signal),
        .sync_level(sync_level),
        .sync_pulse(sync_pulse)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_ff_sync);
        clk = 0;
        reset = 0;
        signal = 0;
    end

    initial #2 reset = !reset;
    initial #3 reset = !reset;

    initial begin
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = ~signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = ~signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = ~signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = ~signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = ~signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #(params_pkg::SIM_HALF_PERIOD_NS) signal = signal;
        #10 $finish;
    end

    always begin
        #(params_pkg::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
endmodule
