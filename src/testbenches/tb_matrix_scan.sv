// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_matrix_scan #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam real ADJUSTED_CLOCK = params::SIM_HALF_PERIOD_NS * params::DIVIDE_CLK_BY_X_FOR_MATRIX;
    logic clk;
    logic reset;
    wire types::col_addr_t column_address;
    wire types::row_subpanel_addr_t row_address;
    wire types::row_subpanel_addr_t row_address_active;
    wire clk_pixel_load;
    wire clk_pixel;
    wire row_latch;
    wire output_enable;
    wire types::brightness_level_t brightness_mask;


`ifdef DEBUGGER
    types::edge_detect_t row_latch_state2;
    wire row_latch2;
    wire state_advance2;
    wire clk_pixel_load_en2;
`endif
    matrix_scan #(
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
`ifdef DEBUGGER,
        .row_latch_state2(row_latch_state2),
        .row_latch2(row_latch2),
        .state_advance2(state_advance2),
        .clk_pixel_load_en2(clk_pixel_load_en2)
`endif
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
`ifdef DEBUGGER
    wire _unused_ok_debugger = &{1'b0,
                                 row_latch_state2,
                                 row_latch2,
                                 state_advance2,
                                 clk_pixel_load_en2,
                                 1'b0};
`endif
    // verilog_format: on
endmodule
