// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
`include "tb_helper.vh"

module tb_control_cmd_readpixel #(
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    wire                                   slowclk;
    logic                                  clk;
    wire                                   subcmd_enable;
    logic                                  done;
    logic [                           7:0] data_in;
    logic                                  reset;
    wire                                   cmd_readpixel_we;
    wire                                   cmd_readpixel_as;
    wire                                   cmd_readpixel_done;
    wire  [                           7:0] cmd_readpixel_do;
    wire  [     _NUM_ROW_ADDRESS_BITS-1:0] cmd_readpixel_row_addr;
    wire  [  _NUM_COLUMN_ADDRESS_BITS-1:0] cmd_readpixel_col_addr;
    wire  [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readpixel_pixel_addr;
    `include "row4.vh"
    localparam [$bits(myled_row_pixel)-8-1:0] myled_row_pixel_local = myled_row_pixel[$bits(myled_row_pixel)-8-1:0];
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

    control_cmd_readpixel #() cmd_readpixel (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(subcmd_enable),
        .row(cmd_readpixel_row_addr),
        .column(cmd_readpixel_col_addr),
        .pixel(cmd_readpixel_pixel_addr),
        .data_out(cmd_readpixel_do),
        .ram_write_enable(cmd_readpixel_we),
        .ram_access_start(cmd_readpixel_as),
        .done(cmd_readpixel_done)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readpixel);
        clk = 0;
        reset = 1;
        // subcmd_enable = 0;
        data_in = 8'b0;
        // finish reset for tb
        @(posedge clk) @(posedge clk) reset <= ~reset;

        // @(posedge clk) begin
        //     subcmd_enable = 1;
        // end
        `STREAM_BYTES_MSB(slowclk, data_in, myled_row_pixel_local)
        `STREAM_BYTES_MSB(slowclk, data_in, myled_row_pixel_local)

        @(posedge slowclk);
        // // `WAIT_ASSERT(clk, (sysreset == 1), 128*4)

        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end
    always begin
        #(params_pkg::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
endmodule
