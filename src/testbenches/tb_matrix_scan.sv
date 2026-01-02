// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_matrix_scan #(
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params::PIXEL_HALFHEIGHT,
    parameter integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS,
    parameter real SIM_HALF_PERIOD_NS = params::SIM_HALF_PERIOD_NS,
    parameter integer unsigned DIVIDE_CLK_BY_X_FOR_MATRIX = params::DIVIDE_CLK_BY_X_FOR_MATRIX,
    parameter integer BRIGHTNESS_BASE_TIMEOUT = params::BRIGHTNESS_BASE_TIMEOUT,
    parameter integer BRIGHTNESS_STATE_TIMEOUT_OVERLAP = params::BRIGHTNESS_STATE_TIMEOUT_OVERLAP,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam real ADJUSTED_CLOCK = SIM_HALF_PERIOD_NS * DIVIDE_CLK_BY_X_FOR_MATRIX;
    logic clk;
    logic reset;
    wire [calc::num_column_address_bits(PIXEL_WIDTH)-1:0] column_address;
    wire [3:0] row_address;
    wire [3:0] row_address_active;
    wire clk_pixel_load;
    wire clk_pixel;
    wire row_latch;
    wire output_enable;
    wire types::brightness_level_t brightness_mask;


    matrix_scan #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .BRIGHTNESS_BASE_TIMEOUT(BRIGHTNESS_BASE_TIMEOUT),
        .BRIGHTNESS_STATE_TIMEOUT_OVERLAP(BRIGHTNESS_STATE_TIMEOUT_OVERLAP),
        ._UNUSED('d0)
    ) matrix_scan_instance (
        .clk_in(clk),
        .reset(reset),
        .column_address(column_address),
        .row_address(row_address),
        .row_address_active(row_address_active),
        .clk_pixel_load(clk_pixel_load),
        .clk_pixel(clk_pixel),
        .row_latch(row_latch),
        .output_enable(output_enable),
        .brightness_mask(brightness_mask)
    );
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_matrix_scan);
        clk   = 0;
        reset = 0;
    end

    initial #2 reset = !reset;
    initial #3 reset = !reset;
    initial #10000000 $finish;

    always begin
        #ADJUSTED_CLOCK clk <= !clk;
    end
    // always begin
    // #700 reset <= ! reset;
    // end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        column_address,
                        row_address,
                        row_address_active,
                        clk_pixel_load,
                        clk_pixel,
                        row_latch,
                        output_enable,
                        brightness_mask,
                        1'b0};
    // verilog_format: on
endmodule
