// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Streams a readrect header + payload and checks row/col/pixel traversal plus data ordering.
module tb_control_cmd_readrect;
    localparam int unsigned RECT_X1 = 2;
    localparam int unsigned RECT_Y1 = 1;
    localparam int unsigned RECT_W = 3;
    localparam int unsigned RECT_H = 2;
    localparam int unsigned TOTAL_WRITES = RECT_W * RECT_H * params::BYTES_PER_PIXEL;
    localparam int unsigned NUM_COL_BYTES = calc::num_bytes_to_contain($bits(types::col_addr_t));
    // === Testbench scaffolding ===
    logic clk;
    logic reset;
    logic enable;
    logic [7:0] data_in;
    wire types::fb_addr_t addr;
    wire [7:0] data_out;
    wire ram_write_enable;
    wire ram_access_start;
    wire done;
    byte data_in_q;
    int payload_idx;
    int done_count;
    logic prev_as;

    // === DUT wiring ===
    control_cmd_readrect #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .enable(enable),
        .clk(clk),
        .addr(addr),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readrect);
        clk = 0;
        reset = 1;
        enable = 0;
        data_in = 8'b0;
        payload_idx = 0;
        done_count = 0;
        prev_as = 0;
        data_in_q = 8'h00;
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    // Drive each byte on negedge so it is stable for the next posedge capture.
    task automatic stream_byte(input byte val);
        @(negedge clk);
        data_in = val;
        enable = 1'b1;
    endtask

    initial begin
        types::col_addr_field_t x1_field;
        types::col_addr_field_t width_field;
        @(negedge reset);
        x1_field = types::col_addr_field_t'(RECT_X1);
        width_field = types::col_addr_field_t'(RECT_W);
        // Header: x1 (big endian), y1, width (big endian), height.
        for (int i = 0; i < NUM_COL_BYTES; i++) begin
            stream_byte(x1_field.bytes[(NUM_COL_BYTES - 1) - i]);
        end
        stream_byte(byte'(RECT_Y1));
        for (int i = 0; i < NUM_COL_BYTES; i++) begin
            stream_byte(width_field.bytes[(NUM_COL_BYTES - 1) - i]);
        end
        stream_byte(byte'(RECT_H));
        // Payload: sequential bytes for the rectangle.
        for (int i = 0; i < TOTAL_WRITES; i++) begin
            stream_byte(byte'(i));
        end
        @(posedge clk);
        @(negedge clk);
        enable = 0;
        `WAIT_ASSERT(clk, done_count == 1, 512)
        `WAIT_ASSERT(clk, payload_idx == TOTAL_WRITES, 512)
        repeat (3) @(posedge clk);
        $finish;
    end

    // === Scoreboard / monitor ===
    // Each payload write must map to the expected row/col/pixel and toggle ram_access_start.
    task automatic expect_payload(input int idx, input byte payload_byte);
        int pixel_idx;
        int exp_row;
        int exp_col;
        int exp_pix;
        assert (ram_write_enable == 1'b1)
        else $fatal(1, "ram_write_enable low at idx %0d", idx);
        assert (ram_access_start != prev_as)
        else $fatal(1, "ram_access_start not toggling at idx %0d", idx);
        pixel_idx = idx / params::BYTES_PER_PIXEL;
        exp_row = RECT_Y1 + (pixel_idx / RECT_W);
        exp_col = RECT_X1 + (pixel_idx % RECT_W);
        exp_pix = params::BYTES_PER_PIXEL - 1 - (idx % params::BYTES_PER_PIXEL);
        assert (addr.row == types::row_addr_t'(exp_row))
        else $fatal(1, "Row mismatch at idx %0d: expected %0d got %0d", idx, exp_row, addr.row);
        assert (addr.col == types::col_addr_t'(exp_col))
        else $fatal(1, "Column mismatch at idx %0d: expected %0d got %0d", idx, exp_col, addr.col);
        assert (addr.pixel == types::pixel_addr_t'(exp_pix))
        else $fatal(1, "Pixel mismatch at idx %0d: expected %0d got %0d", idx, exp_pix, addr.pixel);
        assert (data_out == payload_byte)
        else $fatal(1, "Payload mismatch at idx %0d: expected 0x%0h got 0x%0h", idx, payload_byte, data_out);
    endtask

    always @(posedge clk) begin : monitor
        int next_payload_idx;
        #0;
        next_payload_idx = payload_idx;
        if (reset) begin
            payload_idx <= 0;
            done_count <= 0;
            prev_as <= 0;
            data_in_q <= 8'h00;
        end else begin
            if (ram_write_enable && (ram_access_start != prev_as)) begin
                expect_payload(payload_idx, data_in_q);
                next_payload_idx = payload_idx + 1;
            end
            if (done) begin
                done_count <= done_count + 1;
            end
            prev_as <= ram_access_start;
            if (enable) data_in_q <= data_in;
            payload_idx <= next_payload_idx;
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        1'b0};
    // verilog_format: on
endmodule
