// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
`include "tb_helper.vh"
module tb_control_subcmd_fillarea #(
    parameter int unsigned PIXEL_HEIGHT = 4,
    parameter PIXEL_WIDTH = 4,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    localparam OUT_BITWIDTH = 8;
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH);
    localparam _NUM_ROW_ADDRESS_BITS = $clog2(PIXEL_HEIGHT);
    localparam _NUM_PIXELCOLORSELECT_BITS = $clog2(params_pkg::BYTES_PER_PIXEL);
    localparam int MEM_BYTES = PIXEL_WIDTH * PIXEL_HEIGHT * (1 << _NUM_PIXELCOLORSELECT_BITS);
    localparam MEMBITS = MEM_BYTES * OUT_BITWIDTH;
    localparam int ROW_ADVANCE_MAX_CYCLES = PIXEL_WIDTH * params_pkg::BYTES_PER_PIXEL;
    localparam int DONE_MAX_CYCLES = (PIXEL_WIDTH * params_pkg::BYTES_PER_PIXEL) - 1;
    localparam int MEM_CLEAR_MAX_CYCLES = (PIXEL_WIDTH * PIXEL_HEIGHT * params_pkg::BYTES_PER_PIXEL) + 2;
    logic clk;
    logic subcmd_enable;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] column;
    wire [_NUM_ROW_ADDRESS_BITS-1:0] row;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel;
    wire ram_write_enable;
    wire ram_access_start;
    logic done;
    wire pre_done;
    logic [_NUM_COLUMN_ADDRESS_BITS + _NUM_ROW_ADDRESS_BITS + _NUM_PIXELCOLORSELECT_BITS-1:0] addr;
    logic [MEMBITS-1:0] mem;
    logic [MEMBITS-1:0] valid_mask;
    wire [OUT_BITWIDTH-1:0] data_out;
    logic reset;

    control_subcmd_fillarea #(
        .PIXEL_WIDTH (PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT)
    ) subcmd_fillarea (
        .reset(reset),
        .enable(subcmd_enable),
        .clk(clk),
        .ack(done),
        .x1({_NUM_COLUMN_ADDRESS_BITS{1'b0}}),
        .y1({_NUM_ROW_ADDRESS_BITS{1'b0}}),
        .width((_NUM_COLUMN_ADDRESS_BITS)'(PIXEL_WIDTH)),
        .height((_NUM_ROW_ADDRESS_BITS)'(PIXEL_HEIGHT)),
        .color({(params_pkg::BYTES_PER_PIXEL * 8) {1'b0}}),
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
            if ((mask_idx & ((1 << _NUM_PIXELCOLORSELECT_BITS) - 1)) < params_pkg::BYTES_PER_PIXEL) begin
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

        // Walk rows from HEIGHT-1 down to 0; each row transition must happen within the expected byte-count window.
        for (int r = PIXEL_HEIGHT - 1; r >= 0; r = r - 1) begin
            `WAIT_ASSERT(clk, (row == (_NUM_ROW_ADDRESS_BITS)'(r)), ROW_ADVANCE_MAX_CYCLES)
            // First row should output zeroed color data (color input is all zeros).
            if (r == (PIXEL_HEIGHT - 1)) begin
                assert (data_out == 8'b0)
                else begin
                    $display("expected to see data_out as 0, but saw %d\n", data_out);
                    $stop;
                end
            end
        end
        // Done should assert once the final byte of the final pixel is written.
        `WAIT_ASSERT(clk, (pre_done == 1), DONE_MAX_CYCLES)
        // Handshake ack to let the DUT return to idle.
        @(posedge clk) done = 1;
        @(posedge clk) begin
            done = 0;
            subcmd_enable = 0;
        end
        // FSM should return to idle promptly after ack.
        `WAIT_ASSERT(clk, tb_control_subcmd_fillarea.subcmd_fillarea.state == 0, 1)
        // All valid memory bytes should be cleared to zero within the expected window.
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
