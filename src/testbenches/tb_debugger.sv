`timescale 1ns/1ns
`default_nettype none
module tb_debugger #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);



    logic clk;
    logic reset;
    logic local_reset;
    logic [23:0] data_in;
    wire tx_out;
    logic clk_out;
    wire debug_start;
    logic debug_uart_rx_in;
    logic [1071:0] mystring = "01112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677-L Rrb";
    wire tb_clk_baudrate;
    logic rx_line2;
    logic [3:0] i = 'd0;
    logic [10:0] j = 'd0;

    clock_divider #(
        .CLK_DIV_COUNT(600)
    ) clkdiv_baudrate (
        .reset(local_reset),
        .clk_in(clk),
        .clk_out(tb_clk_baudrate)
    );

    debugger #(
        .DIVIDER_TICKS(1023),
        .DATA_WIDTH(24)
    )
    debug_instance (
        .clk_in(clk),
        .reset(reset),
        .data_in(data_in),
        .tx_out(tx_out),
        .debug_start(debug_start),
        .debug_uart_rx_in(rx_line2)
    );

    initial
        begin
            `ifdef DUMP_FILE_NAME
                $dumpfile(`DUMP_FILE_NAME);
            `endif
            $dumpvars(0, tb_debugger);
            clk = 0;
            reset = 0;
            local_reset = 0;
            rx_line2 = 0;
            clk_out = 0;
            data_in = 24'b111100001010101000001101;

        end


    always @(posedge tb_clk_baudrate) begin

        if (i == 'd10) begin
            rx_line2 <= 1'b0;
            if (j >= ($bits(mystring)-8)) begin
                j <= 'd0;
            end
            else begin
                j <= j + 'd8;
            end
            i <= 'd0;
        end
        else if (i == 'd9) begin
            rx_line2 <= 1'b1;
            i <= i+1;
        end
        else if (i == 'd8) begin
            rx_line2 <= 1'b1;
            i <= i+1;
        end
        else begin
            rx_line2 <= mystring[i + j];
            i <= i+1;
        end
    end
    initial begin
        #2 reset = ! reset;
       #2 local_reset = ! local_reset;
end
    initial begin
        #3 reset = ! reset;
    #3 local_reset = ! local_reset;
end

    initial
        #1000000 $finish;

    always begin
        #22.72727  clk <=  ! clk; // 2 of these make a period, 22MHz
    end
   // always begin
   //     #400 reset <= ! reset;
   // end
endmodule
