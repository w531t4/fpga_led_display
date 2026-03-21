// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Small dual-clock FIFO used to decouple ingress/control timing domains.
//
// This is intentionally tiny and generic:
// - write side accepts short pulses in the source clock domain
// - read side presents the oldest entry and advances on rd_en
// - status crosses domains with Gray-coded pointers
//
// The memory is shallow on purpose; it is an elasticity buffer, not bulk
// storage. The point is to absorb a handful of in-flight bytes while keeping
// the slower consumer off the producer's timing path.
module async_fifo #(
    parameter int unsigned WIDTH = 8,
    parameter int unsigned DEPTH = 4,
    // verilator lint_off UNUSEDPARAM
    parameter int unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  logic             wr_clk,
    input  logic             wr_reset,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    input  logic             rd_clk,
    input  logic             rd_reset,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty
);
    localparam int unsigned ADDR_BITS = $clog2(DEPTH);
    localparam int unsigned PTR_BITS = ADDR_BITS + 1;

    logic [WIDTH-1:0] mem[DEPTH];

    logic [PTR_BITS-1:0] wr_bin;
    logic [PTR_BITS-1:0] wr_gray;
    logic [PTR_BITS-1:0] rd_bin;
    logic [PTR_BITS-1:0] rd_gray;

    logic [PTR_BITS-1:0] rd_gray_wr_sync1;
    logic [PTR_BITS-1:0] rd_gray_wr_sync2;
    logic [PTR_BITS-1:0] wr_gray_rd_sync1;
    logic [PTR_BITS-1:0] wr_gray_rd_sync2;

    function automatic logic [PTR_BITS-1:0] bin_to_gray(input logic [PTR_BITS-1:0] value);
        bin_to_gray = value ^ (value >> 1);
    endfunction

    wire [PTR_BITS-1:0] wr_bin_inc = wr_bin + PTR_BITS'(1);
    wire [PTR_BITS-1:0] wr_gray_inc = bin_to_gray(wr_bin_inc);
    wire [PTR_BITS-1:0] rd_bin_inc = rd_bin + PTR_BITS'(1);
    wire [PTR_BITS-1:0] rd_gray_inc = bin_to_gray(rd_bin_inc);

    assign full = (wr_gray_inc == {~rd_gray_wr_sync2[PTR_BITS-1:PTR_BITS-2], rd_gray_wr_sync2[PTR_BITS-3:0]});
    assign empty = (rd_gray == wr_gray_rd_sync2);

    // The read side samples the current head entry before rd_en advances rd_bin.
    assign rd_data = mem[rd_bin[ADDR_BITS-1:0]];

    always_ff @(posedge wr_clk) begin
        if (wr_reset) begin
            wr_bin <= '0;
            wr_gray <= '0;
            rd_gray_wr_sync1 <= '0;
            rd_gray_wr_sync2 <= '0;
        end else begin
            rd_gray_wr_sync1 <= rd_gray;
            rd_gray_wr_sync2 <= rd_gray_wr_sync1;

            if (wr_en && !full) begin
                mem[wr_bin[ADDR_BITS-1:0]] <= wr_data;
                wr_bin <= wr_bin_inc;
                wr_gray <= wr_gray_inc;
            end
        end
    end

    always_ff @(posedge rd_clk) begin
        if (rd_reset) begin
            rd_bin <= '0;
            rd_gray <= '0;
            wr_gray_rd_sync1 <= '0;
            wr_gray_rd_sync2 <= '0;
        end else begin
            wr_gray_rd_sync1 <= wr_gray;
            wr_gray_rd_sync2 <= wr_gray_rd_sync1;

            if (rd_en && !empty) begin
                rd_bin <= rd_bin_inc;
                rd_gray <= rd_gray_inc;
            end
        end
    end
endmodule
