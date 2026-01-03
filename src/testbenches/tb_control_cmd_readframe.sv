// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_control_cmd_readframe;
    localparam int unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL;
    localparam real SIM_HALF_PERIOD_NS = 1.0;
    localparam int unsigned TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * BYTES_PER_PIXEL;

    // === Testbench scaffolding ===
    logic                          clk;
    logic                          reset;
    logic                          enable;
    logic                    [7:0] data_in;
    wire types::row_addr_t         row;
    wire types::col_addr_t         column;
    wire types::pixel_addr_t       pixel;
    wire                     [7:0] data_out;
    wire                           ram_write_enable;
    wire                           ram_access_start;
    wire                           done;
    byte                           expected_bytes   [TOTAL_BYTES];
    byte                           data_in_q;
    int                            payload_idx;
    int                            done_count;
    logic                          prev_as;

    // === DUT wiring ===
    control_cmd_readframe #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .enable(enable),
        .clk(clk),
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
        $dumpvars(0, tb_control_cmd_readframe);
        clk = 0;
        reset = 1;
        enable = 0;
        data_in = 0;
        for (int i = 0; i < TOTAL_BYTES; i++) expected_bytes[i] = byte'(i);
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        @(posedge clk);
        payload_idx = 0;
        done_count = 0;
        prev_as = 0;
        enable = 1;
        // Drive bytes on negedge so data_in is stable for the next posedge capture.
        for (int i = 0; i < TOTAL_BYTES; i++) begin
            @(negedge clk);
            data_in = expected_bytes[i];
        end
        @(posedge clk);
        @(negedge clk);
        enable = 0;
        repeat (5) @(posedge clk);
        `WAIT_ASSERT(clk, done_count == 1, 10)
        repeat (3) @(posedge clk);
        $finish;
    end

    // === Scoreboard / monitor ===
    // Each payload write must be in-range and toggle ram_access_start; data ordering is driven by DUT.
    task automatic expect_payload(input int idx, input byte b);
        assert (ram_write_enable == 1'b1)
        else $fatal(1, "WE low at idx %0d", idx);
        assert (int'(row) < params::PIXEL_HEIGHT && int'(column) < params::PIXEL_WIDTH && int'(pixel) < BYTES_PER_PIXEL)
        else $fatal(1, "Address out of range at idx %0d row=%0d col=%0d pix=%0d", idx, row, column, pixel);
        assert (ram_access_start != prev_as)
        else $fatal(1, "ram_access_start not toggling at idx %0d", idx);
        assert (data_out == b)
        else $fatal(1, "Payload mismatch at idx %0d expected=0x%0h got=0x%0h", idx, b, data_out);
    endtask

    always @(posedge clk) begin : monitor
        #0;
        if (reset) begin
            payload_idx <= 0;
            done_count <= 0;
            prev_as <= 0;
            data_in_q <= 8'h00;
        end else begin
            // Each payload write must be in-range and toggle ram_access_start; data ordering is driven by DUT.
            if (ram_write_enable && enable) begin
                assert (payload_idx < TOTAL_BYTES)
                else $fatal(1, "Payload idx out of range: %0d", payload_idx);
                assert (data_in == expected_bytes[payload_idx])
                else
                    $fatal(
                        1,
                        "Input mismatch at idx %0d expected=0x%0h got=0x%0h",
                        payload_idx,
                        expected_bytes[payload_idx],
                        data_in
                    );
                // data_out reflects the byte captured on the prior posedge.
                expect_payload(payload_idx, data_in_q);
                payload_idx <= payload_idx + 1;
            end
            if (done) done_count <= done_count + 1;
            prev_as <= ram_access_start;
            if (enable) data_in_q <= data_in;
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
