`default_nettype none
module brightness #(
    parameter BRIGHTNESS_LEVELS = 6,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [BRIGHTNESS_LEVELS-1:0] value, /* the pixel's absolute value */
    input [BRIGHTNESS_LEVELS-1:0] mask,  /* a rolling brightness mask */
    input enable,

    output out
);
    /* apply the brightness mask to the calculated sub-pixel value */
    wire masked_value = (value & mask) != 0;
    assign out = masked_value && enable;
endmodule
