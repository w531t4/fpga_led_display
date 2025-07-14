`timescale 1ns/1ns
`default_nettype none
module tb_clock_divider #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

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
      `ifdef DUMP_FILE_NAME
          $dumpfile(`DUMP_FILE_NAME);
      `endif
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
      #SIM_HALF_PERIOD_NS clk <= !clk;
  end
  always begin
    #400 reset <= ! reset;
  end
endmodule
