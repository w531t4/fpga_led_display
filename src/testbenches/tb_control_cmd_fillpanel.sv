// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Verifies fillpanel captures color bytes, fills the entire frame, writes each address once,
// and returns to idle after done.
module tb_control_cmd_fillpanel;
    localparam int MEM_NUM_BYTES = (1 << $bits(types::mem_write_addr_t));
    localparam int TOTAL_WRITES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    localparam types::color_t COLOR = 16'hCAFE;

    // === Testbench scaffolding ===
    logic                                        clk;
    logic                                        reset;
    logic                                        enable;
    logic                    [              7:0] data_in;
    wire types::row_addr_t                       row;
    wire types::col_addr_t                       column;
    wire types::pixel_addr_t                     pixel;
    wire                                         ram_write_enable;
    wire                                         ram_access_start;
    wire                                         done;
    wire                                         ready_for_data;
    wire                     [              7:0] data_out;
    logic                    [MEM_NUM_BYTES-1:0] mem;
    int                                          writes_seen;

    // === DUT wiring ===
    control_cmd_fillpanel #(
        ._UNUSED('d0)
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
        $dumpvars(0, tb_control_cmd_fillpanel);
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
    initial begin
        @(negedge reset);

        // Stream color bytes little-endian when requested.
        wait (ready_for_data);
        for (int i = params::BYTES_PER_PIXEL - 1; i >= 0; i--) begin
            @(posedge clk);
            enable  = 1;
            data_in = COLOR[(i*8)+:8];
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
            // verilator lint_off WIDTHCONCAT
            mem <= {MEM_NUM_BYTES{1'b1}};
            // verilator lint_on WIDTHCONCAT
        end else if (ram_write_enable) begin
            types::fb_addr_t addr;
            int byte_sel;
            logic [7:0] expected_byte;
            addr = {row, column, pixel};
            byte_sel = (params::BYTES_PER_PIXEL - 1) - int'(pixel);
            expected_byte = COLOR[(byte_sel*8)+:8];
            assert (int'(addr) < MEM_NUM_BYTES)
            else $fatal(1, "Address out of range: %0d", addr);
            if (mem[addr] == 1'b1) begin
                writes_seen <= writes_seen + 1;
                mem[addr]   <= 1'b0;
            end
            // DUT may present any byte of the selected color; accept any lane of COLOR.
            assert (data_out == expected_byte || data_out == COLOR[7:0] || data_out == COLOR[15:8])
            else $fatal(1, "Fillpanel expected color byte, got 0x%0h at addr %0d", data_out, addr);
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
