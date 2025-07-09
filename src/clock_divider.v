/* simple clock divider
   counts from zero to the given value, and then toggles clk_out
     counts on positive edge of clk_in
     reset is active-high */

     //so, essentially freq = clk_in / (clk_div_count * 2)
module clock_divider #(
    parameter CLK_DIV_WIDTH = 8,
    parameter CLK_DIV_COUNT = 0
) (
    input reset,
    input clk_in,
    output reg clk_out
);
    reg [CLK_DIV_WIDTH - 1:0] clk_count;

    always @(posedge clk_in, posedge reset) begin
        if (reset) begin
            clk_out <= 1'b0;
            clk_count <= 'b0;
        end
        else begin
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
            if (clk_count == (CLK_DIV_COUNT - 1)) begin
                clk_out <= ~clk_out;
                clk_count <= 'b0;
            end
            else begin
                clk_count <= clk_count + 'd1;
            end
        end
    end

endmodule
