`timescale 1ns/1ns
`default_nettype none
module tb_clock_divider;

logic clk;
logic reset;
wire clk_out;
clock_divider  #(.CLK_DIV_COUNT(5))
  clock_divider_instance
  (
    .reset(reset),
    .clk_in(clk),
    .clk_out(clk_out)
  );

  initial
  begin
      $dumpfile(`DUMP_FILE_NAME);
      $dumpvars(0, tb_clock_divider);
    clk = 0;
    reset = 0;
  end

  initial
  #2 reset = ! reset;

  initial
  #3 reset = ! reset;

  initial
  #10000 $finish;

  always begin
     #5  clk <=  ! clk;
  end
  always begin
    #400 reset <= ! reset;
  end
endmodule
