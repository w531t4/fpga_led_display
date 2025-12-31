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
endpackage
