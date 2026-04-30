// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_types_sdram_address_map;
    types::fb_addr_t fb_addr;
    types::sdram_byte_addr_t byte_addr;
    types::sdram_word_addr_t word_addr;
    types::sdram_byte_lane_t byte_lane;

    initial begin
        // Geometry-derived storage sizes.
        assert (params::SDRAM_FRAME_BYTES == 48)
        else $fatal(1, "expected frame bytes 48, got %0d", params::SDRAM_FRAME_BYTES);
        assert (params::SDRAM_FRAME_STRIDE_BYTES == 48)
        else $fatal(1, "expected frame stride 48, got %0d", params::SDRAM_FRAME_STRIDE_BYTES);
        assert (params::SDRAM_FRAME0_BASE_BYTES == 0)
        else $fatal(1, "expected frame0 base 0, got %0d", params::SDRAM_FRAME0_BASE_BYTES);
        assert (params::SDRAM_FRAME1_BASE_BYTES == 48)
        else $fatal(1, "expected frame1 base 48, got %0d", params::SDRAM_FRAME1_BASE_BYTES);
        assert (params::SDRAM_SCRATCH_BASE_BYTES == 96)
        else $fatal(1, "expected scratch base 96, got %0d", params::SDRAM_SCRATCH_BASE_BYTES);
        assert (params::SDRAM_REQUIRED_BYTES <= params::SDRAM_CAPACITY_BYTES)
        else
            $fatal(
                1,
                "required bytes %0d exceed capacity %0d",
                params::SDRAM_REQUIRED_BYTES,
                params::SDRAM_CAPACITY_BYTES
            );

        // Logical compact row-major byte addressing.
        fb_addr = '{row: types::row_addr_t'(0), col: types::col_addr_t'(0), pixel: types::pixel_addr_t'(0)};
        byte_addr = types::sdram_frame_byte_addr(1'b0, fb_addr);
        assert (byte_addr == 0)
        else $fatal(1, "frame0 origin expected 0, got %0d", byte_addr);

        fb_addr = '{row: types::row_addr_t'(0), col: types::col_addr_t'(1), pixel: types::pixel_addr_t'(0)};
        byte_addr = types::sdram_frame_byte_addr(1'b0, fb_addr);
        assert (byte_addr == 3)
        else $fatal(1, "frame0 col1 expected 3, got %0d", byte_addr);

        fb_addr = '{row: types::row_addr_t'(1), col: types::col_addr_t'(0), pixel: types::pixel_addr_t'(0)};
        byte_addr = types::sdram_frame_byte_addr(1'b0, fb_addr);
        assert (byte_addr == 12)
        else $fatal(1, "frame0 row1 expected 12, got %0d", byte_addr);

        fb_addr = '{row: types::row_addr_t'(3), col: types::col_addr_t'(3), pixel: types::pixel_addr_t'(2)};
        byte_addr = types::sdram_frame_byte_addr(1'b1, fb_addr);
        assert (byte_addr == 95)
        else $fatal(1, "frame1 last byte expected 95, got %0d", byte_addr);

        // Linear byte address decomposition into {row, bank, col} plus byte lane.
        byte_addr = types::sdram_byte_addr_t'(0);
        word_addr = types::sdram_word_addr_from_byte_addr(byte_addr);
        byte_lane = types::sdram_byte_lane_from_byte_addr(byte_addr);
        assert (word_addr.row == 0 && word_addr.bank == 0 && word_addr.col == 0 && byte_lane == 0)
        else
            $fatal(
                1,
                "byte_addr=0 expected row/bank/col/lane 0/0/0/0 got %0d/%0d/%0d/%0d",
                word_addr.row,
                word_addr.bank,
                word_addr.col,
                byte_lane
            );

        byte_addr = types::sdram_byte_addr_t'(1);
        word_addr = types::sdram_word_addr_from_byte_addr(byte_addr);
        byte_lane = types::sdram_byte_lane_from_byte_addr(byte_addr);
        assert (word_addr.row == 0 && word_addr.bank == 0 && word_addr.col == 0 && byte_lane == 1)
        else
            $fatal(
                1,
                "byte_addr=1 expected row/bank/col/lane 0/0/0/1 got %0d/%0d/%0d/%0d",
                word_addr.row,
                word_addr.bank,
                word_addr.col,
                byte_lane
            );

        byte_addr = types::sdram_byte_addr_t'(48);
        word_addr = types::sdram_word_addr_from_byte_addr(byte_addr);
        byte_lane = types::sdram_byte_lane_from_byte_addr(byte_addr);
        assert (word_addr.row == 0 && word_addr.bank == 1 && word_addr.col == 8 && byte_lane == 0)
        else
            $fatal(
                1,
                "byte_addr=48 expected row/bank/col/lane 0/1/8/0 got %0d/%0d/%0d/%0d",
                word_addr.row,
                word_addr.bank,
                word_addr.col,
                byte_lane
            );

        $display("tb_types_sdram_address_map: PASS");
        $finish;
    end
endmodule
