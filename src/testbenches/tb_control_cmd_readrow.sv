// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.vh"

module tb_control_cmd_readrow #(
    parameter integer unsigned BYTES_PER_PIXEL = params_pkg::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params_pkg::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params_pkg::PIXEL_WIDTH,
    parameter real SIM_HALF_PERIOD_NS = params_pkg::SIM_HALF_PERIOD_NS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    wire                                                             slowclk;
    logic                                                            clk;
    wire                                                             subcmd_enable;
    logic                                                            done;
    logic [                                                     7:0] data_in;
    logic                                                            reset;
    logic                                                            finished;
    wire                                                             cmd_readrow_we;
    wire                                                             cmd_readrow_as;
    wire                                                             cmd_readrow_done;
    wire  [                                                     7:0] cmd_readrow_do;
    wire  [        calc_pkg::num_row_address_bits(PIXEL_HEIGHT)-1:0] cmd_readrow_row_addr;
    wire  [      calc_pkg::num_column_address_bits(PIXEL_WIDTH)-1:0] cmd_readrow_col_addr;
    wire  [calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] cmd_readrow_pixel_addr;
    `include "row4.vh"
    localparam [$bits(myled_row_basic)-8-1:0] myled_row_basic_local = myled_row_basic[$bits(myled_row_basic)-8-1:0];
    wire junk1;
    clock_divider #(
        .CLK_DIV_COUNT(16)
    ) clock_divider_instance (
        .reset  (reset),
        .clk_in (clk),
        .clk_out(slowclk)
    );

    ff_sync #() ff_sync_instance (
        .clk(clk),
        .signal(slowclk),
        .sync_level(junk1),
        .sync_pulse(subcmd_enable),
        .reset(reset)
    );

    control_cmd_readrow cmd_readrow (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(subcmd_enable & finished),
        .row(cmd_readrow_row_addr),
        .column(cmd_readrow_col_addr),
        .pixel(cmd_readrow_pixel_addr),
        .data_out(cmd_readrow_do),
        .ram_write_enable(cmd_readrow_we),
        .ram_access_start(cmd_readrow_as),
        .done(cmd_readrow_done)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readrow);
        clk = 0;
        reset = 1;
        finished = 1;
        // subcmd_enable = 0;
        data_in = 8'b0;
        // finish reset for tb
        @(posedge clk) @(posedge clk) reset <= ~reset;

        // @(posedge clk) begin
        //     subcmd_enable = 1;
        // end
        `STREAM_BYTES_MSB(slowclk, data_in, myled_row_basic_local)
        `STREAM_BYTES_MSB(slowclk, data_in, myled_row_basic_local)
        finished = 0;
        @(posedge slowclk);
        // // `WAIT_ASSERT(clk, (sysreset == 1), 128*4)

        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
    end
endmodule
