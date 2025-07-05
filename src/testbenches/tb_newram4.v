`timescale 1ns/10ps
module tb_newram4;
// period = (1 / 50000000hz) / 2 = 10.00000
parameter SIM_HALF_PERIOD_NS = 10.00000;

    reg clk_a;
    reg clk_b;
    reg reset;
    reg local_reset;
    reg [11:0] ram_a_address;
    reg [10:0] ram_b_address;
    reg [1:0] ram_a_data_in;
    reg ram_a_clk_enable;
    reg ram_b_clk_enable;
    reg ram_a_wr;
    wire [1:0] ram_b_data_out;
    reg ram_a_reset;
    reg ram_b_reset;

    newram4 num0 (
         .DataInA(ram_a_data_in)
        ,.AddressA(ram_a_address)
        ,.AddressB(ram_b_address)
        ,.ClockA(clk_a)
        ,.ClockB(clk_b)
        ,.ClockEnA(ram_a_clk_enable)
        ,.ClockEnB(ram_b_clk_enable)
        ,.WrA(ram_a_wr)
        ,.ResetA(ram_a_reset)
        ,.ResetB(ram_b_reset)
        ,.QB(ram_b_data_out)
    );

    initial begin
        $dumpfile(`DUMP_FILE_NAME);
        $dumpvars(0, tb_newram4);
        clk_a = 0;
        clk_b = 0;
        reset = 0;
        local_reset = 0;
        ram_a_address = 0;
        ram_b_address = 0;
        ram_a_data_in = 2'b00;
        ram_a_clk_enable = 0;
        ram_b_clk_enable = 0;
        ram_a_wr = 0;
        ram_a_reset = 0;
        ram_b_reset = 0;

        @(posedge clk_a)
            local_reset = ! local_reset;
            reset = ! reset;
        @(posedge clk_a)
            local_reset = ! local_reset;
            reset = !reset;
        @(posedge clk_a)
            ram_a_clk_enable = 1;
            ram_b_clk_enable = 1;


        @(posedge clk_a)
            ram_a_wr = 1'b1;
        @(posedge clk_a)
        @(posedge clk_a)
            //ram_a_address = 0;
            ram_a_address = 12'b1111_1111_1111;
            ram_a_data_in = 2'b10;
        @(posedge clk_a)
        //@(posedge clk_a)
        @(posedge clk_a)
            ram_a_wr = 1'b0;
        @(posedge clk_a)
        @(posedge clk_a)
            ram_a_address = 12'b1111_1111_1101;
            ram_a_wr = 0;
        @(posedge clk_b)
        @(posedge clk_b)
        @(posedge clk_b)
        @(posedge clk_b)
            ram_b_address =  11'b1111_1111_111;
        @(posedge clk_b)

        @(posedge clk_b)
        @(posedge clk_b)
        @(posedge clk_b)

            $finish;
    end


//  initial
//    begin
//      $display("Printing Automatic Tasks");
//      fork
//        auto_print(3);
//        auto_print(6);
//        auto_print(1);
//      join
//      #10;
//
//      $display("Printing Non-Automatic Tasks");
//      fork
//        non_auto_print(3);
//        non_auto_print(6);
//        non_auto_print(1);
//      join
//    end
    always begin
        #SIM_HALF_PERIOD_NS  clk_a <=  ~clk_a;
        #SIM_HALF_PERIOD_NS  clk_b <=  ~clk_b;
    end

endmodule