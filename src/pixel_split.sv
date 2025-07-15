`default_nettype none
module pixel_split #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
    ) (
    input [15:0] pixel_rgb565,
    input [5:0] brightness_mask,
    input [2:0] rgb_enable,

    output [2:0] rgb_output
);
    wire [4:0] red_raw;
    wire [5:0] green_raw;
    wire [4:0] blue_raw;

    wire [5:0] red_gamma;
    wire [5:0] green_gamma;
    wire [5:0] blue_gamma;

    /* split the RGB565 pixel into components */
    rgb565 rgb (
        .data_in(pixel_rgb565),
        .red(red_raw),
        .green(green_raw),
        .blue(blue_raw)
    );

    gamma565_correct gamma_c (
        .red_in(red_raw),
        .green_in(green_raw),
        .blue_in(blue_raw),
        .red_out(red_gamma),
        .green_out(green_gamma),
        .blue_out(blue_gamma)
    );

    /* apply the brightness mask to the gamma-corrected sub-pixel value */
    brightness b_red (
        .value(red_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[0]),
        .out(rgb_output[0])
    );
    brightness b_green (
        .value(green_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[1]),
        .out(rgb_output[1])
    );
    brightness b_blue(
        .value(blue_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[2]),
        .out(rgb_output[2])
    );
endmodule
