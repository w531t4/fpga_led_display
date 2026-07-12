// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Status register: command-SPI receive rate, in KBps.
//   - byte_pulse: one pulse per received command byte
//   - value: the rate over a sliding window, zero-padded to status_value_t
// Reads out in KBps with no divide:
//   - prescale bytes into quanta of (window_seconds * 1000) bytes each
//   - count quanta over a window_seconds window -> quanta == KBps
// Window/bins/prescale sizing lives in params::STATUS_RX_KBPS_*.
module reg_spi_rx_kbps #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                        clk,
    input                        reset,
    input                        byte_pulse,
    output types::status_value_t value
);
    wire quantum;
    event_prescaler #(
        .DIVISOR(params::STATUS_RX_KBPS_PRESCALE)
    ) prescaler (
        .clk      (clk),
        .reset    (reset),
        .pulse_in (byte_pulse),
        .pulse_out(quantum)
    );

    // Count of quanta over the window (0..BINS*BIN_TICKS, hence +1); quanta
    // == KBps, so `kbps` is the KBps figure. Sized to the meter's count port.
    typedef logic [calc::safe_clog2(
        params::STATUS_RX_KBPS_WINDOW_SECONDS * params::STATUS_RX_KBPS_BIN_TICKS + 1
    )-1:0] quantum_count_t;
    quantum_count_t kbps;
    event_rate_meter #(
        .BIN_TICKS(params::STATUS_RX_KBPS_BIN_TICKS),
        .BINS     (params::STATUS_RX_KBPS_WINDOW_SECONDS)
    ) meter (
        .clk        (clk),
        .reset      (reset),
        .event_pulse(quantum),
        .count      (kbps)
    );

    assign value = types::status_value_t'(kbps);
endmodule
