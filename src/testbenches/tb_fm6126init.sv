// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_fm6126init;
    logic clk_root;
    logic reset;
    wire mask_en;
    wire [2:0] rgb1_out;
    wire [2:0] rgb2_out;
    wire latch_out;
    wire pixclock_out;
    wire reset_notify;
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
        .pixclock_out(pixclock_out),
        .reset_notify(reset_notify),
        .latch_out(latch_out)
    );
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        mask_en,
                        rgb1_out,
                        rgb2_out,
                        latch_out,
                        pixclock_out,
                        reset_notify,
                        1'b0};
    // verilog_format: on
endmodule
