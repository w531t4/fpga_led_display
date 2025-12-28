// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module cocotb_debugger_wrapper (
    input  wire        clk_in,
    input  wire        reset,
    input  wire [23:0] data_in,
    input  wire        debug_uart_rx_in,
    output wire        tx_out,
    output wire        debug_start,
    output wire [4:0]  currentState,
    output wire        do_close,
    output wire        tx_start,
    output wire [4:0]  current_position,
    output wire [7:0]  debug_command,
    output wire        debug_command_pulse,
    output wire        debug_command_busy
);
    debugger #(
        .DIVIDER_TICKS(1023),
        .DATA_WIDTH(24)
    ) dut (
        .clk_in(clk_in),
        .reset(reset),
        .data_in(data_in),
        .debug_uart_rx_in(debug_uart_rx_in),
        .tx_out(tx_out),
        .debug_start(debug_start),
        .currentState(currentState),
        .do_close(do_close),
        .tx_start(tx_start),
        .current_position(current_position),
        .debug_command(debug_command),
        .debug_command_pulse(debug_command_pulse),
        .debug_command_busy(debug_command_busy)
    );
endmodule
