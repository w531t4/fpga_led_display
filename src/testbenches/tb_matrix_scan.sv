`timescale 1ns/1ns
`default_nettype none
module tb_matrix_scan #(
  `ifdef SIM
  // period = (1 / 16000000hz) / 2 = 31.25000
    parameter SIM_HALF_PERIOD_NS = 31.25000*6, // *6 to match current clock divider in main
  `endif
    // verilator lint_off UNUSEDPARAM
    `include "params.vh"
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

logic clk;
logic reset;
wire [$clog2(PIXEL_WIDTH)-1:0] column_address;
wire [3:0] row_address;
wire [3:0] row_address_active;
wire clk_pixel_load;
wire clk_pixel;
wire row_latch;
wire output_enable;
wire [5:0] brightness_mask;


matrix_scan  #(
    .PIXEL_WIDTH(PIXEL_WIDTH),
    .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT)
) matrix_scan_instance (
    .clk_in(clk),
    .reset(reset),
    .column_address(column_address),
    .row_address(row_address),
    .row_address_active(row_address_active),
    .clk_pixel_load(clk_pixel_load),
    .clk_pixel(clk_pixel),
    .row_latch(row_latch),
    .output_enable(output_enable),
    .brightness_mask(brightness_mask)
  );
  initial
  begin
      `ifdef DUMP_FILE_NAME
          $dumpfile(`DUMP_FILE_NAME);
      `endif
      $dumpvars(0, tb_matrix_scan);
    clk = 0;
    reset = 0;
  end

  initial
  #2 reset = ! reset;

  initial
  #3 reset = ! reset;

  initial
  #10000000 $finish;

  always begin
      #SIM_HALF_PERIOD_NS clk <= !clk;
  end
 // always begin
   // #700 reset <= ! reset;
 // end
endmodule
