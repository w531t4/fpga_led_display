`default_nettype none
module gamma565_correct #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [4:0] red_in,
    input [5:0] green_in,
    input [4:0] blue_in,
    output [5:0] red_out,
    output [5:0] green_out,
    output [5:0] blue_out
);

    // ROMs for gamma correction
    reg [7:0] gamma_r_lut [0:31];
    reg [7:0] gamma_g_lut [0:63];
    reg [7:0] gamma_b_lut [0:31];

    wire [7:0] red_gamma   = gamma_r_lut[red_in];
    wire [7:0] green_gamma = gamma_g_lut[green_in];
    wire [7:0] blue_gamma  = gamma_b_lut[blue_in];

    // Scale gamma-corrected 8-bit values back to 6-bit range
    assign red_out = red_gamma[7:2];     // truncate to 6 bits
    assign green_out = green_gamma[7:2]; // truncate to 6 bits
    assign blue_out = blue_gamma[7:2];   // truncate to 6 bits

    initial $readmemh("src/memory/gamma_rb_lut.mem", gamma_b_lut);
    initial $readmemh("src/memory/gamma_rb_lut.mem", gamma_r_lut);
    initial $readmemh("src/memory/gamma_g_lut.mem", gamma_g_lut);

endmodule
