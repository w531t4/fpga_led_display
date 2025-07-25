`timescale 1ns/1ns
`default_nettype none
module tb_main #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    wire clk_pixel;
    wire row_latch;
    wire OE;
    wire ROA0;
    wire ROA1;
    wire ROA2;
    wire ROA3;
    wire rgb2_0;
    wire rgb2_1;
    wire rgb2_2;
    wire rgb1_0;
    wire rgb1_1;
    wire rgb1_2;
    wire debugger_txout;
    logic  debugger_rxin;

    logic reset;

    // debugger stuff
    wire debug_command_busy;
    wire debug_command_pulse;
    wire [7:0] debug_command;

    `include "row4.vh"

    wire rxdata;
    `ifdef SPI
        logic [7:0] thebyte;
        wire spi_master_txdone;
        integer i;
        wire spi_clk;
        wire spi_cs;
        wire spi_data_ready;
        logic spi_start;
    `else
        wire uart_rx_dataready;
    `endif

    main #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) tbi_main (
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
        .gp14(rxdata),
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
        `ifdef SPI
            ,
            .gp17(rxdata),  // spi miso
            //.gp18() // spi_mosi
            .gp19(spi_clk),  // spi_clk
            .gp20(spi_cs)   // spi_cs
        `endif
    );
    `ifdef SPI
        spi_master #(
        ) spimaster (
            .rstb(~reset),
            .clk(clk),
            .mlb(1'b1),     // shift msb first
            .start(spi_start),  // indicator to start activity
            .tdat(thebyte),
            .cdiv(2'b0),    // 2'b0 = divide by 4
            .din(1'b0),     // data from slave, disable
            .ss(spi_cs),        // chip select for slave
            .sck(spi_clk),      // clock to send to slave
            .dout(rxdata),    // data to send to slave
            .done(spi_master_txdone),
            .rdata()
        );
    `else
        debugger #(
            .DATA_WIDTH(myled_row_size),
            // use smaller than normal so it doesn't require us to simulate to
            // infinity to see results
            .DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS_SIM),

            // We're using the debugger here as a data transmitter only. Need
            // to transmit at the same speed as the controller is expecting to
            // receive at
            .UART_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
        ) mydebug (
            .clk_in(clk),
            .reset(reset),
            .data_in(myled_row),
            .debug_uart_rx_in(1'b0),
            .debug_command(debug_command),
            .debug_command_pulse(debug_command_pulse),
            .debug_command_busy(debug_command_busy),
            .tx_out(rxdata)
        );
    `endif

    initial begin
        `ifdef DUMP_FILE_NAME
            $dumpfile(`DUMP_FILE_NAME);
        `endif
        `ifdef FOCUS_TB_MAIN_UART
            // $dumpvars(0, tb_main);
            $dumpvars(1, tb_main.mydebug.data_in);
            $dumpvars(1, tb_main.mydebug.debug_bits);
            $dumpvars(1, tb_main.mydebug.currentState);
            $dumpvars(1, tb_main.mydebug.tx_busy);
            $dumpvars(1, tb_main.mydebug.tx_done);
            $dumpvars(1, tb_main.mydebug.tx_out);
            $dumpvars(1, tb_main.mydebug.tx_start);
            // $dumpvars(1, tb_main.mydebug);
            // $dumpvars(1, tb_main.mydebug.tx_out);
            $dumpvars(1, tb_main.tbi_main.clk_root);
            $dumpvars(1, tb_main.mydebug.debug_command_busy);
            $dumpvars(1, tb_main.mydebug.debug_command_pulse);
            $dumpvars(1, tb_main.tbi_main.rxdata);
            $dumpvars(1, tb_main.tbi_main.ctrl);
        `else
            $dumpvars(0, tb_main);
        `endif
        clk = 0;
        `ifdef SPI
            i = 0;
            thebyte = 8'd0;
        `endif

        debugger_rxin = 0;
        reset = 1;

        // get past undefined period for global_reset. look for rising edge.
        wait (tb_main.tbi_main.global_reset);
        // finish reset for tb
        @(posedge clk) reset = ~reset;
        // wait for tb_main/global_reset to fall
        wait (!tb_main.tbi_main.global_reset);

        // wait until next clk_root goes high
        wait (tb_main.tbi_main.clk_root);
        // @(posedge tb_main.tbi_main.clk_root);
        `ifdef SPI
            @(posedge clk) begin
                spi_start = 1;
            end
        `endif
        @(posedge clk)
        #((myled_row_size + 1000)*SIM_HALF_PERIOD_NS*2*4); // HALF_CYCLE * 2, to get period. 4, because master spi divides primary clock by 4. 1000 for kicks
        wait (tb_main.tbi_main.row_address_active == 4'b0101);
        $finish;
    end
    `ifdef SPI
        always begin
            @(posedge spi_master_txdone) begin
                if ((i < (myled_row_size / 8))) begin
                    thebyte <= myled_row[myled_row_size-1 - (i*8) -: 8];
                    i <= i+1;
                end
            end
        end
    `endif
    always begin
        #SIM_HALF_PERIOD_NS clk <= !clk;
    end
endmodule
