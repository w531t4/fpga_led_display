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
    wire [7:0] red_selected;
    wire [7:0] green_selected;
    wire [7:0] blue_selected;

    assign red_selected = data_in[23:16];
    assign green_selected = data_in[15:8];
    assign blue_selected = data_in[7:0];

    `ifdef GAMMA
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_red (
            .in(red_selected),
            .out(red)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_green(
            .in(green_selected),
            .out(green)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_blue (
            .in(blue_selected),
            .out(blue)
        );
    `else
        assign red = red_selected;
        assign green = green_selected;
        assign blue = blue_selected;
    `endif

endmodule
