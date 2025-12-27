// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
`include "tb_helper.vh"
module tb_control_subcmd_fillarea #(
    parameter int unsigned PIXEL_HALFHEIGHT = 2,
    parameter PIXEL_WIDTH = 4,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    // section to be removed in future once PIXEL_WIDTH is in params pkg
    // and we can safely include memcalcs
    localparam _NUM_DATA_A_BITS = 8;
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH);
    localparam _NUM_ROW_ADDRESS_BITS = $clog2(params_pkg::PIXEL_HEIGHT);
    localparam _NUM_PIXELCOLORSELECT_BITS = $clog2(params_pkg::BYTES_PER_PIXEL);
    localparam _NUM_SUBPANELS = params_pkg::PIXEL_HEIGHT / PIXEL_HALFHEIGHT;
    localparam _NUM_SUBPANELSELECT_BITS = $clog2(_NUM_SUBPANELS);
    localparam _NUM_ADDRESS_B_BITS = $clog2(PIXEL_HALFHEIGHT) + _NUM_COLUMN_ADDRESS_BITS;
    localparam _NUM_ADDRESS_A_BITS = _NUM_SUBPANELSELECT_BITS + _NUM_PIXELCOLORSELECT_BITS + _NUM_ADDRESS_B_BITS;
    // end section
    localparam int MEM_NUM_BYTES = (1 << _NUM_ADDRESS_A_BITS);
    localparam OUT_BITWIDTH = _NUM_DATA_A_BITS;
    localparam MEM_BITSIZE = MEM_NUM_BYTES * OUT_BITWIDTH;
    localparam int ROW_ADVANCE_MAX_CYCLES = PIXEL_WIDTH * params_pkg::BYTES_PER_PIXEL;
    localparam int DONE_MAX_CYCLES = (PIXEL_WIDTH * params_pkg::BYTES_PER_PIXEL) - 1;
    localparam int MEM_CLEAR_MAX_CYCLES = (PIXEL_WIDTH * params_pkg::PIXEL_HEIGHT * params_pkg::BYTES_PER_PIXEL) + 2;
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
    logic [MEM_BITSIZE-1:0] mem;
    logic [MEM_BITSIZE-1:0] valid_mask;
    int remaining_valid_bytes;
    wire [OUT_BITWIDTH-1:0] data_out;
    logic reset;

    control_subcmd_fillarea #(
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) subcmd_fillarea (
        .reset(reset),
        .enable(subcmd_enable),
        .clk(clk),
        .ack(done),
        .x1({_NUM_COLUMN_ADDRESS_BITS{1'b0}}),
        .y1({_NUM_ROW_ADDRESS_BITS{1'b0}}),
        .width((_NUM_COLUMN_ADDRESS_BITS)'(PIXEL_WIDTH)),
        .height((_NUM_ROW_ADDRESS_BITS)'(params_pkg::PIXEL_HEIGHT)),
        .color({(params_pkg::BYTES_PER_PIXEL * 8) {1'b0}}),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(pre_done)
    );

    // [row bits][column bits][pixel]
    // Take the tiny "pixel" chunk from the right end of idx.
    function automatic int unsigned mask_pixel_idx(input int unsigned idx);
        mask_pixel_idx = idx & ((1 << _NUM_PIXELCOLORSELECT_BITS) - 1);
    endfunction

    // Drop the pixel bits, then take the next chunk: the column number.
    function automatic int unsigned mask_col_idx(input int unsigned idx);
        mask_col_idx = (idx >> _NUM_PIXELCOLORSELECT_BITS) & ((1 << _NUM_COLUMN_ADDRESS_BITS) - 1);
    endfunction

    // Drop pixel + column bits; what's left is the row number.
    function automatic int unsigned mask_row_idx(input int unsigned idx);
        mask_row_idx = idx >> (_NUM_PIXELCOLORSELECT_BITS + _NUM_COLUMN_ADDRESS_BITS);
    endfunction

    initial begin : init_mask
        int mask_idx;
        int mask_row;
        int mask_col;
        int mask_pixel;
        valid_mask = '0;
        for (mask_idx = 0; mask_idx < MEM_NUM_BYTES; mask_idx = mask_idx + 1) begin
            mask_pixel = mask_pixel_idx(mask_idx);
            mask_col   = mask_col_idx(mask_idx);
            mask_row   = mask_row_idx(mask_idx);
            // Only mark real columns/rows; extra codes are padding.
            if (mask_pixel < params_pkg::BYTES_PER_PIXEL &&
                mask_col < PIXEL_WIDTH &&
                mask_row < params_pkg::PIXEL_HEIGHT) begin
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
        mem = {MEM_BITSIZE{1'b1}};
        remaining_valid_bytes = PIXEL_WIDTH * params_pkg::PIXEL_HEIGHT * params_pkg::BYTES_PER_PIXEL;
        subcmd_enable = 0;
        // finish reset for tb
        @(posedge clk) reset <= ~reset;

        @(posedge clk) begin
            subcmd_enable = 1;
        end
        @(posedge clk);

        // Walk rows from HEIGHT-1 down to 0; each row transition must happen within the expected byte-count window.
        for (int r = params_pkg::PIXEL_HEIGHT - 1; r >= 0; r = r - 1) begin
            `WAIT_ASSERT(clk, (row == (_NUM_ROW_ADDRESS_BITS)'(r)), ROW_ADVANCE_MAX_CYCLES)
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
        `WAIT_ASSERT(clk, (remaining_valid_bytes == 0), MEM_CLEAR_MAX_CYCLES)
        assert (|(mem & valid_mask) == 0)
        else begin
            $display("expected all valid bytes cleared, but found non-zero data\n");
            $stop;
        end

        repeat (5) begin
            @(posedge clk);
        end
        $finish;
    end
    always @(posedge clk) begin
        addr = {row, column, pixel};
        if (ram_write_enable && subcmd_enable) begin
            // $display("processing row=%0d col=%0d pixel=%0d", row, column, pixel);
            if (row >= params_pkg::PIXEL_HEIGHT || column >= PIXEL_WIDTH || pixel >= params_pkg::BYTES_PER_PIXEL) begin
                $display("out-of-range write: row=%0d col=%0d pixel=%0d", row, column, pixel);
                $stop;
            end else begin
                if (data_out != 8'b0) begin
                    $display("expected clear data_out==0, got %0d at row=%0d col=%0d pixel=%0d", data_out, row, column,
                             pixel);
                    $stop;
                end
                if (mem[((addr+1)*8)-1-:8] == 8'b0) begin
                    $display("duplicate clear write at row=%0d col=%0d pixel=%0d", row, column, pixel);
                    $stop;
                end
                remaining_valid_bytes  <= remaining_valid_bytes - 1;
                mem[((addr+1)*8)-1-:8] <= data_out[7:0];
            end
        end
    end
    always begin
        #2 clk <= !clk;
    end
endmodule
