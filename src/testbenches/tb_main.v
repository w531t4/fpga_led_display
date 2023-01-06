`timescale 1ns/10ps
/*
iverilog -s tb_main -vvvv -o  blah.vvp tb_main.v control_module.v tb_control_module.v tb_debugger.v \
    debugger.v tb_uart_rx.v uart_rx.v timeout.v clock_divider.v syncore_ram.v \
    /home/awhite/lscc/iCEcube2.2017.08/LSE/cae_library/synthesis/verilog/sb_ice40.v uart_tx.v \
    debug_uart_rx.v main.v framebuffer_fetch.v matrix_scan.v newram2.v pixel_split.v brightness.v \
    rgb565.v Multiported-RAM/mpram_gen.v Multiported-RAM/mpram.v Multiported-RAM/mpram_xor.v \
    Multiported-RAM/mrram.v Multiported-RAM/dpram.v Multiported-RAM/utils.vh && vvp blah.vvp
    */
module tb_main;

    reg pin3_clk;
    wire pin3_ROA0;
    wire pin4_ROA1;
    wire pin5_ROA2;
    wire pin6_ROA3;
    reg pin7_uart_rx;
    wire pin8_row_latch;
    wire pin9_OE;
    wire pin10_clk_pixel;
    wire pin12_rgb1_0;
    wire pin13_rgb1_1;
    wire pin18_rbg1_2;
    wire pin19_rgb2_0;
    wire pin20_rgb2_1;
    wire pin23_txout;
    reg  pin24_debug_rx_in;

    /*
    assign pin3_clk = clk;
    assign pin24_debug_rx_in = 1'b1;
    assign pin7_uart_rx = rx_line_pics;
    */
    reg clk;
    reg reset;
    reg local_reset;
    wire tx_out;
    //reg clk_out;
    wire debug_start;
    reg debug_uart_rx_in;
    reg [1071:0] mystring = "01112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677-L Rrb";

    wire tb_clk_baudrate;
    wire tb_clk_debug;
    reg rx_line_pics1;

    reg [3:0] i = 'd0;
    reg [10:0] j = 'd0;
    reg rx_line_debug;

    main tbi_main (
        //.pin1_usb_dp,
        //.pin2_usb_dn,
        .pin3_clk_16mhz(clk),
        .pin3(pin3_ROA0),
        .pin4(pin4_ROA1),
        .pin5(pin5_ROA2),
        .pin6(pin6_ROA3),
        .pin7(rx_line_pics),
        //.pin7(pin7_uart_rx),
        .pin8(pin8_row_latrch),
        .pin9(pin9_OE),
        .pin10(pin10_clk_pixel),
        //.pin11(),
        .pin12(pin12_rgb1_0),
        .pin13(pin13_rgb1_1),
        .pin18(pin18_rgb1_2),
        .pin19(pin19_rgb2_0),
        .pin20(pin20_rgb2_1),
        //.pin21(),
        //.pin22(),
        .pin23(pin23_txout)
        //.pin24(1'b1)
        //.pin24(pin24_debug_rx_in)
        ////.pin24(rx_line_debug)
        //.pinLED()
    );


    clock_divider #(
        .CLK_DIV_COUNT(600),
        .CLK_DIV_WIDTH(12)
    ) clkdiv_debug (
        .reset(local_reset),
        .clk_in(clk),
        .clk_out(tb_clk_debug)
    );
    clock_divider #(
        .CLK_DIV_COUNT(25),
        .CLK_DIV_WIDTH(6)
    ) clkdiv_baudrate (
        .reset(local_reset),
        .clk_in(clk),
        .clk_out(tb_clk_baudrate)
    );


    initial
        begin
            $dumpfile(`DUMP_FILE_NAME);
            $dumpvars(0, tb_main);
            clk = 0;
            reset = 0;
            local_reset = 0;
           // rx_line_debug = 1;
            rx_line_pics1 = 0;
           // clk_out = 0;
            //data_in = 24'b111100001010101000001101;

        end

/*
    always @(posedge tb_clk_debug) begin

        if (i == 'd10) begin
            rx_line_debug <= 1'b0;
            if (j >= ($bits(mystring)-8)) begin
                j <= 'd0;
            end
            else begin
                j <= j + 'd8;
            end
            i <= 'd0;
        end
        else if (i == 'd9) begin
            rx_line_debug <= 1'b1;
            i <= i+1;
        end
        else if (i == 'd8) begin
            rx_line_debug <= 1'b1;
            i <= i+1;
        end
        else begin
            rx_line_debug <= mystring[i + j];
            i <= i+1;
        end
    end
    */

    always @(posedge tb_clk_baudrate) begin

        if (i == 'd10) begin
            rx_line_pics1 <= 1'b0;
            if (j >= ($bits(mystring)-8)) begin
                j <= 'd0;
            end
            else begin
                j <= j + 'd8;
            end
            i <= 'd0;
        end
        else if (i == 'd9) begin
            rx_line_pics1 <= 1'b1;
            i <= i+1;
        end
        else if (i == 'd8) begin
            rx_line_pics1 <= 1'b1;
            i <= i+1;
        end
        else begin
            rx_line_pics1 <= mystring[i + j];
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
        rx_line_debug <= 1'b1;
        #3.73095  clk <=  ! clk; // 2 of these make a period, 134MHz
    end
    // always begin
    //     #400 reset <= ! reset;
    // end
endmodule
