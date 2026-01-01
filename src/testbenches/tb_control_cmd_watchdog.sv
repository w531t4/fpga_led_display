// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

`include "tb_helper.vh"

// Validates watchdog signature capture, done pulse timing, and deferred sys_reset assertion.
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
    localparam int unsigned WATCHDOG_SIGBYTES = WATCHDOG_SIGNATURE_BITS / 8;

    // === Testbench scaffolding ===
    logic [3:0] divider;
    logic       slowclk;
    logic       clk;
    logic       subcmd_enable;
    logic       done;
    logic [7:0] data_in;
    wire        sysreset;
    logic       reset;
    int         signature_bytes_seen;
    bit         done_seen;
    bit         pending_done;
    bit         sysreset_seen;

    // === DUT wiring ===
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

    // === Init ===
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
        repeat (2) @(posedge clk);
        reset = 0;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        for (int i = 0; i < WATCHDOG_SIGBYTES; i++) begin
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

    // === Scoreboard / monitor ===
    always @(posedge clk) begin
        if (reset) begin
            signature_bytes_seen <= 0;
            done_seen <= 1'b0;
            pending_done <= 1'b0;
            sysreset_seen <= 1'b0;
        end else begin
            if (slowclk && (signature_bytes_seen < WATCHDOG_SIGBYTES)) begin
                signature_bytes_seen <= signature_bytes_seen + 1;
                if (signature_bytes_seen == WATCHDOG_SIGBYTES - 1) begin
                    pending_done <= 1'b1;
                end else begin
                    assert (!done)
                    else $fatal(1, "done asserted before final signature byte");
                end
            end

            if (pending_done) begin
                assert (done)
                else $fatal(1, "done not asserted on final signature byte");
                if (done) begin
                    pending_done <= 1'b0;
                    done_seen <= 1'b1;
                end
            end

            if (!done_seen) begin
                assert (sysreset == 1'b0)
                else $fatal(1, "sys_reset asserted before signature completed");
            end

            if (sysreset) begin
                sysreset_seen <= 1'b1;
            end
        end
    end

    // === Clock generation ===
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
        divider = !clk ? divider + 'd1 : divider;
        slowclk = (divider == 'd0);
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        subcmd_enable,
                        sysreset_seen,
                        1'b0};
    // verilog_format: on
endmodule
