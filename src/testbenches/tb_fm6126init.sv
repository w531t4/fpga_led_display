// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
module tb_fm6126init #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    logic clk_root;
    logic reset;
    wire mask_en;
    wire output_enable_out;
    wire [2:0] rgb1_out;
    wire [2:0] rgb2_out;
    wire latch_out;
    always #5 clk_root <= ~clk_root;
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_fm6126init);
        clk_root = 0;
        reset = 0;
        #5 reset = 1;
        #6 reset = 0;
        #100000 $finish;
    end
    fm6126init #() fm6126init (
        .clk_in(clk_root),
        .reset(reset),
        .mask_en(mask_en),
        .rgb1_out(rgb1_out),
        .rgb2_out(rgb2_out),
        .latch_out(latch_out)
    );
endmodule
