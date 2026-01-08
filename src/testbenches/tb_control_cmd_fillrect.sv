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
    localparam int MEM_NUM_BYTES = (1 << $bits(types::mem_write_addr_t));
`ifdef RGB24
    localparam types::color_field_t COLOR = types::color_field_t'(24'hBEEF42);
`else
    localparam types::color_field_t COLOR = types::color_field_t'(16'hBEEF);
`endif
    localparam int RECT_X1 = 1;
    localparam int RECT_Y1 = 1;
    localparam int RECT_W = 2;
    localparam int RECT_H = 2;
    localparam int TOTAL_WRITES = RECT_W * RECT_H * params::BYTES_PER_PIXEL;

    // === Testbench scaffolding ===
    logic                                     clk;
    logic                                     reset;
    logic                                     enable;
    logic                 [              7:0] data_in;
    wire types::fb_addr_t                     addr;
    wire                                      ram_write_enable;
    wire                                      ram_access_start;
    wire                                      done;
    wire                                      ready_for_data;
    wire                  [              7:0] data_out;
    logic                 [MEM_NUM_BYTES-1:0] mem;
    int                                       writes_seen;

    // === DUT wiring ===
    control_cmd_fillrect #() dut (
        .reset(reset),
        .data_in(data_in),
        .enable(enable),
        .clk(clk),
        .mem_clk(clk),
        .addr(addr),
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
        // verilator lint_off WIDTHCONCAT
        mem = {MEM_NUM_BYTES{1'b1}};
        // verilator lint_on WIDTHCONCAT
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
        for (int i = params::BYTES_PER_PIXEL - 1; i >= 0; i--) begin
            stream_byte(COLOR.bytes[i]);
        end
        wait (!ready_for_data);
        @(posedge clk);
        enable = 0;
        if (dut.selected_color != COLOR)
            $fatal(1, "Fillrect captured color mismatch: saw 0x%0h expected 0x%0h", dut.selected_color, COLOR);
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
            // verilator lint_off WIDTHCONCAT
            mem <= {MEM_NUM_BYTES{1'b1}};
            // verilator lint_on WIDTHCONCAT
        end else if (ram_write_enable) begin
            logic [7:0] expected_byte;
            expected_byte = COLOR.bytes[addr.pixel];
            assert (types::uint_t'(addr.row) >= RECT_Y1
                && types::uint_t'(addr.row) < RECT_Y1 + RECT_H
                && types::uint_t'(addr.col) >= RECT_X1
                && types::uint_t'(addr.col) < RECT_X1 + RECT_W)
            else $fatal(1, "Write outside rect: row=%0d col=%0d pixel=%0d", addr.row, addr.col, addr.pixel);
            assert (types::uint_t'(addr) < MEM_NUM_BYTES)
            else $fatal(1, "Address out of range: %0d", addr);
            if (mem[addr] == 1'b1) begin
                writes_seen <= writes_seen + 1;
                mem[addr]   <= 1'b0;
            end
            assert (data_out == expected_byte)
            else
                $fatal(
                    1,
                    "Fillrect expected 0x%0h got 0x%0h row=%0d col=%0d pix=%0d addr=%0d",
                    expected_byte,
                    data_out,
                    addr.row,
                    addr.col,
                    addr.pixel,
                    addr
                );
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        ram_access_start,
                        1'b0};
    // verilog_format: on
endmodule
