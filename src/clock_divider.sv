// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
/* simple clock divider
   counts from zero to the given value, and then toggles clk_out
     counts on positive edge of clk_in
     reset is active-high */

//so, essentially freq = clk_in / (clk_div_count * 2)
module clock_divider #(
    parameter CLK_DIV_COUNT = 3,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    output logic clk_out
);
    logic [$clog2(CLK_DIV_COUNT) - 1:0] clk_count;

`ifdef SIM
    logic reset_prev;
    initial begin
        reset_prev = 1'b0;
    end
`endif

    /*
    CLK_DIV_WIDTH=2;CLK_DIV_COUNT=3;
    t= 0:: clk_out=0;clk_count=0 => clk_out=0;clk_count=1
    t= 1:: clk_out=0;clk_count=1 => clk_out=0;clk_count=2
    t= 2:: clk_out=0;clk_count=2 => clk_out=1;clk_count=0
    t= 3:: clk_out=1;clk_count=0 => clk_out=1;clk_count=1
    t= 4:: clk_out=1;clk_count=1 => clk_out=1;clk_count=2
    t= 5:: clk_out=1;clk_count=2 => clk_out=0;clk_count=0 <--- start of matrix_scan cycle
    t= 6:: clk_out=0;clk_count=0 => clk_out=0;clk_count=1
    t= 7:: clk_out=0;clk_count=1 => clk_out=1;clk_count=2
    t= 8:: clk_out=0;clk_count=2 => clk_out=1;clk_count=0
    t= 9:: clk_out=1;clk_count=0 => clk_out=1;clk_count=1
    t=10:: clk_out=1;clk_count=1 => clk_out=1;clk_count=2
    t=11:: clk_out=1;clk_count=2 => clk_out=0;clk_count=0 <--- start of matrix_scan cycle
    */
`ifdef SIM
    always @(posedge clk_in) begin
        reset_prev <= (reset === 1'b1);
        if ((reset === 1'b1) && !reset_prev) begin
            clk_out   <= 1'b0;
            clk_count <= 'b0;
        end else begin
            if (clk_count == ($clog2(CLK_DIV_COUNT))'(CLK_DIV_COUNT - 1)) begin
                clk_out   <= ~clk_out;
                clk_count <= 'b0;
            end else begin
                clk_count <= clk_count + 'd1;
            end
        end
    end
`else
    always @(posedge clk_in) begin
        if (reset) begin
            clk_out   <= 1'b0;
            clk_count <= 'b0;
        end else begin
            if (clk_count == ($clog2(CLK_DIV_COUNT))'(CLK_DIV_COUNT - 1)) begin
                clk_out   <= ~clk_out;
                clk_count <= 'b0;
            end else begin
                clk_count <= clk_count + 'd1;
            end
        end
    end
`endif

endmodule
