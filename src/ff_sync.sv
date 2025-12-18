// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module ff_sync #(
    // Double flop synchronizer with rising edge detection
    // verilator lint_off UNUSEDPARAM
    parameter INIT_STATE = 1,
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire clk,
    input wire signal,
    input wire reset,

    output wire sync_level,  // synchronized signal (level)
    output wire sync_pulse   // one-cycle pulse on rising edge
);

    logic temp, sync, prev;

    assign sync_level = sync;
    assign sync_pulse = sync & ~prev;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            temp <= INIT_STATE;
            sync <= INIT_STATE;
            prev <= INIT_STATE;
        end else begin
            temp <= signal;
            sync <= temp;
            prev <= sync;
        end
    end
endmodule
