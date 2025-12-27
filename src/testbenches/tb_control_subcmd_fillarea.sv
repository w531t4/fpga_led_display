// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
`include "tb_helper.vh"

module tb_control_subcmd_fillarea #(
    parameter int unsigned BYTES_PER_PIXEL = 2,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam WIDTH = 4;
    localparam HEIGHT = 4;
    localparam OUT_BITWIDTH = 8;
    localparam int PIXEL_BITS = $clog2(BYTES_PER_PIXEL);
    localparam int MEM_BYTES = WIDTH * HEIGHT * (1 << PIXEL_BITS);
    localparam MEMBITS = MEM_BYTES * 8;
    localparam int ROW_ADVANCE_MAX_CYCLES = WIDTH * BYTES_PER_PIXEL;
    localparam int DONE_MAX_CYCLES = (WIDTH * BYTES_PER_PIXEL) - 1;
    localparam int MEM_CLEAR_MAX_CYCLES = (WIDTH * HEIGHT * BYTES_PER_PIXEL) + 2;
    logic clk;
    logic subcmd_enable;
    wire [$clog2(WIDTH)-1:0] column;
    wire [$clog2(HEIGHT)-1:0] row;
    wire [$clog2(BYTES_PER_PIXEL)-1:0] pixel;
    wire ram_write_enable;
    wire ram_access_start;
    logic done;
    wire pre_done;
    logic [$clog2(WIDTH) + $clog2(HEIGHT) + $clog2(BYTES_PER_PIXEL)-1:0] addr;
    logic [MEMBITS-1:0] mem;
    logic [MEMBITS-1:0] valid_mask;
    wire [OUT_BITWIDTH-1:0] data_out;
    logic reset;

    control_subcmd_fillarea #(
        .PIXEL_WIDTH(WIDTH),
        .PIXEL_HEIGHT(HEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) subcmd_fillarea (
        .reset(reset),
        .enable(subcmd_enable),
        .clk(clk),
        .ack(done),
        .x1({$clog2(WIDTH) {1'b0}}),
        .y1({$clog2(HEIGHT) {1'b0}}),
        .width(($clog2(WIDTH))'(WIDTH)),
        .height(($clog2(HEIGHT))'(HEIGHT)),
        .color({(BYTES_PER_PIXEL * 8) {1'b0}}),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(pre_done)
    );

    initial begin : init_mask
        int mask_idx;
        valid_mask = '0;
        for (mask_idx = 0; mask_idx < MEM_BYTES; mask_idx = mask_idx + 1) begin
            if ((mask_idx & ((1 << PIXEL_BITS) - 1)) < BYTES_PER_PIXEL) begin
                valid_mask[((mask_idx+1)*8)-1-:8] = 8'hFF;
            end
        end
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_subcmd_fillarea);
        clk = 0;
        done = 0;
        reset = 1;
        addr = '0;
        mem = {MEMBITS{1'b1}};
        subcmd_enable = 0;
        // finish reset for tb
        @(posedge clk) reset <= ~reset;

        @(posedge clk) begin
            subcmd_enable = 1;
        end
        @(posedge clk);

        `WAIT_ASSERT(clk, (row == 3), 1)
        assert (data_out == 8'b0)
        else begin
            $display("expected to see data_out as 0, but saw %d\n", data_out);
            $stop;
        end
        `WAIT_ASSERT(clk, (row == 2), ROW_ADVANCE_MAX_CYCLES)
        `WAIT_ASSERT(clk, (row == 1), ROW_ADVANCE_MAX_CYCLES)
        `WAIT_ASSERT(clk, (row == 0), ROW_ADVANCE_MAX_CYCLES)
        `WAIT_ASSERT(clk, (pre_done == 1), DONE_MAX_CYCLES)
        @(posedge clk) done = 1;
        @(posedge clk) begin
            done = 0;
            subcmd_enable = 0;
        end
        `WAIT_ASSERT(clk, tb_control_subcmd_fillarea.subcmd_fillarea.state == 0, 1)
        `WAIT_ASSERT(clk, |(mem & valid_mask) == 0, MEM_CLEAR_MAX_CYCLES)

        repeat (5) begin
            @(posedge clk);
        end
        $finish;
    end
    always @(posedge clk) begin
        addr = {row, column, pixel};
        if (ram_write_enable) mem[((addr+1)*8)-1-:8] <= data_out[7:0];
    end
    always begin
        #2 clk <= !clk;
    end
endmodule
