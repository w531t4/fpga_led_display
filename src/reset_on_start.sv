// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module reset_on_start #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  wire clock_in,
    output wire reset
);
`ifdef SIM
    localparam integer unsigned counter = 8;
`else
    localparam integer unsigned counter = 2;
`endif
    typedef logic [$clog2(counter+1)-1:0] counter_count_t;
    logic count;
    logic objective;

    wire counter_count_t unused_timer_counter;
    initial begin
        count = 1'b0;
        objective = 1'b0;
    end

    always @(posedge clock_in) begin
        if (objective == 1'b0 && count == 1'b0) begin
            count <= ~count;
        end else if (objective == 1'b0 && count == 1'b1) begin
            objective <= 1'b1;
            count <= ~count;
        end
    end
    // TODO: Is + 1 really neccessary here?
    timeout_sync #(
        .COUNTER_WIDTH($bits(counter_count_t))
    ) reset_on_start_timeout (
        .reset  (count),
        .clk_in (clock_in),
        .start  (objective),
        .value  (counter_count_t'(counter)),
        .counter(unused_timer_counter),
        .running(reset)
    );
    wire _unused_ok = &{1'b0, unused_timer_counter, 1'b0};
endmodule
