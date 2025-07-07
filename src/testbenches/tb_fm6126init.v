module fm6126init_tb;
    reg clk_root;
    reg reset;
    wire mask_en;
    wire output_enable_out;
    wire [2:0] rgb1_out;
    wire [2:0] rgb2_out;
   always #5 clk_root <= ~clk_root;
   initial begin
         $dumpfile(`DUMP_FILE_NAME);
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
                .mask_en(mask_en),
                .rgb1_out(rgb1_out),
                .rgb2_out(rgb2_out),
                .latch_out(latch_out));
endmodule
