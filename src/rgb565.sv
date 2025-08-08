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

    wire [4:0] red_selected;
    wire [5:0] green_selected;
    wire [4:0] blue_selected;

    assign red_selected = data_in[15:11];
    assign green_selected = data_in[10:5];
    assign blue_selected = data_in[4:0];


    `ifdef GAMMA
        gamma_correct #(
            .IN_BITS(5),
            .OUT_BITS(6)
        ) gc_red (
            .in(red_selected),
            .out(red)
        );
        gamma_correct #(
            .IN_BITS(6),
            .OUT_BITS(6)
        ) gc_green(
            .in(green_selected),
            .out(green)
        );
        gamma_correct #(
            .IN_BITS(5),
            .OUT_BITS(6)
        ) gc_blue (
            .in(blue_selected),
            .out(blue)
        );
    `else
        assign red = {red_selected, red_selected[0]};
        assign green = green_selected;
        assign blue = {blue_selected, blue_selected[0]};
    `endif
endmodule
