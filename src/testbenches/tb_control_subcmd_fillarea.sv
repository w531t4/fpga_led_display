`timescale 1ns/1ns
`default_nettype none
module tb_control_subcmd_fillarea #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam BYTES_PER_PIXEL = 2;
    localparam WIDTH = 3;
    localparam HEIGHT = 4;
    localparam OUT_BITWIDTH = 8;
    logic clk;
    logic subcmd_enable;
    wire [$clog2(WIDTH)-1:0] column;
    wire [$clog2(HEIGHT)-1:0] row;
    wire [$clog2(BYTES_PER_PIXEL)-1:0] pixel;
    wire ram_write_enable;
    wire ram_access_start;
    wire done;
    wire pre_done;

    wire [OUT_BITWIDTH-1:0] data_out;
    logic reset;

    control_subcmd_fillarea #(
    ) subcmd_fillarea (
        .reset(reset),
        .enable(subcmd_enable),
        .clk(clk),
        .ack(done),
        .x1(0),
        .y1(0),
        .width(($clog2(WIDTH))'(WIDTH)),
        .height(($clog2(HEIGHT))'(HEIGHT)),
        .color({(BYTES_PER_PIXEL*8){1'b0}}),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(pre_done)
    );

    initial begin
        `ifdef DUMP_FILE_NAME
            $dumpfile(`DUMP_FILE_NAME);
        `endif
        $dumpvars(0, tb_control_subcmd_fillarea);
        clk = 0;
        reset = 1;
        subcmd_enable = 0;


        // finish reset for tb
        @(posedge clk) reset = ~reset;

        // // wait for tb_main/global_reset to fall
        // wait (!tb_main.tbi_main.global_reset);
        repeat (20) begin
            @(posedge clk);
        end
        // #(($bits(myled_row) + 1000)*SIM_HALF_PERIOD_NS*2*4); // HALF_CYCLE * 2, to get period. 4, because master spi divides primary clock by 4. 1000 for kicks
        // wait (tb_main.tbi_main.row_address_active == 4'b0101);
        $finish;
    end
    always begin
        #2 clk <= !clk;
    end
endmodule
