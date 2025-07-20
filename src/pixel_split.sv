`default_nettype none
module pixel_split #(
    parameter BRIGHTNESS_LEVELS = 6,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [15:0] pixel_rgb565,
    input [BRIGHTNESS_LEVELS-1:0] brightness_mask,
    input [2:0] rgb_enable,

    output [2:0] rgb_output
);
    wire [BRIGHTNESS_LEVELS-1:0] red_gamma;
    wire [BRIGHTNESS_LEVELS-1:0] green_gamma;
    wire [BRIGHTNESS_LEVELS-1:0] blue_gamma;

    /* split the RGB565 pixel into components */
    rgb565 rgb (
        .data_in(pixel_rgb565),
        .red(red_gamma),
        .green(green_gamma),
        .blue(blue_gamma)
    );

    /* apply the brightness mask to the gamma-corrected sub-pixel value */
    brightness #(
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS)
    ) b_red (
        .value(red_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[0]),
        .out(rgb_output[0])
    );
    brightness #(
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS)
    ) b_green (
        .value(green_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[1]),
        .out(rgb_output[1])
    );
    brightness #(
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS)
    ) b_blue(
        .value(blue_gamma),
        .mask(brightness_mask),
        .enable(rgb_enable[2]),
        .out(rgb_output[2])
    );
endmodule
