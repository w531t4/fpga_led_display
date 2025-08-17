`timescale 1ns/1ns
`default_nettype none
module tb_matrix_scan #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam ADJUSTED_CLOCK = SIM_HALF_PERIOD_NS * DIVIDE_CLK_BY_X_FOR_MATRIX;
    logic clk;
    logic reset;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] column_address;
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
    initial begin
        `ifdef DUMP_FILE_NAME
            $dumpfile(`DUMP_FILE_NAME);
        `endif
        $dumpvars(0, tb_matrix_scan);
        clk = 0;
        reset = 0;
    end

    initial #2 reset = ! reset;
    initial #3 reset = ! reset;
    initial #10000000 $finish;

    always begin
        #ADJUSTED_CLOCK clk <= !clk;
    end
    // always begin
      // #700 reset <= ! reset;
    // end
endmodule
