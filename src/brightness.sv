`default_nettype none
module brightness #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [5:0] value, /* the pixel's absolute value */
    input [5:0] mask,  /* a rolling brightness mask */
    input enable,

    output out
);
    /* apply the brightness mask to the calculated sub-pixel value */
    wire masked_value = (value & mask) != 0;
    assign out = masked_value && enable;
endmodule
