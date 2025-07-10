`timescale 1ns/1ns
`default_nettype none
module tb_control_module;
// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
parameter CTRLR_CLK_TICKS_PER_BIT = 7'd65;


// context: TX DEBUG baud
// 16000000hz / 115200hz = 138.8889 ticks width=8
// tgt_hz variation (after rounding): -0.08%
// 16000000hz / 115108hz = 139 ticks width=8
parameter DEBUG_TX_UART_TICKS_PER_BIT = 8'd139;

// context: Debug msg rate
// 16000000hz / 22hz = 727272.7273 ticks width=20
// tgt_hz variation (after rounding): -0.00%
// 16000000hz / 22hz = 727273 ticks width=20
parameter DEBUG_MSGS_PER_SEC_TICKS = 20'd727273;

`ifdef SIM
// use smaller value in testbench so we don't infinitely sim
parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;

// period = (1 / 16000000hz) / 2 = 31.25000
parameter SIM_HALF_PERIOD_NS = 31.25000;
`endif
logic clk;
logic reset;
logic local_reset;
wire rx_line;
//20220106
//logic [7:0] ram_data_in = 8'b01100101;
wire rx_running;
wire [2:0] rgb_enable;
wire [5:0] brightness_enable;
wire [7:0] ram_data_out;
wire [11:0] ram_address;
wire ram_write_enable;
wire [7:0] num_commands_processed;
wire ram_clk_enable;
wire ram_reset;
wire [1:0] cmd_line_state2;


// debugger stuff
wire debug_command_busy;
wire debug_command_pulse;
wire [7:0] debug_command;

//>>> "".join([a[i] for i in range(len(a)-1, -1, -1)])
//'brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110'
logic [1071:0] mystring = "brR L-77665544332211887766554433221188776655443322118877665544332211887766554433221188776655443322118877665544332211887766554433221110";
//logic tb_clk_baudrate;


control_module #(
        // Picture/Video data RX baud rate
        .UART_CLK_TICKS_PER_BIT(CTRLR_CLK_TICKS_PER_BIT)
    ) control_module_instance (
        .reset(reset),
        .clk_in(clk),
        .uart_rx(rx_line),
        .rx_running(rx_running),
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        //20220106
        //.ram_data_in(ram_data_in),
        .ram_data_out(ram_data_out),
        .ram_address(ram_address),
        .ram_write_enable(ram_write_enable),
        .ram_clk_enable(ram_clk_enable),
        .ram_reset(ram_reset),
        //20220106
        //.rx_invalid(rx_invalid),
        .cmd_line_state2(cmd_line_state2),
        .num_commands_processed(num_commands_processed)
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
      $dumpfile(`DUMP_FILE_NAME);
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
