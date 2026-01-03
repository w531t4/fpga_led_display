// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Ensures blankpanel drives a full-frame clear: every address written once with zero data,
// done pulses, and the FSM returns idle.
module tb_control_cmd_blankpanel;
    localparam int unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL;
    localparam int unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT;
    localparam real SIM_HALF_PERIOD_NS = 1.0;
    localparam int MEM_NUM_BYTES = (1 << $bits(types::mem_write_addr_t));
    localparam int TOTAL_WRITES = params::PIXEL_WIDTH * PIXEL_HEIGHT * BYTES_PER_PIXEL;

    // === Testbench scaffolding ===
    logic                                        clk;
    logic                                        reset;
    logic                                        enable;
    wire types::row_addr_t                       row;
    wire types::col_addr_t                       column;
    wire types::pixel_addr_t                     pixel;
    wire                                         ram_write_enable;
    wire                                         ram_access_start;
    wire                                         done;
    wire                     [              7:0] data_out;
    logic                    [MEM_NUM_BYTES-1:0] mem;
    int                                          writes_seen;

    // === DUT wiring ===
    control_cmd_blankpanel #(
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .enable(enable),
        .clk(clk),
        .mem_clk(clk),
        .row(row),
        .column(column),
        .pixel(pixel),
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
        $dumpvars(0, tb_control_cmd_blankpanel);
        clk = 0;
        reset = 1;
        enable = 0;
        // verilator lint_off WIDTHCONCAT
        mem = {MEM_NUM_BYTES{1'b1}};
        // verilator lint_on WIDTHCONCAT
        writes_seen = 0;
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        enable = 1;
        // Drive a single transaction; all writes and done should occur within a small window.
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
            types::fb_addr_t addr;
            addr = {row, column, pixel};
            assert (int'(addr) < MEM_NUM_BYTES)
            else $fatal(1, "Address out of range: %0d", addr);
            assert (mem[addr] == 1'b1)
            else $fatal(1, "Duplicate write detected at %0d", addr);
            mem[addr]   <= 1'b0;
            writes_seen <= writes_seen + 1;
            assert (data_out == 8'b0)
            else $fatal(1, "Blankpanel expected zero data, got %0h", data_out);
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
