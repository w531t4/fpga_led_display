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

    function automatic int unsigned num_row_column_pixel_bits(
        input int unsigned pixel_height, input int unsigned pixel_width, input int unsigned bytes_per_pixel);
        num_row_column_pixel_bits = num_row_address_bits(pixel_height) + num_column_address_bits(pixel_width) +
            num_pixelcolorselect_bits(bytes_per_pixel);
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

    function automatic int unsigned safe_bits(input int unsigned number);
        // consider     logic [safe_bits_needed_for_column_byte_counter-1:0] column_byte_counter;
        // clog2(2) -> 1 <-- "you need 1 bits to represent qty 2" [clog2(n)-1:0] ==> [1-1:0] ==> [0:0] OK
        // clog2(1) -> 0 <-- "you need 0 bits to represent qty 1" [clog2(n)-1:0] ==> [0-1:0] ==> [-1:0] NOK
        // this function makes the NOK case OK [safe_bits(1)-1:0] ==> [1-1:0] ==> [0:0] OK
        safe_bits = number > 1 ? $clog2(number) : 1;
    endfunction
endpackage
