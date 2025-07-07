`default_nettype none
`timescale 1ms/1ns
module tb_matrix_scan;

reg clk;
reg reset;
wire [5:0] column_address;
wire [3:0] row_address;
wire [3:0] row_address_active;
wire clk_pixel_load;
wire clk_pixel;
wire row_latch;
wire output_enable;
wire [5:0] brightness_mask;

matrix_scan  matrix_scan_instance
  (
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
      $dumpfile(`DUMP_FILE_NAME);
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
     #5  clk <=  ! clk;
  end
 // always begin
   // #700 reset <= ! reset;
 // end
endmodule
