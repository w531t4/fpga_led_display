// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"
// Self-checking subcmd_fillarea: runs twice (zero fill + pattern fill) and
// verifies every valid byte is written exactly once with the expected color,
// rows advance in order, done/ack handoff completes, and the FSM returns idle.
module tb_control_subcmd_fillarea #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params::PIXEL_HALFHEIGHT,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    // Local parameters grouped for easy reference
    localparam int MEM_NUM_BYTES = (1 << calc::num_address_a_bits(
        PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
    ));
    localparam integer unsigned OUT_BITWIDTH = calc::num_data_a_bits();
    localparam int ROW_ADVANCE_MAX_CYCLES = PIXEL_WIDTH * BYTES_PER_PIXEL;
    localparam int DONE_MAX_CYCLES = (PIXEL_WIDTH * BYTES_PER_PIXEL) - 1;
    localparam int MEM_CLEAR_MAX_CYCLES = (PIXEL_WIDTH * PIXEL_HEIGHT * BYTES_PER_PIXEL) + 2;
    localparam logic [(BYTES_PER_PIXEL*8)-1:0] COLOR_ZERO = {(BYTES_PER_PIXEL * 8) {1'b0}};
    localparam logic [(BYTES_PER_PIXEL*8)-1:0] COLOR_ALT = {BYTES_PER_PIXEL{8'hA5}};

    // === Testbench scaffolding ===
    logic clk;
    logic subcmd_enable;
    wire types::col_addr_t column;
    wire types::row_addr_t row;
    wire [calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel;
    wire ram_write_enable;
    wire ram_access_start;
    logic done;
    wire pre_done;
    logic [calc::num_row_column_pixel_bits(PIXEL_HEIGHT, PIXEL_WIDTH, BYTES_PER_PIXEL)-1:0] addr;
    logic [MEM_NUM_BYTES-1:0] mem;
    logic [MEM_NUM_BYTES-1:0] valid_mask;
    int remaining_valid_bytes;
    wire [OUT_BITWIDTH-1:0] data_out;
    logic reset;
    logic [(BYTES_PER_PIXEL*8)-1:0] color_in;

    // === DUT wiring ===
    control_subcmd_fillarea #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        ._UNUSED('d0)
    ) subcmd_fillarea (
        .reset(reset),
        .enable(subcmd_enable),
        .clk(clk),
        .ack(done),
        .x1(types::col_addr_t'(0)),
        .y1(types::row_addr_t'(0)),
        .width(types::col_addr_t'(PIXEL_WIDTH)),
        .height(types::row_addr_t'(PIXEL_HEIGHT)),
        .color(color_in),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(pre_done)
    );

    // === Init ===
    // [row bits][column bits][pixel]
    // Take the tiny "pixel" chunk from the right end of idx.
    function automatic int unsigned mask_pixel_idx(input int unsigned idx);
        mask_pixel_idx = idx & ((1 << calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)) - 1);
    endfunction

    // Drop the pixel bits, then take the next chunk: the column number.
    function automatic int unsigned mask_col_idx(input int unsigned idx);
        mask_col_idx = (idx >> calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)) &
            ((1 << $bits(types::col_addr_t)) - 1);
    endfunction

    // Drop pixel + column bits; what's left is the row number.
    function automatic int unsigned mask_row_idx(input int unsigned idx);
        mask_row_idx = idx >> (calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL) + $bits(types::col_addr_t));
    endfunction

    // We build a mask of bits representing where each byte written by the
    // module is rep. by a single bit
    //
    // Based on the configuration of width/height/subdisplays, our addressing
    // schema may have areas of memory that are unused..
    //
    // The following section determines which sections are valid (so we don't waste time)
    // working on unused area.
    initial begin : init_mask
        int mask_idx;
        int mask_row;
        int mask_col;
        int mask_pixel;
        // verilator lint_off WIDTHCONCAT
        valid_mask = '0;
        // verilator lint_on WIDTHCONCAT
        for (mask_idx = 0; mask_idx < MEM_NUM_BYTES; mask_idx = mask_idx + 1) begin
            mask_pixel = mask_pixel_idx(mask_idx);
            mask_col   = mask_col_idx(mask_idx);
            mask_row   = mask_row_idx(mask_idx);
            // Only mark real columns/rows; extra codes are padding.
            if (mask_pixel < BYTES_PER_PIXEL && mask_col < PIXEL_WIDTH && mask_row < PIXEL_HEIGHT) begin
                valid_mask[mask_idx] = 1'b1;
            end
        end
    end
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_subcmd_fillarea);
        clk = 0;
    end

    // === Stimulus ===
    // Drive a full-frame fill with the provided color and assert correctness/timing.
    task automatic run_fill(input logic [(BYTES_PER_PIXEL*8)-1:0] color_bytes);
        // Reset DUT and scoreboard state for each fill.
        done = 0;
        reset = 1;
        addr = '0;
        color_in = color_bytes;
        // verilator lint_off WIDTHCONCAT
        mem = {MEM_NUM_BYTES{1'b1}};
        // verilator lint_on WIDTHCONCAT
        remaining_valid_bytes = PIXEL_WIDTH * PIXEL_HEIGHT * BYTES_PER_PIXEL;
        subcmd_enable = 0;
        @(posedge clk);
        @(posedge clk) reset = 0;

        @(posedge clk) begin
            subcmd_enable = 1;
        end
        @(posedge clk);

        // Walk rows from HEIGHT-1 down to 0; each row transition must happen within the expected byte-count window.
        for (int r = PIXEL_HEIGHT - 1; r >= 0; r = r - 1) begin
            `WAIT_ASSERT(clk, (row == types::row_addr_t'(r)), ROW_ADVANCE_MAX_CYCLES)
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
    endtask
    initial begin
        // First, clear to zero.
        run_fill(COLOR_ZERO);
        // Then fill with a non-zero pattern to confirm arbitrary data works.
        run_fill(COLOR_ALT);
        repeat (5) begin
            @(posedge clk);
        end
        $finish;
    end

    // === Scoreboard / monitor ===
    always @(posedge clk) begin
        addr <= {row, column, pixel};
        if (ram_write_enable && subcmd_enable) begin
            // Each write must be in-range, unique, and match the requested color byte for that pixel lane.
            if (types::uint_t'(row) >= PIXEL_HEIGHT || types::uint_t'(column) >= PIXEL_WIDTH || types::uint_t'(pixel) >= BYTES_PER_PIXEL) begin
                $display("out-of-range write: row=%0d col=%0d pixel=%0d", row, column, pixel);
                $stop;
            end else begin
                if (data_out != color_in[(((32)'(pixel)+1)*8)-1-:8]) begin
                    $display("expected data_out=0x%0h, got 0x%0h at row=%0d col=%0d pixel=%0d",
                             color_in[(((32)'(pixel)+1)*8)-1-:8], data_out, row, column, pixel);
                    $stop;
                end
                if (mem[addr] == 1'b0) begin
                    $display("duplicate clear write at row=%0d col=%0d pixel=%0d", row, column, pixel);
                    $stop;
                end
                remaining_valid_bytes <= remaining_valid_bytes - 1;
                mem[addr] <= 1'b0;
            end
        end
    end

    // === Clock generation ===
    always begin
        #2 clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        ram_access_start,
                        1'b0};
    // verilog_format: on
endmodule
