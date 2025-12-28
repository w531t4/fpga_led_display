// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package calc_pkg;
    function automatic int unsigned num_subpanels(input int unsigned pixel_height, input int unsigned pixel_halfheight);
        return pixel_height / pixel_halfheight;
    endfunction

    function automatic int unsigned num_subpanelselect_bits(input int unsigned pixel_height,
                                                            input int unsigned pixel_halfheight);
        return $clog2(num_subpanels(pixel_height, pixel_halfheight));
    endfunction

    function automatic int unsigned num_pixelcolorselect_bits(input int unsigned bytes_per_pixel);
        return $clog2(bytes_per_pixel);
    endfunction

    function automatic int unsigned num_column_address_bits(input int unsigned pixel_width);
        return $clog2(pixel_width);
    endfunction

    function automatic int unsigned num_row_address_bits(input int unsigned pixel_height);
        return $clog2(pixel_height);
    endfunction

    function automatic int unsigned num_address_b_bits(input int unsigned pixel_width,
                                                       input int unsigned pixel_halfheight);
        return $clog2(pixel_halfheight) + num_column_address_bits(pixel_width);
    endfunction

    function automatic int unsigned num_address_a_bits(input int unsigned pixel_width, input int unsigned pixel_height,
                                                       input int unsigned bytes_per_pixel,
                                                       input int unsigned pixel_halfheight);
        return num_subpanelselect_bits(pixel_height, pixel_halfheight) + num_pixelcolorselect_bits(bytes_per_pixel) +
            num_address_b_bits(pixel_width, pixel_halfheight);
    endfunction

    function automatic int unsigned num_structure_bits(input int unsigned pixel_width, input int unsigned pixel_height,
                                                       input int unsigned bytes_per_pixel,
                                                       input int unsigned pixel_halfheight);
        return num_address_a_bits(pixel_width, pixel_height, bytes_per_pixel, pixel_halfheight) -
            num_address_b_bits(pixel_width, pixel_halfheight);
    endfunction

    function automatic int unsigned num_data_a_bits(input int unsigned data_a_bits);
        return data_a_bits;
    endfunction

    function automatic int unsigned num_data_b_bits(input int unsigned pixel_height, input int unsigned bytes_per_pixel,
                                                    input int unsigned pixel_halfheight);
        return ((1 << num_pixelcolorselect_bits(bytes_per_pixel)) <<
                num_subpanelselect_bits(pixel_height, pixel_halfheight)) << $clog2(8);
    endfunction

    function automatic int unsigned num_bits_per_subpanel(
        input int unsigned pixel_height, input int unsigned bytes_per_pixel, input int unsigned pixel_halfheight);
        return num_data_b_bits(pixel_height, bytes_per_pixel, pixel_halfheight) >>
            num_subpanelselect_bits(pixel_height, pixel_halfheight);
    endfunction
endpackage
