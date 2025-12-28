// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module cocotb_watchdog_wrapper (
    input  wire       reset,
    input  wire [7:0] data_in,
    input  wire       enable,
    input  wire       clk,
    output wire       sys_reset,
    output wire       done
);
    control_cmd_watchdog #(
        .WATCHDOG_CONTROL_TICKS(16 * 12)
    ) dut (
        .reset(reset),
        .data_in(data_in),
        .enable(enable),
        .clk(clk),
        .sys_reset(sys_reset),
        .done(done)
    );
endmodule
