`default_nettype none
module rgb24 #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [23:0] data_in,

    output [7:0] red,
    output [7:0] green,
    output [7:0] blue
);
    `ifdef GAMMA
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_red (
            .in(data_in[23:16]),
            .out(red)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_green(
            .in(data_in[15:8]),
            .out(green)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_blue (
            .in(data_in[7:0]),
            .out(blue)
        );
    `else
        assign red = data_in[23:16];
        assign green = data_in[15:8];
        assign blue = data_in [7:0];
    `endif

endmodule
