`timescale 1ns/1ns
`default_nettype none
module tb_ff_sync #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

logic clk;
logic reset;
logic signal;
logic sync_signal;

ff_sync  #(

) ff_sync_instance
  (
    .reset(reset),
    .clk(clk),
    .signal(signal),
    .sync_signal(sync_signal)
  );

  initial
  begin
      `ifdef DUMP_FILE_NAME
          $dumpfile(`DUMP_FILE_NAME);
      `endif
      $dumpvars(0, tb_ff_sync);
    clk = 0;
    reset = 0;
    signal = 0;
  end

  initial
  #2 reset = ! reset;

  initial
  #3 reset = ! reset;

  initial begin
    #SIM_HALF_PERIOD_NS signal = ~signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = ~signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = ~signal;
    #SIM_HALF_PERIOD_NS signal = ~signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = ~signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #SIM_HALF_PERIOD_NS signal = signal;
    #10 $finish;
  end

  always begin
      #SIM_HALF_PERIOD_NS clk <= !clk;
  end
endmodule
