// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_control_module #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter real SIM_HALF_PERIOD_NS = params::SIM_HALF_PERIOD_NS,
    parameter integer unsigned CTRLR_CLK_TICKS_PER_BIT = params::CTRLR_CLK_TICKS_PER_BIT,
    parameter integer unsigned DEBUG_MSGS_PER_SEC_TICKS_SIM = params::DEBUG_MSGS_PER_SEC_TICKS_SIM,
    parameter integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS,
    parameter integer unsigned WATCHDOG_SIGNATURE_BITS = params::WATCHDOG_SIGNATURE_BITS,
    parameter logic [WATCHDOG_SIGNATURE_BITS-1:0] WATCHDOG_SIGNATURE_PATTERN = params::WATCHDOG_SIGNATURE_PATTERN,
    parameter int unsigned WATCHDOG_CONTROL_TICKS = params::WATCHDOG_CONTROL_TICKS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
    logic local_reset;

    //20220106
    //logic [7:0] ram_data_in = 8'b01100101;
    wire [2:0] rgb_enable;
    wire types::brightness_level_t brightness_enable;
    wire [calc::num_data_a_bits()-1:0] ram_data_out;
    wire types::mem_write_addr_t ram_address;
    wire ram_write_enable;
    wire ctrl_busy;
    wire ram_clk_enable;
`ifdef DEBUGGER
    wire [7:0] num_commands_processed;
`endif

    wire [7:0] rxdata_to_controller;
    wire rxdata;
    wire rxdata_ready;
    wire rxdata_ready_level;
    wire rxdata_ready_pulse;
`ifdef SPI
    logic [7:0] thebyte;
    wire spi_master_txdone;
    integer i;
    wire spi_clk;
    wire spi_cs;
    logic spi_start;
`else
    wire uart_rx_dataready;
`endif
    localparam integer unsigned mystring_size = 'd1072;
    logic [1071:0] mystring = "brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110";
    //logic tb_clk_baudrate;

`ifdef SPI
    wire [7:0] unused_rdata;
    wire unused_sdout;
    spi_master #() spimaster (
        .rstb (~reset),
        .clk  (clk),
        .mlb  (1'b1),               // shift msb first
        .start(spi_start),          // indicator to start activity
        .tdat (thebyte),
        .cdiv (2'b0),               // 2'b0 = divide by 4
        .din  (1'b0),               // data from slave, disable
        .ss   (spi_cs),             // chip select for slave
        .sck  (spi_clk),            // clock to send to slave
        .dout (rxdata),             // data to send to slave
        .done (spi_master_txdone),
        .rdata(unused_rdata)
    );
    spi_slave spislave (
        .rstb (~reset),
        .ten  (1'b0),                 // transmit enable, 0 = disabled
        .tdata(8'b0),
        .mlb  (1'b1),                 // shift msb first
        .ss   (spi_cs),
        .sck  (spi_clk),
        .sdin (rxdata),               // data coming from master
        .sdout(unused_sdout),
        .done (rxdata_ready),         // data ready
        .rdata(rxdata_to_controller)  // data
    );
    // verilog_format: off
    wire _unused_ok_ifdef_spi = &{1'b0,
                                  1'(CTRLR_CLK_TICKS_PER_BIT),
                                  1'(DEBUG_MSGS_PER_SEC_TICKS_SIM),
                                  unused_rdata,
                                  unused_sdout,
                                  1'b0};
    // verilog_format: on
`else
    uart_rx #(
        // we want 22MHz / 2,430,000 = 9.0534
        // 22MHz / 9 = 2,444,444 baud 2444444
        .TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
    ) mycontrol_rxuart (
        .reset(reset),
        .i_clk(clk),
        .i_enable(1'b1),
        .i_din_priortobuffer(rxdata),
        .o_rxdata(rxdata_to_controller),
        .o_recvdata(uart_rx_dataready),
        .o_busy(rxdata_ready)
    );
    debugger #(
        .DATA_WIDTH(1072),
        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
        .DIVIDER_TICKS(DEBUG_MSGS_PER_SEC_TICKS_SIM),

        // We're using the debugger here as a data transmitter only. Need
        // to transmit at the same speed as the controller is expecting to
        // receive at
        .UART_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
    ) mydebug (
        .clk_in(clk),
        .reset(local_reset),
        .data_in(mystring),
        .debug_uart_rx_in(1'b0),
        .debug_command(debug_command),
        .debug_command_pulse(debug_command_pulse),
        .debug_command_busy(debug_command_busy),
        .tx_out(rxdata)
    );
`endif
    // bring uart-data into main clock domain
    ff_sync #() uart_sync (
        .clk(clk),
        .signal(rxdata_ready),
        .sync_level(rxdata_ready_level),
        .sync_pulse(rxdata_ready_pulse),
        .reset(reset)
    );
    wire [2:0] _unused_ok_main;
    control_module #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .BRIGHTNESS_LEVELS(BRIGHTNESS_LEVELS),
        .WATCHDOG_SIGNATURE_BITS(WATCHDOG_SIGNATURE_BITS),
        .WATCHDOG_SIGNATURE_PATTERN(WATCHDOG_SIGNATURE_PATTERN),
        .WATCHDOG_CONTROL_TICKS(WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) control_module_instance (
        .reset(reset),
        .clk_in(clk),
        .busy(ctrl_busy),
        .data_rx(rxdata_to_controller),
`ifdef SPI
        .data_ready_n(~rxdata_ready_pulse),
`else
        .data_ready_n(rxdata_ready_pulse),
`endif
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        .ready_for_data(_unused_ok_main[0]),
`ifdef DOUBLE_BUFFER
        .frame_select(_unused_ok_main[1]),
`endif
`ifdef USE_WATCHDOG
        .watchdog_reset(_unused_ok_main[2]),
`endif
        //20220106
        //.ram_data_in(ram_data_in),
        .ram_data_out(ram_data_out),
        .ram_address(ram_address),
        .ram_write_enable(ram_write_enable),
        .ram_clk_enable(ram_clk_enable)
        //20220106
        //.rx_invalid(rx_invalid),
`ifdef DEBUGGER,
        .num_commands_processed(num_commands_processed)
`endif
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_module);
        clk = 0;
        reset = 0;
        local_reset = 0;
`ifdef SPI
        i = 0;
        spi_start = 0;
        thebyte = 8'b0;
`endif

        @(posedge clk) begin
            local_reset = !local_reset;
            reset = !reset;
        end
        @(posedge clk) begin
            local_reset = !local_reset;
            reset = !reset;
        end
`ifdef SPI
        @(posedge clk) spi_start = 1;
`endif
        repeat (300) begin
            @(posedge clk);
        end
        $finish;
    end

`ifdef SPI
    always begin
        @(posedge spi_master_txdone) begin
            if ((i < (mystring_size / 8))) begin
                thebyte <= mystring[mystring_size-1-(i*8)-:8];
                i <= i + 1;
            end
        end
    end
`endif
    always begin
        #(SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        rxdata_ready_level,
                        rgb_enable,
                        brightness_enable,
                        ram_data_out,
                        ram_address,
                        ram_write_enable,
                        ctrl_busy,
                        ram_clk_enable,
                        1'b0};
    // verilog_format: on
endmodule
