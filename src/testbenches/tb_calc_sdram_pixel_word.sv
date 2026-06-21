// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
`default_nettype none

// tb_calc_sdram_pixel_word:
// - Confirms calc::sdram_pixel_word_select / calc::sdram_byte_in_word_select recombine
//   to the original byte index, and that the byte-in-word result always fits within
//   one SDRAM word.
// - sdram_pixel_word_select returns a single bit (the project's pixels span at most
//   two SDRAM words), so this only exercises byte indices within that contract --
//   up to two full words' worth of bytes -- rather than arbitrary word sizes.
module tb_calc_sdram_pixel_word;
    localparam int unsigned MAX_BYTE_INDEX = 2 * params::SDRAM_WORD_BYTES;

    initial begin
        for (int unsigned byte_index = 0; byte_index < MAX_BYTE_INDEX; byte_index++) begin
            logic word_select;
            int unsigned byte_in_word;
            int unsigned recombined;
            word_select = calc::sdram_pixel_word_select(byte_index, params::SDRAM_WORD_BYTES);
            byte_in_word = calc::sdram_byte_in_word_select(byte_index, params::SDRAM_WORD_BYTES);
            recombined = (word_select ? params::SDRAM_WORD_BYTES : 0) + byte_in_word;
            if (byte_in_word >= params::SDRAM_WORD_BYTES)
                $fatal(1, "byte_in_word %0d out of range for SDRAM_WORD_BYTES=%0d (byte_index=%0d)", byte_in_word,
                       params::SDRAM_WORD_BYTES, byte_index);
            if (recombined != byte_index)
                $fatal(1, "recombination mismatch: byte_index=%0d got=%0d", byte_index, recombined);
        end

        $display("tb_calc_sdram_pixel_word: PASS");
        $finish;
    end
endmodule
