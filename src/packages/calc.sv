// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package calc;
    function automatic int unsigned num_subpanels(input int unsigned pixel_height, input int unsigned pixel_halfheight);
        num_subpanels = pixel_height / pixel_halfheight;
    endfunction

    function automatic int unsigned num_subpanelselect_bits(input int unsigned pixel_height,
                                                            input int unsigned pixel_halfheight);
        num_subpanelselect_bits = $clog2(num_subpanels(pixel_height, pixel_halfheight));
    endfunction

    function automatic int unsigned num_pixelcolorselect_bits(input int unsigned bytes_per_pixel);
        num_pixelcolorselect_bits = $clog2(bytes_per_pixel);
    endfunction

    function automatic int unsigned num_column_address_bits(input int unsigned pixel_width);
        num_column_address_bits = $clog2(pixel_width);
    endfunction

    function automatic int unsigned num_row_address_bits(input int unsigned pixel_height);
        num_row_address_bits = $clog2(pixel_height);
    endfunction

    // Address B (port B read address):
    //  - composed as (row within subpanel + column)
    //  - rrrrcccc (where)
    //          YYYY = num_subpanelselect_bits(PIXEL_HEIGHT, PIXEL_HALFHEIGHT)
    //          rrrr = log2(PIXEL_HALFHEIGHT)
    //          cccc = log2(PIXEL_WIDTH)
    //          XXXX = num_pixelcolorselect_bits(BYTES_PER_PIXEL)
    function automatic int unsigned num_address_b_bits(input int unsigned pixel_width,
                                                       input int unsigned pixel_halfheight);
        num_address_b_bits = $clog2(pixel_halfheight) + num_column_address_bits(pixel_width);
    endfunction

    //Data A: 8‑bit
    //  - one byte of a pixel written into the selected lane (QA is tied off)
    function automatic int unsigned num_data_a_bits();
        num_data_a_bits = 8;
    endfunction

    // Data B (QB):
    //  - concatenation of all lane bytes for that AddressB (all subpanels × pixel‑byte selects)
    //  - split as {pixeldata_bottom, pixeldata_top}
    //  - Viz (lanes concatenated by lane index {Y,X}):
    //     AAAAAAAABBBBBBBBCCCCCCCCDDDDDDDDEEEEEEEEFFFFFFFFGGGGGGGGHHHHHHHH
    //     |=======pixeldata_bottom=======||=========pixeldata_top========|
    //     BBBBBBBBGGGGGGGGRRRRRRRRxxxxxxxxBBBBBBBBGGGGGGGGRRRRRRRRxxxxxxxx < rgb24
    //     For current config (2 subpanels, 4 byte slots):
    //     A=Y0X0, B=Y0X1, C=Y0X2, D=Y0X3, E=Y1X0, F=Y1X1, G=Y1X2, H=Y1X3.
    function automatic int unsigned num_data_b_bits(input int unsigned pixel_height, input int unsigned bytes_per_pixel,
                                                    input int unsigned pixel_halfheight);
        num_data_b_bits = ((1 << num_pixelcolorselect_bits(bytes_per_pixel)) <<
                           num_subpanelselect_bits(pixel_height, pixel_halfheight)) << $clog2(8);
    endfunction

    function automatic int unsigned num_pixeldata_bits(input int unsigned bytes_per_pixel);
        // num_pixelcolorselect_bits(bytes_per_pixel)
        //      - bits needed to select the byte index within a pixel (rounded up to power of two)
        // 1 << num_pixelcolorselect_bits(...)
        //      - number of byte slots (padded to power of two)
        // * 8
        //      - We must allocate 8-bits for each byte slot
        num_pixeldata_bits = (1 << num_pixelcolorselect_bits(bytes_per_pixel)) << 3;
    endfunction

    function automatic int unsigned num_bytes_to_contain(input int unsigned num_bits);
        // return the number of bytes needed to hold a n-bit number
        // 128 - 7 bit (0-127), 1 byte
        // 256 - 8 bit (0-255), 1 byte
        // 257 - 9 bit (0-511), 2 bytes
        num_bytes_to_contain = ((num_bits + 8 - 1) / 8);
    endfunction

    function automatic int unsigned num_padding_bits_needed_to_reach_byte_boundry(input int unsigned num_bits);
        // Return the number of padding bits needed to align to a byte boundry.
        // WARNING: things get ugly if this returns 0. Must mitigate that case with ifdef
        num_padding_bits_needed_to_reach_byte_boundry = (num_bytes_to_contain(num_bits) * 8) - num_bits;
    endfunction

    function automatic int unsigned safe_clog2(input int unsigned number);
        // consider     logic [safe_bits_needed_for_column_byte_counter-1:0] column_byte_counter;
        // clog2(2) -> 1 <-- "you need 1 bits to represent qty 2" [clog2(n)-1:0] ==> [1-1:0] ==> [0:0] OK
        // clog2(1) -> 0 <-- "you need 0 bits to represent qty 1" [clog2(n)-1:0] ==> [0-1:0] ==> [-1:0] NOK
        // this function makes the NOK case OK [safe_bits(1)-1:0] ==> [1-1:0] ==> [0:0] OK
        safe_clog2 = number > 1 ? $clog2(number) : 1;
    endfunction

    function automatic int unsigned clamp_remaining_dimension(input int unsigned start, input int unsigned span,
                                                              input int unsigned max);
        // TODO: use later when we move interface to provide x2
        // if (span >= max) begin
        //     clamp_dimension = max - 1;
        // end else if ((start + (span - 1)) >= max) begin
        //     clamp_dimension = max - 1;
        // end else begin
        //     clamp_dimension = start + span - 1;
        // end

        // PIXEL_WIDTH=8, x1 = 3, width = 4 (w) ==  width OK
        //                  [0, 1, 2, 3, 4, 5, 6, 7]
        //                            *<------>*
        // PIXEL_WIDTH=8, x1 = 3, width = 6 (w) == width=4
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9
        //                            *<--------------*
        // PIXEL_WIDTH=8, x1 = 3, width = 8 (w) == width=4
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                            *<-------------------->*
        // PIXEL_WIDTH=8, x1 = 3, width = 9 (w) == width=4
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                            *<------------------------>*
        // span = 2, start= 5 max = 8..
        // PIXEL_WIDTH=8, x1 = 5, width = 2 -- width = 2 ok
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                                  *<--->*
        // span = 8, start= 0 max = 8..
        // PIXEL_WIDTH=8, x1 = 5, width = 2 -- width = 2 ok
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                   *<------------------>*
        // span = 9, start= 0 max = 8..
        // PIXEL_WIDTH=8, x1 = 5, width = 2 -- width = 2 ok
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                   *<------------------>*
        // span = 8, start= 1 max = 8..
        // PIXEL_WIDTH=8, x1 = 5, width = 2 -- width = 2 ok
        //                  [0, 1, 2, 3, 4, 5, 6, 7], 8, 9, 10, 11
        //                      *<------------------->*
        if ((span + start - 1) >= max) begin
            clamp_remaining_dimension = max - start + 1;
        end else begin
            clamp_remaining_dimension = span;
        end
    endfunction

    // Words needed for one SDRAM framebuffer: one scan-position block per row of
    // pixel_halfheight, each holding pixel_width columns, each column holding
    // subpanel_count independent pixels (top/bottom), each pixel (pixel_bytes/sdram_word_bytes)
    // SDRAM words. pixel_bytes is the already-padded per-pixel byte count (see
    // calc::num_pixeldata_bits), not the raw color depth.
    function automatic int unsigned num_sdram_buffer_words(input int unsigned pixel_width,
                                                           input int unsigned pixel_halfheight,
                                                           input int unsigned subpanel_count,
                                                           input int unsigned pixel_bytes,
                                                           input int unsigned sdram_word_bytes);
        num_sdram_buffer_words =
            pixel_halfheight * pixel_width * subpanel_count * (pixel_bytes / sdram_word_bytes);
    endfunction

    // SDRAM word address for the post-migration framebuffer layout:
    //  - frame       selects front/back buffer
    //  - scan_pos    = y[3:0], the BAM scan row within a subpanel
    //  - col         = x
    //  - half        = y[4], top (0) vs bottom (1) subpanel pixel at this scan position
    //  - pixel_word  selects which (pixel_bytes/sdram_word_bytes)-word of that pixel
    //                (low/high half of its padded color value)
    function automatic logic [params::SDRAM_NATIVE_ADDR_BITS-1:0] sdram_word_addr(
        input logic frame, input int unsigned scan_pos, input int unsigned col, input logic half,
        input logic pixel_word, input int unsigned pixel_width, input int unsigned pixel_halfheight,
        input int unsigned subpanel_count, input int unsigned pixel_bytes, input int unsigned sdram_word_bytes);
        int unsigned words_per_pixel;
        int unsigned buffer_words;
        int unsigned frame_words;
        int unsigned words_per_col;
        int unsigned words_per_row;
        words_per_pixel = pixel_bytes / sdram_word_bytes;
        buffer_words =
            num_sdram_buffer_words(pixel_width, pixel_halfheight, subpanel_count, pixel_bytes, sdram_word_bytes);
        words_per_col = subpanel_count * words_per_pixel;
        words_per_row = pixel_width * words_per_col;
        frame_words = frame ? buffer_words : 0;
        sdram_word_addr = params::SDRAM_NATIVE_ADDR_BITS'(frame_words + scan_pos * words_per_row +
                              col * words_per_col + half * words_per_pixel + pixel_word);
    endfunction

    // Decompose a byte index within a (possibly multi-word) pixel into which
    // SDRAM word holds it, and which byte within that word. Used by the
    // write path to turn a per-byte control_module write into a word write
    // with the right byte enable.
    function automatic logic sdram_pixel_word_select(input int unsigned byte_index, input int unsigned sdram_word_bytes);
        sdram_pixel_word_select = logic'(byte_index / sdram_word_bytes);
    endfunction

    function automatic int unsigned sdram_byte_in_word_select(input int unsigned byte_index,
                                                              input int unsigned sdram_word_bytes);
        sdram_byte_in_word_select = byte_index % sdram_word_bytes;
    endfunction
endpackage
