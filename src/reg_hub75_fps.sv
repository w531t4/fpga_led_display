// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Status register: HUB75 frame-emit rate, in Hz (sliding-window average).
//   - frame_active: a level that rises once per emitted frame, async to clk
//     (synchronized into clk here)
//   - value: the average rate over the window, zero-padded to status_value_t
// Reads out in Hz with no divide: synchronize the frame edge, prescale frames
// by the window length, then count quanta over the window -> quanta == Hz.
// Sizing lives in params::STATUS_HUB75_FPS_*.
module reg_hub75_fps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                        clk,
    input                        reset,
    input                        frame_active,
    output types::status_value_t value
);
    // Bring the frame edge into this clock domain as a one-clk pulse.
    wire frame_active_synced;
    wire frame_pulse;
    ff_sync frame_sync (
        .clk       (clk),
        .signal    (frame_active),
        .reset     (reset),
        .sync_level(frame_active_synced),
        .sync_pulse(frame_pulse)
    );

    wire quantum;
    event_prescaler #(
        .DIVISOR(params::STATUS_HUB75_FPS_PRESCALE)
    ) prescaler (
        .clk      (clk),
        .reset    (reset),
        .pulse_in (frame_pulse),
        .pulse_out(quantum)
    );

    // Count of quanta over the window (0..BINS*BIN_TICKS, hence +1); quanta
    // == Hz, so `fps` is the averaged rate. Sized to the meter's count port.
    typedef logic [calc::safe_clog2(
params::STATUS_HUB75_FPS_WINDOW_SECONDS * params::STATUS_HUB75_FPS_BIN_TICKS + 1
)-1:0] quantum_count_t;
    quantum_count_t fps;
    event_rate_meter #(
        .BIN_TICKS(params::STATUS_HUB75_FPS_BIN_TICKS),
        .BINS     (params::STATUS_HUB75_FPS_WINDOW_SECONDS)
    ) meter (
        .clk        (clk),
        .reset      (reset),
        .event_pulse(quantum),
        .count      (fps)
    );

    assign value = types::status_value_t'(fps);

    wire _unused_ok = &{1'b0, frame_active_synced, 1'b0};
endmodule
