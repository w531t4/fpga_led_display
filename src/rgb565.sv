`default_nettype none
module rgb565 #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input [15:0] data_in,

    output [4:0] red,
    output [5:0] green,
    output [4:0] blue
);
    assign red[4:0]   = data_in[15:11];
    assign green[5:0] = data_in[10:5];
    assign blue[4:0]  = data_in[4:0];
endmodule
