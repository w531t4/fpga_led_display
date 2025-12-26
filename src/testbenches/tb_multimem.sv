// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns `default_nettype none
module tb_multimem #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk_a;
    logic clk_b;
    logic reset;
    logic local_reset;
    logic [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] ram_a_address;
    logic [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-3:0] ram_b_address;
    logic [7:0] ram_a_data_in;
    logic ram_a_clk_enable;
    logic ram_b_clk_enable;
    logic ram_a_wr;
    wire [((PIXEL_HEIGHT / PIXEL_HALFHEIGHT) * BYTES_PER_PIXEL * 8)-1:0] ram_b_data_out;
    logic ram_a_reset;
    logic ram_b_reset;

    multimem #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) A (
        .DataInA(ram_a_data_in),
        .AddressA(ram_a_address),
        .AddressB(ram_b_address),
        .ClockA(clk_a),
        .ClockB(clk_b),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable),
        .WrA(ram_a_wr),
        .ResetA(ram_a_reset),
        .ResetB(ram_b_reset),
        .QB(ram_b_data_out)
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_multimem);
        clk_a = 0;
        clk_b = 0;
        reset = 0;
        local_reset = 0;
        ram_a_address = 0;
        ram_b_address = 0;
        ram_a_data_in = 0;
        ram_a_clk_enable = 0;
        ram_b_clk_enable = 0;
        ram_a_wr = 0;
        ram_a_reset = 0;
        ram_b_reset = 0;

        @(posedge clk_a) begin
            local_reset = !local_reset;
            reset = !reset;
            ram_a_reset = !ram_a_reset;
            ram_b_reset = !ram_b_reset;
        end
        @(posedge clk_a) begin
            local_reset = !local_reset;
            reset = !reset;
            ram_a_reset = !ram_a_reset;
            ram_b_reset = !ram_b_reset;
            #10 $dumpoff;
            #190000 $dumpon;
        end
        @(negedge clk_a) do_write_start(12'b1111_1111_1111, "A");
        @(posedge clk_a) @(negedge clk_a) do_write_end();
        //@(posedge clk_a)


        @(negedge clk_a) do_write_start(12'b1111_1111_1110, "B");
        @(posedge clk_a) @(negedge clk_a) do_write_end();
        //@(posedge clk_a)


        @(negedge clk_a) ram_b_clk_enable = 1;
        do_read_start(11'b1111_1111_111);
        @(posedge clk_a) @(posedge clk_a) do_read_end();
        //@(posedge clk_a)


        @(negedge clk_a) do_write_start(12'b1111_1111_1111, "C");
        @(posedge clk_a) @(negedge clk_a) do_write_end();

        @(negedge clk_a) do_read_start(11'b1111_1111_111);
        @(posedge clk_a) @(negedge clk_a) do_read_end();



        @(negedge clk_a) do_write_start(12'b1111_1111_1111, "D");
        @(posedge clk_a)
        @(negedge clk_a)
        //do_write_end();
        do_write_start(
            12'b1111_1111_1110, "E");
        do_read_start(11'b1111_1111_111);
        @(posedge clk_a)
        @(negedge clk_a)
        //do_write_end();
        do_write_start(
            12'b1111_1111_1110, "F");
        do_read_start(11'b1111_1111_111);
        @(posedge clk_a) @(negedge clk_a) do_read_start(11'b1111_1111_111);
        do_write_end();
        @(posedge clk_a) do_read_end();


        // test "half_address"
        @(negedge clk_a) do_write_start(12'b0111_1111_1111, "Z");
        @(posedge clk_a)
        @(negedge clk_a)
        //do_write_end();
        do_write_start(
            12'b0111_1111_1110, "Y");
        do_read_start(11'b0111_1111_111);
        @(posedge clk_a)
        @(negedge clk_a)
        //do_write_end();
        do_write_start(
            12'b0111_1111_1110, "R");
        do_read_start(11'b0111_1111_111);
        @(posedge clk_a) @(negedge clk_a) do_read_start(11'b0111_1111_111);
        do_write_end();
        @(posedge clk_a) do_read_end();
        //@(posedge clk_a)

        // end padding
        #400;

        //@(posedge clk_a)
        //    ram_a_clk_enable = 1;
        //    ram_b_clk_enable = 1;


        // @(posedge clk_a)
        //    ram_a_wr = 1'b1;
        // @(posedge clk_a)
        // @(posedge clk_a)
        //    //ram_a_address = 0;
        //    ram_a_address = 12'b1111_1111_1111;
        //    ram_a_data_in = "A";
        // @(posedge clk_a)
        // @(posedge clk_a)
        //    //ram_a_address = 0;
        //    ram_a_address = 12'b1111_1111_1110;
        //    ram_a_data_in = "B";
        // @(posedge clk_a)
        // //@(posedge clk_a)
        // @(posedge clk_a)
        //    ram_a_wr = 1'b0;
        // @(posedge clk_a)
        // @(posedge clk_a)
        //    ram_a_address = 12'b1111_1111_1101;
        //    ram_a_wr = 0;
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        //    ram_b_address =  11'b1111_1111_111;
        // @(posedge clk_b)

        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_a)
        //    ram_a_wr = 1'b1;
        // @(posedge clk_a)
        //    //ram_a_address = 0;
        //    ram_a_address = 12'b1111_1111_1111;
        //    ram_a_data_in = "C";
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        // @(posedge clk_b)
        $finish;
    end

    task automatic do_write_start;
        input [11:0] address;
        input [7:0] data;
        begin
            ram_a_address = address;
            ram_a_data_in = data;
            ram_a_clk_enable = 1;
            ram_a_wr = 1'b1;
        end
    endtask

    task automatic do_write_end;
        begin
            ram_a_clk_enable = 0;
            ram_a_wr = 1'b0;
        end
    endtask

    task automatic do_read_start;
        input [10:0] address;
        begin
            ram_b_clk_enable = 1;
            ram_b_address = address;
        end
    endtask

    task automatic do_read_end;
        begin
            ram_b_clk_enable = 0;
        end
    endtask

    always begin
        #SIM_HALF_PERIOD_NS clk_a <= ~clk_a;
        #SIM_HALF_PERIOD_NS clk_b <= ~clk_b;
    end

endmodule
