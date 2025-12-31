// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package calc_pkg;
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

    function automatic int unsigned num_address_b_bits(input int unsigned pixel_width,
                                                       input int unsigned pixel_halfheight);
        num_address_b_bits = $clog2(pixel_halfheight) + num_column_address_bits(pixel_width);
    endfunction

    function automatic int unsigned num_address_a_bits(input int unsigned pixel_width, input int unsigned pixel_height,
                                                       input int unsigned bytes_per_pixel,
                                                       input int unsigned pixel_halfheight);
        num_address_a_bits = num_subpanelselect_bits(pixel_height, pixel_halfheight) +
            num_pixelcolorselect_bits(bytes_per_pixel) + num_address_b_bits(pixel_width, pixel_halfheight);
    endfunction

    function automatic int unsigned num_structure_bits(input int unsigned pixel_width, input int unsigned pixel_height,
                                                       input int unsigned bytes_per_pixel,
                                                       input int unsigned pixel_halfheight);
        num_structure_bits = num_address_a_bits(pixel_width, pixel_height, bytes_per_pixel, pixel_halfheight) -
            num_address_b_bits(pixel_width, pixel_halfheight);
    endfunction

    function automatic int unsigned num_data_a_bits();
        num_data_a_bits = 8;
    endfunction

    function automatic int unsigned num_data_b_bits(input int unsigned pixel_height, input int unsigned bytes_per_pixel,
                                                    input int unsigned pixel_halfheight);
        num_data_b_bits = ((1 << num_pixelcolorselect_bits(bytes_per_pixel)) <<
                           num_subpanelselect_bits(pixel_height, pixel_halfheight)) << $clog2(8);
    endfunction

    function automatic int unsigned num_bits_per_subpanel(
        input int unsigned pixel_height, input int unsigned bytes_per_pixel, input int unsigned pixel_halfheight);
        num_bits_per_subpanel = num_data_b_bits(pixel_height, bytes_per_pixel, pixel_halfheight) >>
            num_subpanelselect_bits(pixel_height, pixel_halfheight);
    endfunction

    function automatic int unsigned num_bytes_to_contain(input int unsigned num_bits);
        // return the number of bytes needed to hold a n-bit number
        // 128 - 7 bit (0-127), 1 byte
        // 256 - 8 bit (0-255), 1 byte
        // 257 - 9 bit (0-511), 2 bytes
        num_bytes_to_contain = ((num_bits + 8 - 1) / 8);
    endfunction

    function automatic int unsigned safe_bits(input int unsigned number);
        // consider     logic [safe_bits_needed_for_column_byte_counter-1:0] column_byte_counter;
        // clog2(2) -> 1 <-- "you need 1 bits to represent qty 2" [clog2(n)-1:0] ==> [1-1:0] ==> [0:0] OK
        // clog2(1) -> 0 <-- "you need 0 bits to represent qty 1" [clog2(n)-1:0] ==> [0-1:0] ==> [-1:0] NOK
        // this function makes the NOK case OK [safe_bits(1)-1:0] ==> [1-1:0] ==> [0:0] OK
        safe_bits = number > 1 ? $clog2(number) : 1;
    endfunction
endpackage
