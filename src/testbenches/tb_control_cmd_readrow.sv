// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_control_cmd_readrow #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    `include "row4.svh"
    localparam int unsigned CLK_DIV_VALUE = 16;
    localparam int unsigned STREAM_BITCOUNT = $bits(cmd_readrow) - $bits(cmd::opcode_t);  // row selector + data payload

    localparam int unsigned STREAM_BYTECOUNT = calc::num_bytes_to_contain(STREAM_BITCOUNT);
    localparam int unsigned STREAM_TIMEOUT_CYCLES = STREAM_BYTECOUNT * (CLK_DIV_VALUE * 4);

    // verilog_format: off
    types::readrow_cmd_t cmd_readrow_local;
    // verilog_format: on
    // === Testbench scaffolding ===
    wire                                                             slowclk;
    logic                                                            clk;
    wire                                                             subcmd_enable;
    logic [                                                     7:0] data_in;
    logic                                                            reset;
    logic                                                            finished;
    wire                                                             cmd_readrow_we;
    wire                                                             cmd_readrow_as;
    wire                                                             cmd_readrow_done;
    wire  [                                                     7:0] cmd_readrow_do;
    wire types::fb_addr_t                                            cmd_readrow_addr;
    logic                                                            junk1;
    logic [                                                     7:0] expected_bytes         [STREAM_BYTECOUNT];
    int                                                              enable_count;
    int                                                              data_count;
    int                                                              done_count;
    logic [                                                     7:0] last_enable_byte;
    int                                                              last_enable_idx;
    int                                                              last_data_idx;
    logic                                                            last_enable_pulse;
    logic                                                            prev_ram_as;
    logic                                                            expect_cleanup;

    // === DUT wiring ===
    clock_divider #(
        .CLK_DIV_COUNT(CLK_DIV_VALUE)
    ) clock_divider_instance (
        .reset  (reset),
        .clk_in (clk),
        .clk_out(slowclk)
    );

    ff_sync #() ff_sync_instance (
        .clk(clk),
        .signal(slowclk),
        .sync_level(junk1),
        .sync_pulse(subcmd_enable),
        .reset(reset)
    );

    control_cmd_readrow #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(subcmd_enable & finished),
        .addr(cmd_readrow_addr),
        .data_out(cmd_readrow_do),
        .ram_write_enable(cmd_readrow_we),
        .ram_access_start(cmd_readrow_as),
        .done(cmd_readrow_done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readrow);
        cmd_readrow_local = cmd_readrow;
        clk = 0;
        reset = 1;
        finished = 1;
        data_in = 8'b0;
        for (int __i = 0; __i < STREAM_BYTECOUNT; __i++) begin
            expected_bytes[__i] = cmd_readrow_local[STREAM_BITCOUNT-1-(__i*8)-:8];
        end
        // finish reset for tb
        @(posedge clk) @(posedge clk) reset = ~reset;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        `WAIT_ASSERT(clk,
                     (cmd_readrow_addr.row == '0 && cmd_readrow_addr.col == '0 && cmd_readrow_addr.pixel == '0
                         && cmd_readrow_do == '0 && cmd_readrow_we == 1'b0 && cmd_readrow_done == 1'b0),
                     1);

        // Stream two rows back-to-back to ensure the FSM returns to capture cleanly.
        `STREAM_COMMAND_MSB(slowclk, data_in, cmd_readrow_local)
        `STREAM_COMMAND_MSB(slowclk, data_in, cmd_readrow_local)
        @(posedge slowclk);
        `WAIT_ASSERT(clk, (done_count == 2), STREAM_TIMEOUT_CYCLES);
        finished = 0;
        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end

    // === Scoreboard / monitor ===
    // Task helpers to keep the scoreboard readable.
    task automatic expect_row_capture(input types::row_addr_t sel_bits);
        assert (cmd_readrow_addr.row == sel_bits)
        else $fatal(1, "Row latch mismatch: expected %0d, got %0d", sel_bits, cmd_readrow_addr.row);
        assert (cmd_readrow_we == 1'b0 && cmd_readrow_do == 8'b0)
        else $fatal(1, "Unexpected write/data during row capture");
    endtask
    task automatic expect_data_payload(input int byte_idx, input logic [7:0] data_byte, input int exp_col,
                                       input int exp_pix);
        assert (cmd_readrow_we == 1'b1)
        else $fatal(1, "ram_write_enable deasserted during data transfer at byte %0d", byte_idx);
        assert (cmd_readrow_do == data_byte)
        else $fatal(1, "Data mismatch at byte %0d: expected 0x%0h got 0x%0h", byte_idx, data_byte, cmd_readrow_do);
        assert (cmd_readrow_addr.col == types::col_addr_t'(exp_col))
        else $fatal(1, "Column mismatch at byte %0d: expected %0d got %0d", byte_idx, exp_col, cmd_readrow_addr.col);
        assert (cmd_readrow_addr.pixel == types::pixel_addr_t'(exp_pix))
        else $fatal(1, "Pixel mismatch at byte %0d: expected %0d got %0d", byte_idx, exp_pix, cmd_readrow_addr.pixel);
        assert (cmd_readrow_as != prev_ram_as)
        else $fatal(1, "ram_access_start failed to toggle at byte %0d", byte_idx);
    endtask
    task automatic expect_idle_cleanup();
        assert (cmd_readrow_we == 1'b0 && cmd_readrow_do == 8'b0)
        else $fatal(1, "Outputs not cleared after done");
    endtask
    always @(posedge clk) begin
        if (reset) begin
            enable_count      <= 0;
            data_count        <= 0;
            done_count        <= 0;
            last_enable_byte  <= '0;
            last_enable_idx   <= 0;
            last_data_idx     <= -1;
            last_enable_pulse <= 1'b0;
            prev_ram_as       <= 1'b0;
            expect_cleanup    <= 1'b0;
        end else begin
            int next_enable_count;
            int next_data_count;
            next_enable_count = enable_count;
            next_data_count   = data_count;
            // Check the effects of the previous enable pulse (sampled one cycle ago).
            if (last_enable_pulse) begin
                if (last_enable_idx == 0) begin
                    expect_row_capture(types::row_addr_t'(last_enable_byte));
                end else begin
                    int exp_col;
                    int exp_pix;
                    exp_col = params::PIXEL_WIDTH - 1 - (last_data_idx / params::BYTES_PER_PIXEL);
                    exp_pix = params::BYTES_PER_PIXEL - 1 - (last_data_idx % params::BYTES_PER_PIXEL);
                    expect_data_payload(last_data_idx, last_enable_byte, exp_col, exp_pix);
                end
            end

            // Confirm cleanup right after a done pulse.
            if (expect_cleanup) begin
                expect_cleanup <= 1'b0;
                expect_idle_cleanup();
            end

            // Track new enable pulse for checking on the next cycle.
            if (subcmd_enable && finished) begin
                last_enable_pulse <= 1'b1;
                last_enable_byte  <= data_in;
                last_enable_idx   <= enable_count;
                last_data_idx     <= (enable_count == 0) ? -1 : data_count;
                assert (enable_count < STREAM_BYTECOUNT)
                else
                    $fatal(
                        1, "Stream length exceeded: enable_count=%0d expected max %0d", enable_count, STREAM_BYTECOUNT
                    );
                assert (data_in == expected_bytes[enable_count])
                else
                    $fatal(
                        1,
                        "Unexpected byte %0d: saw 0x%0h expected 0x%0h",
                        enable_count,
                        data_in,
                        expected_bytes[enable_count]
                    );
                next_enable_count = enable_count + 1;
                if (enable_count > 0) next_data_count = data_count + 1;
            end else begin
                last_enable_pulse <= 1'b0;
            end

            if (cmd_readrow_done) begin
                done_count <= done_count + 1;
                assert (next_data_count == calc::num_bytes_to_contain($bits(cmd_readrow_local.data)))
                else
                    $fatal(
                        1,
                        "Done asserted after %0d data bytes, expected %0d",
                        next_data_count,
                        calc::num_bytes_to_contain(
                            $bits(cmd_readrow_local.data)
                        )
                    );
                expect_cleanup <= 1'b1;
                next_enable_count = 0;
                next_data_count   = 0;
            end

            enable_count <= next_enable_count;
            data_count   <= next_data_count;
            prev_ram_as  <= cmd_readrow_as;
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        cmd_readrow_we,
                        cmd_readrow_as,
                        cmd_readrow_done,
                        cmd_readrow_do,
                        cmd_readrow_addr,
                        cmd_series,
                        junk1,
                        1'b0};
    // verilog_format: on
endmodule
