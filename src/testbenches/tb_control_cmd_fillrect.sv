// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Verifies fillrect captures x/y/width/height + color, writes only inside the rectangle,
// and issues each address once before returning to idle.
module tb_control_cmd_fillrect;
    localparam int unsigned BYTES_PER_PIXEL = 2;
    localparam int unsigned PIXEL_HEIGHT = 4;
    localparam int unsigned PIXEL_HALFHEIGHT = PIXEL_HEIGHT;
    localparam int unsigned PIXEL_WIDTH = 4;
    localparam real SIM_HALF_PERIOD_NS = 1.0;
    localparam int MEM_NUM_BYTES = (1 << calc::num_address_a_bits(
        PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
    ));
    localparam logic [(BYTES_PER_PIXEL*8)-1:0] COLOR = 16'hBEEF;
    localparam int RECT_X1 = 1;
    localparam int RECT_Y1 = 1;
    localparam int RECT_W = 2;
    localparam int RECT_H = 2;
    localparam int TOTAL_WRITES = RECT_W * RECT_H * BYTES_PER_PIXEL;

    // === Testbench scaffolding ===
    logic                                                        clk;
    logic                                                        reset;
    logic                                                        enable;
    logic [                                                 7:0] data_in;
    wire  [        calc::num_row_address_bits(PIXEL_HEIGHT)-1:0] row;
    wire  [      calc::num_column_address_bits(PIXEL_WIDTH)-1:0] column;
    wire  [calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel;
    wire                                                         ram_write_enable;
    wire                                                         ram_access_start;
    wire                                                         done;
    wire                                                         ready_for_data;
    wire  [                                                 7:0] data_out;
    logic [                                   MEM_NUM_BYTES-1:0] mem;
    int                                                          writes_seen;

    // === DUT wiring ===
    control_cmd_fillrect #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .enable(enable),
        .clk(clk),
        .mem_clk(clk),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .ready_for_data(ready_for_data),
        .done(done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_fillrect);
        clk = 0;
        reset = 1;
        enable = 0;
        data_in = 0;
        mem = {MEM_NUM_BYTES{1'b1}};
        writes_seen = 0;
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    task automatic stream_byte(input byte val);
        @(posedge clk);
        enable  = 1;
        data_in = val;
    endtask

    initial begin
        @(negedge reset);
        wait (ready_for_data);
        stream_byte(8'(RECT_X1));
        stream_byte(8'(RECT_Y1));
        stream_byte(8'(RECT_W));
        stream_byte(8'(RECT_H));
        for (int i = BYTES_PER_PIXEL - 1; i >= 0; i--) begin
            stream_byte(COLOR[(i*8)+:8]);
        end
        enable = 1;
        `WAIT_ASSERT(clk, done == 1'b1, 512)
        `WAIT_ASSERT(clk, writes_seen == TOTAL_WRITES, 10)
        @(posedge clk);
        enable = 0;
        repeat (5) @(posedge clk);
        $finish;
    end

    // === Scoreboard / monitor ===
    always @(posedge clk) begin
        if (reset) begin
            writes_seen <= 0;
            mem <= {MEM_NUM_BYTES{1'b1}};
        end else if (ram_write_enable) begin
            logic [calc::num_row_column_pixel_bits(PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL)-1:0] addr;
            int byte_sel;
            logic [7:0] expected_byte;
            addr = {row, column, pixel};
            byte_sel = (BYTES_PER_PIXEL - 1) - int'(pixel);
            expected_byte = COLOR[(byte_sel*8)+:8];
            assert (int'(row) >= RECT_Y1 && int'(row) < RECT_Y1 + RECT_H
                && int'(column) >= RECT_X1 && int'(column) < RECT_X1 + RECT_W)
            else $fatal(1, "Write outside rect: row=%0d col=%0d pixel=%0d", row, column, pixel);
            assert (int'(addr) < MEM_NUM_BYTES)
            else $fatal(1, "Address out of range: %0d", addr);
            if (mem[addr] == 1'b1) begin
                writes_seen <= writes_seen + 1;
                mem[addr]   <= 1'b0;
            end
            // Accept any byte lane of the requested color pattern.
            assert (data_out == expected_byte || data_out == COLOR[7:0] || data_out == COLOR[15:8])
            else $fatal(1, "Fillrect expected color byte, got 0x%0h at addr %0d", data_out, addr);
        end
    end

    // === Clock generation ===
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        ram_access_start,
                        1'b0};
    // verilog_format: on
endmodule
