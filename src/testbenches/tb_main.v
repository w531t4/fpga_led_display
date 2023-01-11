`timescale 1ns/100ps
module tb_main;
// context: RX DATA baud
// 50000000hz / 2444444hz = 20.4545 ticks width=5
// tgt_hz variation (after rounding): 2.27%
// 50000000hz / 2500000hz = 20 ticks width=5
parameter CTRLR_CLK_TICKS_PER_BIT = 5'd20;
parameter CTRLR_CLK_TICKS_WIDTH = 3'd5;


// context: TX DEBUG baud
// 50000000hz / 115200hz = 434.0278 ticks width=9
// tgt_hz variation (after rounding): 0.01%
// 50000000hz / 115207hz = 434 ticks width=9
parameter DEBUG_TX_UART_TICKS_PER_BIT = 9'd434;
parameter DEBUG_TX_UART_TICKS_PER_BIT_WIDTH = 4'd9;


// context: Debug msg rate
// 50000000hz / 22hz = 2272727.2727 ticks width=22
// tgt_hz variation (after rounding): 0.00%
// 50000000hz / 22hz = 2272727 ticks width=22
parameter DEBUG_MSGS_PER_SEC_TICKS = 22'd2272727;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH = 5'd22;


`ifdef SIM
// use smaller value in testbench so we don't infinitely sim
parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM = 3'd4;


// period = (1 / 50000000hz) / 2 = 10.00000
parameter SIM_HALF_PERIOD_NS = 10.00000;
`endif
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
    wire pin22;
    wire pin23_txout;
    reg  pin24_debug_rx_in;

    reg clk;
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
        .pin22(pin22),
        .pin23(pin23_txout),
        .pin24(pin24_debug_rx_in)
    );
    reg mask;
    debugger #(
		.DATA_WIDTH_BASE2(4'd12),
		.DATA_WIDTH(12'd2112),

        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
		.DIVIDER_TICKS_WIDTH(DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM),
		.DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS_SIM),

		// We're using the debugger here as a data transmitter only. Need
		// to transmit at the same speed as the controller is expecting to
		// receive at
        .UART_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT),
        .UART_TICKS_PER_BIT_SIZE(CTRLR_CLK_TICKS_WIDTH)
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
        #5000000 $finish;
    end
    always begin
        #SIM_HALF_PERIOD_NS clk <= !clk;
    end
endmodule
