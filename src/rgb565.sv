`default_nettype none
module rgb565 #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [15:0] data_in,

    output [5:0] red,
    output [5:0] green,
    output [5:0] blue
);

    gamma_correct #(
        .IN_BITS(5),
        .OUT_BITS(6)
    ) gc_red (
        .in(data_in[15:11]),
        .out(red)
    );
    gamma_correct #(
        .IN_BITS(6),
        .OUT_BITS(6)
    ) gc_green(
        .in(data_in[10:5]),
        .out(green)
    );
    gamma_correct #(
        .IN_BITS(5),
        .OUT_BITS(6)
    ) gc_blue (
        .in(data_in[4:0]),
        .out(blue)
    );

endmodule
