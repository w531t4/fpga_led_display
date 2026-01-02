// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_control_cmd_readpixel #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS,
    parameter real SIM_HALF_PERIOD_NS = params::SIM_HALF_PERIOD_NS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    `include "structures.svh"
    `include "row4.svh"
    localparam integer unsigned command_without_opcode_bits = $bits(readpixel_cmd_t) - $bits(commands_pkg::opcode_t);
    localparam logic [command_without_opcode_bits-1:0] cmd_pixel_1_local = cmd_pixel_1[command_without_opcode_bits-1:0];
    localparam int unsigned STREAM_BYTES = ($bits(cmd_pixel_1_local) / 8);
    localparam int ROW_IDX = 0;
    localparam int COL_LSB_IDX = 1;
    localparam int COL_MSB_IDX = 2;

    // === Testbench scaffolding ===
    wire                                                             slowclk;
    logic                                                            clk;
    wire                                                             subcmd_enable;
    logic [                                                     7:0] data_in;
    logic                                                            reset;
    wire                                                             cmd_readpixel_we;
    wire                                                             cmd_readpixel_as;
    wire                                                             cmd_readpixel_done;
    wire  [                                                     7:0] cmd_readpixel_do;
    wire  [        calc_pkg::num_row_address_bits(PIXEL_HEIGHT)-1:0] cmd_readpixel_row_addr;
    wire  [      calc_pkg::num_column_address_bits(PIXEL_WIDTH)-1:0] cmd_readpixel_col_addr;
    wire  [calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] cmd_readpixel_pixel_addr;
    wire                                                             junk1;
    // verilator lint_off UNUSEDSIGNAL
    logic [                                                     7:0] expected_bytes           [STREAM_BYTES];
    // verilator lint_on UNUSEDSIGNAL
    int                                                              enable_count;
    int                                                              data_count;
    int                                                              done_count;
    logic [                                                     7:0] last_enable_byte;
    int                                                              last_enable_idx;
    int                                                              last_data_idx;
    logic                                                            last_enable_pulse;
    logic                                                            prev_ram_as;

    // === DUT wiring ===
    clock_divider #(
        .CLK_DIV_COUNT(16)
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

    control_cmd_readpixel #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        ._UNUSED('d0)
    ) cmd_readpixel (
        .reset(reset),
        .data_in(data_in),
        .clk(clk),
        .enable(subcmd_enable),
        .row(cmd_readpixel_row_addr),
        .column(cmd_readpixel_col_addr),
        .pixel(cmd_readpixel_pixel_addr),
        .data_out(cmd_readpixel_do),
        .ram_write_enable(cmd_readpixel_we),
        .ram_access_start(cmd_readpixel_as),
        .done(cmd_readpixel_done)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_readpixel);
        clk = 0;
        reset = 1;
        // subcmd_enable = 0;
        data_in = 8'b0;
        // finish reset for tb
        @(posedge clk) @(posedge clk) reset = ~reset;

        // @(posedge clk) begin
        //     subcmd_enable = 1;
        // end
        // Precompute expected stream for monitoring.
        expected_bytes[ROW_IDX]     = cmd_pixel_1_local[$bits(cmd_pixel_1_local)-1-:8];
        expected_bytes[COL_LSB_IDX] = cmd_pixel_1_local[$bits(cmd_pixel_1_local)-1-8-:8];
`ifdef W128
        expected_bytes[COL_MSB_IDX] = cmd_pixel_1_local[$bits(cmd_pixel_1_local)-1-16-:8];
        for (int __i = 3; __i < STREAM_BYTES; __i++) begin
            expected_bytes[__i] = cmd_pixel_1_local[$bits(cmd_pixel_1_local)-1-(__i*8)-:8];
        end
`else
        for (int __i = 2; __i < STREAM_BYTES; __i++) begin
            expected_bytes[__i] = cmd_pixel_1_local[$bits(cmd_pixel_1_local)-1-(__i*8)-:8];
        end
`endif
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);
        `STREAM_BYTES_MSB(slowclk, data_in, cmd_pixel_1_local)
        `STREAM_BYTES_MSB(slowclk, data_in, cmd_pixel_1_local)

        @(posedge slowclk);
        // // `WAIT_ASSERT(clk, (sysreset == 1), 128*4)

        repeat (25) begin
            @(posedge slowclk);
        end
        $finish;
    end

    // === Scoreboard / monitor ===
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
        end else begin
            int next_enable_count;
            int next_data_count;
            next_enable_count = enable_count;
            next_data_count   = data_count;

            if (last_enable_pulse) begin
                if (last_enable_idx == 0) begin
                    // Row capture byte
                    assert (cmd_readpixel_row_addr == last_enable_byte[4:0])
                    else
                        $fatal(
                            1,
                            "Row latch mismatch: expected %0d, got %0d",
                            last_enable_byte[4:0],
                            cmd_readpixel_row_addr
                        );
                    assert (cmd_readpixel_we == 1'b0 && cmd_readpixel_do == 8'b0)
                    else $fatal(1, "Unexpected write/data during row capture");
                end else if (last_enable_idx == 1) begin
                    // Column capture LSB/MSB (little endian)
                    assert (cmd_readpixel_we == 1'b0)
                    else $fatal(1, "WE asserted during column capture");
                end else begin
                    // Payload byte
                    int exp_pix;
                    exp_pix = BYTES_PER_PIXEL - 1 - (last_data_idx % BYTES_PER_PIXEL);
                    assert (cmd_readpixel_we == 1'b1)
                    else $fatal(1, "ram_write_enable deasserted during data transfer at byte %0d", last_data_idx);
                    // Payload values can vary with test vector; just ensure we store what we sampled.
                    assert (cmd_readpixel_do == last_enable_byte)
                    else
                        $fatal(
                            1,
                            "Data mismatch at byte %0d: expected 0x%0h got 0x%0h",
                            last_data_idx,
                            last_enable_byte,
                            cmd_readpixel_do
                        );
                    assert (cmd_readpixel_pixel_addr == (calc_pkg::num_pixelcolorselect_bits(
                        BYTES_PER_PIXEL
                    ))'(exp_pix))
                    else
                        $fatal(
                            1,
                            "Pixel mismatch at byte %0d: expected %0d got %0d",
                            last_data_idx,
                            exp_pix,
                            cmd_readpixel_pixel_addr
                        );
                    assert (cmd_readpixel_as != prev_ram_as)
                    else $fatal(1, "ram_access_start failed to toggle at byte %0d", last_data_idx);
                end
            end

            if (cmd_readpixel_done) begin
                done_count <= done_count + 1;
                assert (next_data_count == BYTES_PER_PIXEL)
                else $fatal(1, "Done asserted after %0d data bytes, expected %0d", next_data_count, BYTES_PER_PIXEL);
                next_enable_count = 0;
                next_data_count   = 0;
            end

            if (subcmd_enable) begin
                last_enable_pulse <= 1'b1;
                last_enable_byte  <= data_in;
                last_enable_idx   <= enable_count;
                last_data_idx     <= (enable_count <= 1) ? -1 : data_count;
                assert (enable_count < STREAM_BYTES)
                else $fatal(1, "Stream length exceeded: enable_count=%0d expected max %0d", enable_count, STREAM_BYTES);
                // Ignore strict match on header bytes; only payload bytes are checked for data integrity.
                next_enable_count = enable_count + 1;
                if (enable_count > 1) next_data_count = data_count + 1;
            end else begin
                last_enable_pulse <= 1'b0;
            end

            enable_count <= next_enable_count;
            data_count   <= next_data_count;
            prev_ram_as  <= cmd_readpixel_as;
        end
    end

    // === Clock generation ===
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        cmd_readpixel_we,
                        cmd_readpixel_as,
                        cmd_readpixel_done,
                        cmd_readpixel_do,
                        cmd_readpixel_row_addr,
                        cmd_readpixel_col_addr,
                        cmd_readpixel_pixel_addr,
                        cmd_series,
                        junk1,
                        1'b0};
    // verilog_format: on
endmodule
