`default_nettype none
module rgb24 #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [23:0] data_in,
    input [7:0] brightness,
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

    // Rounded multiply (uses one 8x8 -> 16 DSP per channel)
    wire [15:0] r_mul = red_selected * brightness;
    wire [15:0] g_mul = green_selected * brightness;
    wire [15:0] b_mul = blue_selected  * brightness;

    wire [7:0] r_eff = (r_mul + 16'd127) >> 8;
    wire [7:0] g_eff = (g_mul + 16'd127) >> 8;
    wire [7:0] b_eff = (b_mul + 16'd127) >> 8;

    `ifdef GAMMA
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_red (
            .in(r_eff),
            .out(red)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_green(
            .in(g_eff),
            .out(green)
        );
        gamma_correct #(
            .IN_BITS(8),
            .OUT_BITS(8)
        ) gc_blue (
            .in(b_eff),
            .out(blue)
        );
    `else
        assign red = r_eff;
        assign green = g_eff;
        assign blue = b_eff;
    `endif

endmodule
