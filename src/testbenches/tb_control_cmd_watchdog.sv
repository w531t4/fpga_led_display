// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

`include "tb_helper.vh"

module tb_control_cmd_watchdog #(
    parameter integer unsigned WATCHDOG_SIGNATURE_BITS = params_pkg::WATCHDOG_SIGNATURE_BITS,
    parameter logic [WATCHDOG_SIGNATURE_BITS-1:0] WATCHDOG_SIGNATURE_PATTERN = params_pkg::WATCHDOG_SIGNATURE_PATTERN,
    // TODO: switch WATCHDOG_CONTROL_TICKS to params_pkg::WATCHDOG_CONTROL_TICKS,
    parameter int unsigned WATCHDOG_CONTROL_TICKS = 16 * 12,
    parameter real SIM_HALF_PERIOD_NS = params_pkg::SIM_HALF_PERIOD_NS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic [3:0] divider;
    logic slowclk;
    logic clk;
    logic subcmd_enable;
    logic done;
    logic [7:0] data_in;
    wire sysreset;
    logic reset;

    control_cmd_watchdog #(
        .WATCHDOG_SIGNATURE_BITS(WATCHDOG_SIGNATURE_BITS),
        .WATCHDOG_SIGNATURE_PATTERN(WATCHDOG_SIGNATURE_PATTERN),
        .WATCHDOG_CONTROL_TICKS(WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) cmd_watchdog (
        .reset(reset),
        .data_in(data_in),
        .enable(slowclk),
        .clk(clk),
        .sys_reset(sysreset),
        .done(done)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_watchdog);
        clk = 0;
        slowclk = 0;
        divider = 0;
        slowclk = 0;
        reset = 1;
        subcmd_enable = 0;
        data_in = 8'b0;
        // finish reset for tb
        @(posedge clk) reset <= ~reset;

        for (int i = 0; i < (WATCHDOG_SIGNATURE_BITS / 8); i++) begin
            @(posedge slowclk) begin
                data_in = WATCHDOG_SIGNATURE_PATTERN[(WATCHDOG_SIGNATURE_BITS-1)-(i*8)-:8];
            end
        end
        @(posedge slowclk);
        `WAIT_ASSERT(clk, (sysreset == 1), 128 * 4)

        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
        divider = !clk ? divider + 'd1 : divider;
        slowclk = (divider == 'd0);
    end
endmodule
