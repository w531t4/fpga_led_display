// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Simple handshake test: captures brightness byte, asserts brightness_change_en/done,
// then returns outputs to idle.
module tb_control_cmd_readbrightness;
    // === Testbench scaffolding ===
    logic                                clk;
    logic                                reset;
    logic                                enable;
    logic                          [7:0] data_in;
    wire types::brightness_level_t       data_out;
    wire                                 brightness_change_en;
    wire                                 done;

    // === DUT wiring ===
    control_cmd_readbrightness #() dut (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(enable),
        .data_out(data_out),
        .brightness_change_en(brightness_change_en),
        .done(done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readbrightness);
        clk = 0;
        reset = 1;
        enable = 0;
        data_in = 8'h3A;
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        enable = 1'b1;  // keep high through the next rising edge
        @(posedge clk);  // DUT latches on this edge
        #(params::SIM_HALF_PERIOD_NS);  // sample mid-cycle after NBA updates
        assert (done == 1'b1)
        else $fatal(1, "done not asserted");
        assert (brightness_change_en == 1'b1)
        else $fatal(1, "brightness_change_en not asserted");
        assert (data_out == data_in)
        else $fatal(1, "Unexpected data_out: %0b", data_out);
        enable = 1'b0;
        @(posedge clk);  // clear handshake on next edge
        #(params::SIM_HALF_PERIOD_NS);
        assert (done == 1'b0 && brightness_change_en == 1'b0 && data_out == 0)
        else $fatal(1, "Outputs not cleared after done");
        repeat (3) @(posedge clk);
        $finish;
    end

    // === Scoreboard / monitor ===
    always @(posedge clk) begin
        if (!reset && enable) begin
            // Allow NBA updates from the DUT before checking the handshake.
            #(params::SIM_HALF_PERIOD_NS);
            assert (done == 1'b1)
            else $fatal(1, "done not asserted on enable");
            assert (brightness_change_en == 1'b1)
            else $fatal(1, "brightness_change_en not asserted on enable");
            assert (data_out == data_in)
            else $fatal(1, "Unexpected data_out on enable: %0b", data_out);
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
endmodule
