// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module pixel_split #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input types::color_field_subpanel_t pixel_data,
    input types::brightness_level_t brightness_mask,
    input types::brightness_level_t brightness_enable,
    input [2:0] rgb_enable,

    output [2:0] rgb_output
);
    wire types::brightness_level_t red_gamma;
    wire types::brightness_level_t green_gamma;
    wire types::brightness_level_t blue_gamma;

`ifdef RGB24
    rgb24 rgb_888 (
        // W/ the use of
        //      - _~_cmd_line_pixelselect_num (in control_module) for write addr:
        //             ({pixel_data[15:8], pixel_data[23:16], pixel_data[31:24]}) produced correct colors.
        //              pixel_data.field.color produced red/green colors, swapped... missing blue.
        //            - pixel_data[31:8] are populated
        //              [bbbb,gggg,rrrr]
        //                 0    1    2   3
        //              [____,____,____,xxxx]
        //      - cmd_line_pixelselect_num (note absent ~):
        //              ({pixel_data[15:8], pixel_data[23:16], pixel_data[31:24]}) shows just red
        //              pixel_data.field.color produces correct colors
        //            - pixel_data[23:0] are populated
        .data_in(pixel_data.field.color),
        .brightness(brightness_enable),
        .red(red_gamma),
        .green(green_gamma),
        .blue(blue_gamma)
    );
`else
    /* split the RGB565 pixel into components */
    rgb565 rgb_565 (
        //              [rrrrrbbb bbbggggg]
        .data_in(pixel_data.field.color),
        .brightness(brightness_enable),
        .red(red_gamma),
        .green(green_gamma),
        .blue(blue_gamma)
    );
`endif

    /* apply the brightness mask to the gamma-corrected sub-pixel value */
    brightness #(
        ._UNUSED('d0)
    ) b_red (
        .value(red_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[0]),
        .out(rgb_output[0])
    );
    brightness #(
        ._UNUSED('d0)
    ) b_green (
        .value(green_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[1]),
        .out(rgb_output[1])
    );
    brightness #(
        ._UNUSED('d0)
    ) b_blue (
        .value(blue_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[2]),
        .out(rgb_output[2])
    );
endmodule
