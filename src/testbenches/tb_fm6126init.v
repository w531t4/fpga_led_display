module fm6126init_tb;
    reg clk_root;
	reg reset;
	wire output_enable_in;
	wire [2:0] rgb1_in;
	wire [2:0] rgb2_in;
	wire latch_in;
	wire output_enable_out;
	wire [2:0] rgb1_out;
	wire [2:0] rgb2_out;
    wire done;
   always #5 clk_root <= ~clk_root;
   initial begin
         $dumpfile("fm6126init.vcd");
         $dumpvars(0, fm6126init_tb);
         clk_root = 0;
         reset = 0;
         #5 reset = 1;
         #6 reset = 0;
         #100000 $finish;
   end
   fm6126init fm6126init(
                .clk_in(clk_root),
                .reset(reset),
                .output_enable_in(output_enable_in),
                .rgb1_in(rgb1_in),
                .rgb2_in(rgb2_in),
                .latch_in(latch_in),
                .output_enable_out(output_enable_out),
                .rgb1_out(rgb1_out),
                .rgb2_out(rgb2_out),
                .latch_out(latch_out),
                .done(done));
endmodule
