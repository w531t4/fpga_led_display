`timescale 1ns/1ns
`default_nettype none
module tb_main_uart;
// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
parameter CTRLR_CLK_TICKS_PER_BIT = 7'd65;
parameter CTRLR_CLK_TICKS_WIDTH = 3'd7;


// context: TX DEBUG baud
// 16000000hz / 115200hz = 138.8889 ticks width=8
// tgt_hz variation (after rounding): -0.08%
// 16000000hz / 115108hz = 139 ticks width=8
parameter DEBUG_TX_UART_TICKS_PER_BIT = 8'd139;
parameter DEBUG_TX_UART_TICKS_PER_BIT_WIDTH = 4'd8;


// context: Debug msg rate
// 16000000hz / 22hz = 727272.7273 ticks width=20
// tgt_hz variation (after rounding): -0.00%
// 16000000hz / 22hz = 727273 ticks width=20
parameter DEBUG_MSGS_PER_SEC_TICKS = 20'd727273;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH = 5'd20;


`ifdef SIM
// use smaller value in testbench so we don't infinitely sim
parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;
parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM = 3'd4;


// period = (1 / 16000000hz) / 2 = 31.25000
parameter SIM_HALF_PERIOD_NS = 31.25000;
`endif
    logic clk;
    wire clk_pixel;
    wire row_latch;
    wire OE;
    wire ROA0;
    wire ROA1;
    wire ROA2;
    wire ROA3;
    wire uart_rx;
    wire rgb2_0;
    wire rgb2_1;
    wire rgb2_2;
    wire rgb1_0;
    wire rgb1_1;
    wire rgb1_2;
    wire debugger_txout;
    logic  debugger_rxin;

    logic reset;
    logic local_reset;

    // debugger stuff
    wire debug_command_busy;
    wire debug_command_pulse;
    wire [7:0] debug_command;

    //>>> "".join([a[i] for i in range(len(a)-1, -1, -1)])
    //'brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110'


    // 260 * 8 = 2080
    logic [2079:0] myled_row = 'h4c040000000098000000000000009800000081a000000000000081a0000094c000000000000094c00000042000000000000004200000044f0000000000000000000002100000000000000000000000160000000000000016000040130000000000004013000000000000881100000000000000000000000098000000000000000000;
    main tbi_main (
        .gp11(clk_pixel),
        .gp12(row_latch),
        .gp13(OE),
        .clk_25mhz(clk),
        .gp7(ROA0),
        .gp8(ROA1),
        .gp9(ROA2),
        .gp10(ROA3),
        .gp0(rgb1_0),
        .gp1(rgb1_1),
        .gp2(rgb1_2),
        .gp3(rgb2_2),
        .gp4(rgb2_0),
        .gp5(rgb2_1),
        .gp14(uart_rx),
        .gp16(debugger_txout),
        .gp15(debugger_rxin),
        .gn11(),
        .gn12(),
        .gn13(),
        .gn7(),
        .gn8(),
        .gn9(),
        .gn10(),
        .gn0(),
        .gn1(),
        .gn2(),
        .gn3(),
        .gn4(),
        .gn5()
    );
    logic mask;
    debugger #(
        .DATA_WIDTH_BASE2(4'd13),
        .DATA_WIDTH(13'd2080),

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
        .data_in(myled_row),
        .debug_uart_rx_in(1'b0),
        .debug_command(debug_command),
        .debug_command_pulse(debug_command_pulse),
        .debug_command_busy(debug_command_busy),
        .tx_out(uart_rx)
    );

    initial begin
        $dumpfile(`DUMP_FILE_NAME);
        // $dumpvars(0, tb_main_uart);
        $dumpvars(1, tb_main_uart.mydebug.data_in);
        $dumpvars(1, tb_main_uart.mydebug.debug_bits);
        $dumpvars(1, tb_main_uart.mydebug.currentState);
        $dumpvars(1, tb_main_uart.mydebug.tx_busy);
        $dumpvars(1, tb_main_uart.mydebug.tx_done);
        $dumpvars(1, tb_main_uart.mydebug.tx_out);
        $dumpvars(1, tb_main_uart.mydebug.tx_start);
        // $dumpvars(1, tb_main_uart.mydebug);
        // $dumpvars(1, tb_main_uart.mydebug.tx_out);
        $dumpvars(1, tb_main_uart.tbi_main.clk_root);
        $dumpvars(1, tb_main_uart.tbi_main.debug_command_busy);
        $dumpvars(1, tb_main_uart.tbi_main.debug_command_pulse);
        $dumpvars(1, tb_main_uart.tbi_main.uart_rx);
        $dumpvars(1, tb_main_uart.tbi_main.ctrl);
        clk = 0;
        mask = 0;

        //123456y
        debugger_rxin = 0;
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
        repeat (20) begin
            @(posedge clk);
        end
        repeat (5) begin
            @(posedge clk);
        end
        @(posedge clk)
            mask = 1;
        #15000000 $finish;
    end
    always begin
        #SIM_HALF_PERIOD_NS clk <= !clk;
    end
endmodule
