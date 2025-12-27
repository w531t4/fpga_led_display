// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
module tb_brightness_timeout;

    logic clk;
    logic reset;
    logic row_latch;
    wire  output_enable;
    wire  exceeded_overlap_time;
    wire  clk_out;
    localparam BASE_TIMEOUT = 23;
    logic [params_pkg::BRIGHTNESS_LEVELS-1:0] brightness_mask_active;
    wire [$clog2(BASE_TIMEOUT) + params_pkg::BRIGHTNESS_LEVELS:0] brightness_timeout;
    brightness_timeout #(
        .BASE_TIMEOUT(BASE_TIMEOUT)
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
        brightness_mask_active = 1 << (params_pkg::BRIGHTNESS_LEVELS - 1);
        @(posedge clk) reset <= 1'b0;
        repeat (params_pkg::BRIGHTNESS_LEVELS * 2) begin
            @(posedge clk);
            brightness_mask_active = brightness_mask_active >> 1;
        end
        @(posedge clk) brightness_mask_active = 1 << 1;
        @(posedge clk) row_latch = 1;
        @(posedge clk) row_latch = 0;
        repeat (params_pkg::BRIGHTNESS_LEVELS * 8) begin
            @(posedge clk);
        end
        $finish;
    end
    always begin
        #(params_pkg::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
endmodule
