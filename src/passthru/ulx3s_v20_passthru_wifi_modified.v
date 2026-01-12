// SPDX-License-Identifier: BSD-2-Clause
// SPDX-FileCopyrightText: (c) EMARD
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// Origin: https://raw.githubusercontent.com/emard/ulx3s-passthru/71ce18953f84ea8ee07bb42d42ddc5a2673623c3/rtl/ulx3s_v20_passthru_wifi.vhd
// Translated into Verilog by ChatGPT, then truncated to only things necessary to program ESP32
// (c)EMARD
// License=BSD

// ULX3S ESP32 passthrough — MINIMAL VERSION
// ONLY what is required to:
//   - Program ESP32 over FTDI USB serial
//   - Leave FPGA programming completely unaffected
`default_nettype none

module ulx3s_v20_passthru_wifi_modified (
    // Required clock (used only for timing-safe logic if expanded later)
    input wire clk_25mhz,

    // ===============================
    // FTDI USB SERIAL (REQUIRED)
    // ===============================
    output wire ftdi_rxd,
    input  wire ftdi_txd,
    inout  wire ftdi_ndtr,
    inout  wire ftdi_nrts,

    // ===============================
    // ESP32 SERIAL + STRAPS (REQUIRED)
    // ===============================
    output wire wifi_rxd,
    input  wire wifi_txd,
    output wire wifi_en,
    output wire wifi_gpio0
);

    // UART passthrough
    assign ftdi_rxd = wifi_txd;
    assign wifi_rxd = ftdi_txd;

    // DTR/RTS → EN/GPIO0 mapping
    wire [1:0] prog_in = {ftdi_ndtr, ftdi_nrts};
    wire [1:0] prog_out = (prog_in == 2'b10) ? 2'b01 : (prog_in == 2'b01) ? 2'b10 : 2'b11;

    assign wifi_en    = prog_out[1];
    assign wifi_gpio0 = prog_out[0];

endmodule
