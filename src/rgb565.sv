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
    /* map out the pixel's data:
         rrrr rggg  gggb bbbb
       red and blue are only 5-bit, so we duplicate the LSB to make 6-bit values */
    assign red[5:0]   = { data_in[15:11], data_in[11] };
    assign green[5:0] = { data_in[10:5] };
    assign blue[5:0]  = { data_in[4:0], data_in[0] };
endmodule
