`timescale 1ns/1ns
`default_nettype none
module tb_control_module #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

logic clk;
logic reset;
logic local_reset;
wire rx_line;
//20220106
//logic [7:0] ram_data_in = 8'b01100101;
wire [2:0] rgb_enable;
wire [5:0] brightness_enable;
wire [7:0] ram_data_out;
wire [$clog2(PIXEL_HEIGHT)+$clog2((PIXEL_WIDTH * BYTES_PER_PIXEL) - 1)-1:0] ram_address;
wire ram_write_enable;

wire ram_clk_enable;
wire ram_reset;
`ifdef DEBUGGER
    wire [1:0] cmd_line_state2;
    wire [7:0] num_commands_processed;
`endif
// debugger stuff
wire debug_command_busy;
wire debug_command_pulse;
wire [7:0] debug_command;

wire [7:0] uart_rx_data;
wire uart_rx_running_presync;
wire uart_rx_running_sync;
wire uart_rx_dataready;

//>>> "".join([a[i] for i in range(len(a)-1, -1, -1)])
//'brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110'
logic [1071:0] mystring = "brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110";
//logic tb_clk_baudrate;

    uart_rx #(
        // we want 22MHz / 2,430,000 = 9.0534
        // 22MHz / 9 = 2,444,444 baud 2444444
        .TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
    ) mycontrol_rxuart (
        .reset(reset),
        .i_clk(clk),
        .i_enable(1'b1),
        .i_din_priortobuffer(rx_line),
        .o_rxdata(uart_rx_data),
        .o_recvdata(uart_rx_dataready),
        .o_busy(uart_rx_running_presync)
    );

    // bring uart-data into main clock domain
    ff_sync #(
    ) uart_sync (
        .clk(clk),
        .signal(uart_rx_running_presync),
        .sync_signal(uart_rx_running_sync),
        .reset(reset)
    );

control_module #(
        // Picture/Video data RX baud rate
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL)
    ) control_module_instance (
        .reset(reset),
        .clk_in(clk),
        .data_rx(uart_rx_data),
        .data_ready_n(uart_rx_running_sync),
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        //20220106
        //.ram_data_in(ram_data_in),
        .ram_data_out(ram_data_out),
        .ram_address(ram_address),
        .ram_write_enable(ram_write_enable),
        .ram_clk_enable(ram_clk_enable),
        .ram_reset(ram_reset)
        //20220106
        //.rx_invalid(rx_invalid),
        `ifdef DEBUGGER
            ,
            .cmd_line_state2(cmd_line_state2),
            .num_commands_processed(num_commands_processed)
        `endif
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
        .tx_out(rx_line)
    );

  initial
  begin
      `ifdef DUMP_FILE_NAME
          $dumpfile(`DUMP_FILE_NAME);
      `endif
      $dumpvars(0, tb_control_module);
      clk = 0;
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
    repeat (20000) begin
        @(posedge clk);
    end
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    @(posedge clk)
        local_reset = ! local_reset;
        reset = ! reset;
    $finish;
  end

always begin
    #SIM_HALF_PERIOD_NS clk <= !clk;
end

endmodule
