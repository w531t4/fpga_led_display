`timescale 1ns/10ps
module tb_test;
    reg clk = 0;

    reg blah = 0;


    initial
        begin
            $dumpfile("tb_test.vcd");
            $dumpvars(0, tb_test);
            clk = 0;
        end

    always @(posedge clk) begin
        #7.52 blah <=clk;
    end
    always begin
        #7.52  clk <=  ! clk;  // produces ~133MHz
    end
    initial
        #10000000 $finish;


endmodule