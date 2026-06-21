// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
`default_nettype none

// tb_calc_sdram_addr:
// - Confirms calc::num_sdram_buffer_words matches the documented per-buffer size.
// - Exhaustively confirms calc::sdram_word_addr never aliases two distinct
//   (frame, scan_pos, col, half, pixel_word) locations onto the same word address,
//   and that frame 1 starts exactly where frame 0 ends.
module tb_calc_sdram_addr;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    // Already-padded per-pixel byte count (same derivation color_field_subpanel_t's padding uses),
    // not the raw color depth in params::BYTES_PER_PIXEL.
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned WORDS_PER_PIXEL = PIXEL_BYTES / params::SDRAM_WORD_BYTES;
    // Same type as addr: BUFFER_WORDS doubles as "the address where frame 1 begins."
    localparam types::sdram_word_addr_t BUFFER_WORDS = types::sdram_word_addr_t'(calc::num_sdram_buffer_words(
        params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES));
    localparam types::sdram_word_addr_t EXPECTED_BUFFER_WORDS =
        types::sdram_word_addr_t'(params::PIXEL_HALFHEIGHT * params::PIXEL_WIDTH * NUM_SUBPANELS * WORDS_PER_PIXEL);

    bit seen[types::sdram_word_addr_t];

    initial begin
        types::sdram_word_addr_t addr;

        if (BUFFER_WORDS != EXPECTED_BUFFER_WORDS)
            $fatal(1, "buffer_words mismatch: expected %0d got %0d", EXPECTED_BUFFER_WORDS, BUFFER_WORDS);

        for (int frame = 0; frame < 2; frame++) begin
            for (int scan_pos = 0; scan_pos < params::PIXEL_HALFHEIGHT; scan_pos++) begin
                for (int col = 0; col < params::PIXEL_WIDTH; col++) begin
                    for (int half = 0; half < NUM_SUBPANELS; half++) begin
                        for (int pixel_word = 0; pixel_word < WORDS_PER_PIXEL; pixel_word++) begin
                            addr = calc::sdram_word_addr(logic'(frame), scan_pos, col, logic'(half),
                                                         logic'(pixel_word), params::PIXEL_WIDTH,
                                                         params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                                                         params::SDRAM_WORD_BYTES);
                            if (seen.exists(addr))
                                $fatal(1,
                                       "address collision at addr=%0d (frame=%0d scan_pos=%0d col=%0d half=%0d pixel_word=%0d)",
                                       addr, frame, scan_pos, col, half, pixel_word);
                            seen[addr] = 1;
                            if (frame == 0 && addr >= BUFFER_WORDS)
                                $fatal(1, "frame 0 address %0d spilled past buffer_words=%0d", addr, BUFFER_WORDS);
                            if (frame == 1 && addr < BUFFER_WORDS)
                                $fatal(1, "frame 1 address %0d overlaps frame 0 (buffer_words=%0d)", addr,
                                       BUFFER_WORDS);
                        end
                    end
                end
            end
        end

        if (seen.num() != 2 * BUFFER_WORDS)
            $fatal(1, "expected %0d unique addresses, got %0d", 2 * BUFFER_WORDS, seen.num());

        $display("tb_calc_sdram_addr: PASS (%0d unique words across both frames)", seen.num());
        $finish;
    end
endmodule
