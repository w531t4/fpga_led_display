// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Status register: uptime -- whole seconds elapsed since reset.
//   - value: seconds since `reset` last deasserted, zero-padded to
//     status_value_t
// No divide: an event_prescaler fed a constant 1 (every clock is an "event")
// emits one 1 Hz tick per ROOT_CLOCK clocks; a plain counter accrues ticks.
// The counter is STATUS_UPTIME_SECONDS_BITS wide, so it wraps only after
// ~136 years -- effectively never.
module reg_uptime_seconds #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                        clk,
    input                        reset,
    output types::status_value_t value
);
    // One 1 Hz tick per ROOT_CLOCK clocks.
    wire tick_1hz;
    event_prescaler #(
        .DIVISOR(params::ROOT_CLOCK)
    ) second_tick (
        .clk      (clk),
        .reset    (reset),
        .pulse_in (1'b1),
        .pulse_out(tick_1hz)
    );

    // Seconds since reset; plain counter, cleared by reset.
    typedef logic [params::STATUS_UPTIME_SECONDS_BITS-1:0] seconds_t;
    seconds_t seconds;
    always @(posedge clk) begin
        if (reset) seconds <= '0;
        else if (tick_1hz) seconds <= seconds + 1'b1;
    end

    assign value = types::status_value_t'(seconds);
endmodule
