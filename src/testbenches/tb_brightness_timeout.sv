// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_brightness_timeout #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    logic clk;
    logic reset;
    logic row_latch;
    wire output_enable;
    wire exceeded_overlap_time;
    types::brightness_level_t brightness_mask_active;
    brightness_timeout #(
        ._UNUSED('d0)
    ) btd (
        .clk_in(clk),
        .reset(reset),
        .row_latch(row_latch),
        .output_enable(output_enable),
        .exceeded_overlap_time(exceeded_overlap_time),
        .brightness_mask_active(brightness_mask_active)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_brightness_timeout);
        clk = 0;
        reset = 1;
        row_latch = 0;
        brightness_mask_active = 1 << ($bits(types::brightness_level_t) - 1);
        @(posedge clk);
        @(posedge clk) reset = 1'b0;
        repeat ($bits(
            types::brightness_level_t
        ) * 2) begin
            @(posedge clk);
            brightness_mask_active = brightness_mask_active >> 1;
        end
        @(posedge clk) brightness_mask_active = 1 << 1;
        @(posedge clk) row_latch = 1;
        @(posedge clk) row_latch = 0;
        repeat ($bits(
            types::brightness_level_t
        ) * 8) begin
            @(posedge clk);
        end
        $finish;
    end
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        output_enable,
                        exceeded_overlap_time,
                        1'b0};
    // verilog_format: on
endmodule
