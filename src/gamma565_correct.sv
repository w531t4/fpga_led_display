`default_nettype none
module gamma565_correct #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [4:0] red_in,
    input [4:0] green_in,
    input [5:0] blue_in,
    output [5:0] red_out,
    output [5:0] green_out,
    output [5:0] blue_out
);

    // ROMs for gamma correction
    logic [7:0] gamma_r_lut [0:31];
    logic [7:0] gamma_g_lut [0:63];
    logic [7:0] gamma_b_lut [0:31];

    wire [7:0] red_gamma   = gamma_r_lut[red_in];
    wire [7:0] green_gamma = gamma_g_lut[green_in];
    wire [7:0] blue_gamma  = gamma_b_lut[blue_in];

    // Scale gamma-corrected 8-bit values back to 6-bit range
    assign red_out = red_gamma[7:2];     // truncate to 6 bits
    assign green_out = green_gamma[7:2]; // truncate to 6 bits
    assign blue_out = blue_gamma[7:2];   // truncate to 6 bits

    initial begin
        // Red & Blue LUT (5-bit input)
        gamma_r_lut[ 0] = 8'd0;    gamma_b_lut[ 0] = 8'd0;
        gamma_r_lut[ 1] = 8'd1;    gamma_b_lut[ 1] = 8'd1;
        gamma_r_lut[ 2] = 8'd2;    gamma_b_lut[ 2] = 8'd2;
        gamma_r_lut[ 3] = 8'd4;    gamma_b_lut[ 3] = 8'd4;
        gamma_r_lut[ 4] = 8'd6;    gamma_b_lut[ 4] = 8'd6;
        gamma_r_lut[ 5] = 8'd8;    gamma_b_lut[ 5] = 8'd8;
        gamma_r_lut[ 6] = 8'd11;   gamma_b_lut[ 6] = 8'd11;
        gamma_r_lut[ 7] = 8'd14;   gamma_b_lut[ 7] = 8'd14;
        gamma_r_lut[ 8] = 8'd18;   gamma_b_lut[ 8] = 8'd18;
        gamma_r_lut[ 9] = 8'd22;   gamma_b_lut[ 9] = 8'd22;
        gamma_r_lut[10] = 8'd27;   gamma_b_lut[10] = 8'd27;
        gamma_r_lut[11] = 8'd32;   gamma_b_lut[11] = 8'd32;
        gamma_r_lut[12] = 8'd38;   gamma_b_lut[12] = 8'd38;
        gamma_r_lut[13] = 8'd45;   gamma_b_lut[13] = 8'd45;
        gamma_r_lut[14] = 8'd52;   gamma_b_lut[14] = 8'd52;
        gamma_r_lut[15] = 8'd60;   gamma_b_lut[15] = 8'd60;
        gamma_r_lut[16] = 8'd68;   gamma_b_lut[16] = 8'd68;
        gamma_r_lut[17] = 8'd77;   gamma_b_lut[17] = 8'd77;
        gamma_r_lut[18] = 8'd87;   gamma_b_lut[18] = 8'd87;
        gamma_r_lut[19] = 8'd97;   gamma_b_lut[19] = 8'd97;
        gamma_r_lut[20] = 8'd108;  gamma_b_lut[20] = 8'd108;
        gamma_r_lut[21] = 8'd119;  gamma_b_lut[21] = 8'd119;
        gamma_r_lut[22] = 8'd131;  gamma_b_lut[22] = 8'd131;
        gamma_r_lut[23] = 8'd144;  gamma_b_lut[23] = 8'd144;
        gamma_r_lut[24] = 8'd157;  gamma_b_lut[24] = 8'd157;
        gamma_r_lut[25] = 8'd170;  gamma_b_lut[25] = 8'd170;
        gamma_r_lut[26] = 8'd184;  gamma_b_lut[26] = 8'd184;
        gamma_r_lut[27] = 8'd198;  gamma_b_lut[27] = 8'd198;
        gamma_r_lut[28] = 8'd213;  gamma_b_lut[28] = 8'd213;
        gamma_r_lut[29] = 8'd227;  gamma_b_lut[29] = 8'd227;
        gamma_r_lut[30] = 8'd242;  gamma_b_lut[30] = 8'd242;
        gamma_r_lut[31] = 8'd255;  gamma_b_lut[31] = 8'd255;

        // Green LUT (6-bit input)
        gamma_g_lut[ 0] = 8'd0;    gamma_g_lut[ 1] = 8'd0;    gamma_g_lut[ 2] = 8'd1;
        gamma_g_lut[ 3] = 8'd2;    gamma_g_lut[ 4] = 8'd3;    gamma_g_lut[ 5] = 8'd4;
        gamma_g_lut[ 6] = 8'd5;    gamma_g_lut[ 7] = 8'd6;    gamma_g_lut[ 8] = 8'd8;
        gamma_g_lut[ 9] = 8'd9;    gamma_g_lut[10] = 8'd11;   gamma_g_lut[11] = 8'd12;
        gamma_g_lut[12] = 8'd14;   gamma_g_lut[13] = 8'd16;   gamma_g_lut[14] = 8'd18;
        gamma_g_lut[15] = 8'd20;   gamma_g_lut[16] = 8'd22;   gamma_g_lut[17] = 8'd24;
        gamma_g_lut[18] = 8'd27;   gamma_g_lut[19] = 8'd29;   gamma_g_lut[20] = 8'd32;
        gamma_g_lut[21] = 8'd35;   gamma_g_lut[22] = 8'd38;   gamma_g_lut[23] = 8'd41;
        gamma_g_lut[24] = 8'd44;   gamma_g_lut[25] = 8'd47;   gamma_g_lut[26] = 8'd50;
        gamma_g_lut[27] = 8'd54;   gamma_g_lut[28] = 8'd57;   gamma_g_lut[29] = 8'd61;
        gamma_g_lut[30] = 8'd64;   gamma_g_lut[31] = 8'd68;   gamma_g_lut[32] = 8'd72;
        gamma_g_lut[33] = 8'd76;   gamma_g_lut[34] = 8'd80;   gamma_g_lut[35] = 8'd84;
        gamma_g_lut[36] = 8'd88;   gamma_g_lut[37] = 8'd92;   gamma_g_lut[38] = 8'd96;
        gamma_g_lut[39] = 8'd101;  gamma_g_lut[40] = 8'd105;  gamma_g_lut[41] = 8'd110;
        gamma_g_lut[42] = 8'd114;  gamma_g_lut[43] = 8'd119;  gamma_g_lut[44] = 8'd124;
        gamma_g_lut[45] = 8'd129;  gamma_g_lut[46] = 8'd134;  gamma_g_lut[47] = 8'd139;
        gamma_g_lut[48] = 8'd144;  gamma_g_lut[49] = 8'd149;  gamma_g_lut[50] = 8'd154;
        gamma_g_lut[51] = 8'd160;  gamma_g_lut[52] = 8'd165;  gamma_g_lut[53] = 8'd171;
        gamma_g_lut[54] = 8'd176;  gamma_g_lut[55] = 8'd182;  gamma_g_lut[56] = 8'd188;
        gamma_g_lut[57] = 8'd194;  gamma_g_lut[58] = 8'd200;  gamma_g_lut[59] = 8'd206;
        gamma_g_lut[60] = 8'd212;  gamma_g_lut[61] = 8'd218;  gamma_g_lut[62] = 8'd224;
        gamma_g_lut[63] = 8'd231;
    end

endmodule
