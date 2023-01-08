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
    wire pin7_uart_rx;
    wire pin8_row_latch;
    wire pin9_OE;
    wire pin10_clk_pixel;
    wire pin12_rgb2_0;
    wire pin13_rgb2_1;
    wire pin18_rbg2_2;
    wire pin19_rgb1_0;
    wire pin20_rgb1_1;
    wire pin21_rgb1_2;
    wire pin23_txout;
    reg  pin24_debug_rx_in;

    reg clk;
    reg clk_22mhz;
    reg reset;
    reg local_reset;

    // debugger stuff
    wire debug_command_busy;
    wire debug_command_pulse;
    wire [7:0] debug_command;

    //>>> "".join([a[i] for i in range(len(a)-1, -1, -1)])
    //'brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110'
    //reg [1071:0] mystring = "brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110";
    //reg [1071:0] mystring = 'h627252204c2d3737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313130;
    reg [2111:0] mystring = 'h627252204c2d37373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313131304c133737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313130;
    main tbi_main (
        .pin3_clk_16mhz(clk),
        .pin3(pin3_ROA0),
        .pin4(pin4_ROA1),
        .pin5(pin5_ROA2),
        .pin6(pin6_ROA3),
        .pin7(pin7_uart_rx),
        .pin8(pin8_row_latch),
        .pin9(pin9_OE),
        .pin10(pin10_clk_pixel),
        .pin12(pin12_rgb2_0),
        .pin13(pin13_rgb2_1),
        .pin18(pin18_rgb2_2),
        .pin19(pin19_rgb1_0),
        .pin20(pin20_rgb1_1),
        .pin21(pin21_rgb1_2),
        .pin23(pin23_txout),
        .pin24(pin24_debug_rx_in)
    );
    reg mask;
    debugger #(
		// 22MHz / 1000000 = 22
		//.DIVIDER_TICKS_WIDTH(20),
		//.DIVIDER_TICKS(1000000),
        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
		.DIVIDER_TICKS_WIDTH(9),
		.DIVIDER_TICKS(500),
		.DATA_WIDTH_BASE2('d12),
		.DATA_WIDTH('d2112),
        // override the below params to override the default transmit speeds
        // 2444444 baud @ 22mhZ
        .UART_TICKS_PER_BIT(4'd9),
        .UART_TICKS_PER_BIT_SIZE(4)
        // 22MHz / 1222222 = 18
        //.UART_TICKS_PER_BIT(5'd18),
        //.UART_TICKS_PER_BIT_SIZE(5)
	) mydebug (
        .clk_in(clk && mask),
		.reset(local_reset),
		.data_in(mystring),
		.debug_uart_rx_in(1'b0),
		.debug_command(debug_command),
		.debug_command_pulse(debug_command_pulse),
		.debug_command_busy(debug_command_busy),
		.tx_out(pin7_uart_rx)
	);

    integer j;
    initial begin
        $dumpfile(`DUMP_FILE_NAME);
        $dumpvars(0, tb_main);
        clk = 0;
        mask = 0;


        pin24_debug_rx_in = 0;
        reset = 0;
        local_reset = 0;
        repeat (20) begin
            @(posedge clk);
        end
        @(posedge clk)
            local_reset = ! local_reset;
            reset = ! reset;
        @(posedge clk)
            local_reset = ! local_reset;
            reset = ! reset;
        repeat (175) begin
            @(posedge clk);
        end
        //@(posedge clk)
        //    local_reset = ! local_reset;
        //@(posedge clk)
        //    local_reset = ! local_reset;
        repeat (5) begin
            @(posedge clk);
        end
        @(posedge clk)
            mask = 1;

        //repeat (200000) begin
        //    @(posedge clk);
        //end
        //@(posedge clk)
        //    local_reset = ! local_reset;
        //    reset = ! reset;
        //@(posedge clk)
        //    local_reset = ! local_reset;
        //    reset = ! reset;
        //$finish;
        #10000000 $finish;
    end
    always begin
        //#222.72727  clk_22mhz <= ! clk_22mhz; // 2 of these make a period, 22MHz
        #31.25000  clk <=  ! clk; // 2 of these make a period, 16MHz
        //#204.545   tb_clk_baudrate <= ! tb_clk_baudrate; // 2444444hz
    end
    // always begin
    //     #400 reset <= ! reset;
    // end
endmodule
