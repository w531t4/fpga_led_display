// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Status register: framebuffer effective FPS -- the buffer-swap rate (each
// swap advances the displayed frame), in frames/second (sliding-window
// average). Always instantiated; without DOUBLE_BUFFER there is no swap
// signal, so it reads 0 (and builds no meter).
//   - toggle_signal (DOUBLE_BUFFER only): a level that flips on each swap,
//     in this clock domain (no CDC)
//   - value: the average rate over the window, zero-padded to status_value_t
// Reads out in Hz with no divide: turn each edge into a pulse, prescale by the
// window length, then count quanta over the window -> quanta == frames/second.
// Sizing lives in params::STATUS_FB_FPS_*.
module reg_fb_fps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                        clk,
    input                        reset,
`ifdef DOUBLE_BUFFER
    input                        toggle_signal,
`endif
    output types::status_value_t value
);
`ifdef DOUBLE_BUFFER
    // Each flip of toggle_signal is one swap -> a one-clk pulse (both edges).
    logic toggle_signal_q;
    always @(posedge clk) begin
        if (reset) toggle_signal_q <= 1'b0;
        else toggle_signal_q <= toggle_signal;
    end
    wire toggle_pulse = toggle_signal ^ toggle_signal_q;

    wire quantum;
    event_prescaler #(
        .DIVISOR(params::STATUS_FB_FPS_PRESCALE)
    ) prescaler (
        .clk      (clk),
        .reset    (reset),
        .pulse_in (toggle_pulse),
        .pulse_out(quantum)
    );

    // Count of quanta over the window (0..BINS*BIN_TICKS, hence +1); quanta
    // == frames/second, the averaged rate. Sized to the meter's count port.
    typedef logic [calc::safe_clog2(
        params::STATUS_FB_FPS_WINDOW_SECONDS * params::STATUS_FB_FPS_BIN_TICKS + 1
    )-1:0] quantum_count_t;
    quantum_count_t fps;
    event_rate_meter #(
        .BIN_TICKS(params::STATUS_FB_FPS_BIN_TICKS),
        .BINS     (params::STATUS_FB_FPS_WINDOW_SECONDS)
    ) meter (
        .clk        (clk),
        .reset      (reset),
        .event_pulse(quantum),
        .count      (fps)
    );

    assign value = types::status_value_t'(fps);
`else
    // No double buffering -> no swaps to count.
    assign value = '0;
    wire _unused_ok = &{1'b0, clk, reset, 1'b0};
`endif
endmodule
