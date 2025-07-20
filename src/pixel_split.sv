`default_nettype none
module pixel_split #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [_NUM_DATA_B_BITS-1:0] pixel_data,
    input [BRIGHTNESS_LEVELS-1:0] brightness_mask,
    input [2:0] rgb_enable,

    output [2:0] rgb_output
);
    wire [BRIGHTNESS_LEVELS-1:0] red_gamma;
    wire [BRIGHTNESS_LEVELS-1:0] green_gamma;
    wire [BRIGHTNESS_LEVELS-1:0] blue_gamma;

    `ifdef RGB24
        rgb24 rgb_888 (
            // bits 7:0 are empty

            //              [bbbb,gggg,rrrr]
            //                 0    1    2   3
            //              [____,____,____,xxxx]
            .data_in({pixel_data[15:8], pixel_data[23:16], pixel_data[31:24]}),
            // .data_in({pixel_data[15:8], pixel_data[31:24], pixel_data[23:16]}), // things that are blue are green
            // .data_in({pixel_data[7:0], 8'b0, 8'b0}),
            .red(red_gamma),
            .green(green_gamma),
            .blue(blue_gamma)
        );
    `else
        /* split the RGB565 pixel into components */
        rgb565 rgb_565 (
            //              [rrrrrbbb bbbggggg]
            .data_in(pixel_data),
            .red(red_gamma),
            .green(green_gamma),
            .blue(blue_gamma)
        );
    `endif

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
