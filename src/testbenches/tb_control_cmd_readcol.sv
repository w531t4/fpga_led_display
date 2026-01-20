// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_control_cmd_readcol #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int unsigned CLK_DIV_VALUE = 16;
    localparam int unsigned COLUMN_DATA_BYTES = params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    localparam logic [7:0] TEST_DATA_BYTE = 8'hA5;
    localparam types::col_addr_t TEST_COLUMN = types::col_addr_t'(params::PIXEL_WIDTH / 2);
    localparam types::column_data_t COLUMN_PAYLOAD = {COLUMN_DATA_BYTES{TEST_DATA_BYTE}};
    localparam types::readcol_cmd_t CMD_READCOL = types::readcol_cmd_t'({
        cmd::READCOL, types::col_addr_field_t'(TEST_COLUMN), types::column_data_field_t'(COLUMN_PAYLOAD)
    });

    localparam int unsigned STREAM_BITCOUNT = $bits(CMD_READCOL) - $bits(cmd::opcode_t);
    localparam int unsigned STREAM_BYTECOUNT = calc::num_bytes_to_contain(STREAM_BITCOUNT);
    localparam int unsigned STREAM_TIMEOUT_CYCLES = STREAM_BYTECOUNT * (CLK_DIV_VALUE * 4);
    localparam int unsigned COL_BYTES = calc::num_bytes_to_contain($bits(types::col_addr_t));

    types::readcol_cmd_t cmd_readcol_local;
    // === Testbench scaffolding ===
    wire                  slowclk;
    logic                 clk;
    wire                  subcmd_enable;
    logic           [7:0] data_in;
    logic                 reset;
    logic                 finished;
    wire                  cmd_readcol_we;
    wire                  cmd_readcol_as;
    wire                  cmd_readcol_done;
    wire            [7:0] cmd_readcol_do;
    wire types::fb_addr_t addr;
    logic                 sync_level_unused;
    logic           [7:0] expected_bytes[STREAM_BYTECOUNT];
    int                   enable_count;
    int                   data_count;
    int                   done_count;
    logic           [7:0] last_enable_byte;
    int                   last_enable_idx;
    int                   last_data_idx;
    logic                 last_enable_pulse;
    logic                 prev_ram_as;
    logic                 expect_cleanup;

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
        .sync_level(sync_level_unused),
        .sync_pulse(subcmd_enable),
        .reset(reset)
    );

    control_cmd_readcol #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(subcmd_enable & finished),
        .addr(addr),
        .data_out(cmd_readcol_do),
        .ram_write_enable(cmd_readcol_we),
        .ram_access_start(cmd_readcol_as),
        .done(cmd_readcol_done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readcol);
        cmd_readcol_local = CMD_READCOL;
        clk = 0;
        reset = 1;
        finished = 1;
        data_in = 8'b0;
        for (int __i = 0; __i < STREAM_BYTECOUNT; __i++) begin
            expected_bytes[__i] = cmd_readcol_local[STREAM_BITCOUNT-1-(__i*8)-:8];
        end
        // finish reset for tb
        @(posedge clk) @(posedge clk) reset = ~reset;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        `WAIT_ASSERT(clk,
                     (addr.row == '0 && addr.col == '0 && addr.pixel == '0
                         && cmd_readcol_do == '0 && cmd_readcol_we == 1'b0 && cmd_readcol_done == 1'b0),
                     1);

        // Stream two columns back-to-back to confirm the FSM returns to capture cleanly.
        `STREAM_COMMAND_MSB(slowclk, data_in, cmd_readcol_local)
        `STREAM_COMMAND_MSB(slowclk, data_in, cmd_readcol_local)
        @(posedge slowclk);
        `WAIT_ASSERT(clk, (done_count == 2), STREAM_TIMEOUT_CYCLES);
        finished = 0;
        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end

    // === Scoreboard / monitor ===
    // Capture helper checks to keep the scoreboard readable.
    task automatic expect_column_capture();
        assert (cmd_readcol_we == 1'b0 && cmd_readcol_do == 8'b0)
        else $fatal(1, "Unexpected write/data during column capture");
    endtask
    task automatic expect_data_payload(input int byte_idx, input logic [7:0] data_byte, input int exp_row,
                                       input int exp_pix);
        assert (cmd_readcol_we == 1'b1)
        else $fatal(1, "ram_write_enable deasserted during data transfer at byte %0d", byte_idx);
        assert (cmd_readcol_do == data_byte)
        else $fatal(1, "Data mismatch at byte %0d: expected 0x%0h got 0x%0h", byte_idx, data_byte, cmd_readcol_do);
        assert (addr.row == types::row_addr_t'(exp_row))
        else $fatal(1, "Row mismatch at byte %0d: expected %0d got %0d", byte_idx, exp_row, addr.row);
        assert (addr.col == TEST_COLUMN)
        else $fatal(1, "Column mismatch at byte %0d: expected %0d got %0d", byte_idx, TEST_COLUMN, addr.col);
        assert (addr.pixel == types::pixel_addr_t'(exp_pix))
        else $fatal(1, "Pixel mismatch at byte %0d: expected %0d got %0d", byte_idx, exp_pix, addr.pixel);
        assert (cmd_readcol_as != prev_ram_as)
        else $fatal(1, "ram_access_start failed to toggle at byte %0d", byte_idx);
    endtask
    task automatic expect_idle_cleanup();
        assert (cmd_readcol_we == 1'b0 && cmd_readcol_do == 8'b0)
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
                if (last_enable_idx < COL_BYTES) begin
                    expect_column_capture();
                end else begin
                    int exp_row;
                    int exp_pix;
                    exp_row = last_data_idx / params::BYTES_PER_PIXEL;
                    exp_pix = params::BYTES_PER_PIXEL - 1 - (last_data_idx % params::BYTES_PER_PIXEL);
                    expect_data_payload(last_data_idx, last_enable_byte, exp_row, exp_pix);
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
                last_data_idx     <= (enable_count < COL_BYTES) ? -1 : data_count;
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
                if (enable_count >= COL_BYTES) next_data_count = data_count + 1;
            end else begin
                last_enable_pulse <= 1'b0;
            end

            if (cmd_readcol_done) begin
                done_count <= done_count + 1;
                assert (next_data_count == COLUMN_DATA_BYTES)
                else
                    $fatal(
                        1,
                        "Done asserted after %0d data bytes, expected %0d",
                        next_data_count,
                        COLUMN_DATA_BYTES
                    );
                expect_cleanup <= 1'b1;
                next_enable_count = 0;
                next_data_count   = 0;
            end

            enable_count <= next_enable_count;
            data_count   <= next_data_count;
            prev_ram_as  <= cmd_readcol_as;
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        cmd_readcol_we,
                        cmd_readcol_as,
                        cmd_readcol_done,
                        cmd_readcol_do,
                        addr,
                        sync_level_unused,
                        1'b0};
    // verilog_format: on
endmodule
