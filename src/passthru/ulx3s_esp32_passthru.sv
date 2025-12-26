// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// Generated with assistance from ChatGPT (OpenAI), 2025.
// No third-party source code was used.

`default_nettype none

module ulx3s_esp32_passthru (
    // required by your constraint file
    input wire clk_25mhz,

    // FTDI USB-serial
    output wire ftdi_rxd,   // FPGA -> FTDI (TX to host)
    input  wire ftdi_txd,   // FTDI -> FPGA (RX from host)
    input  wire ftdi_nrts,  // active-low modem control from host
    input  wire ftdi_ndtr,  // active-low modem control from host

    // ESP32 “wifi” UART
    output wire wifi_rxd,  // FPGA -> ESP32 RX0
    input  wire wifi_txd,  // ESP32 TX0 -> FPGA

    // ESP32 boot/reset controls
    output wire wifi_en,    // enable/reset
    output wire wifi_gpio0, // GPIO0 strap

    // present in your .lpf; leave unused but must exist if you don’t edit constraints
    input wire ftdi_txden,
    input wire ftdi_nrxled
);

  // UART passthru
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  // Auto-boot wiring (simple, no filtering/deglitching)
  // ftdi_* are active-low inputs; invert to get active-high asserted signals
  wire dtr = ~ftdi_ndtr;
  wire rts = ~ftdi_nrts;

  // Drive ESP32 into ROM bootloader using DTR/RTS (common convention):
  //   DTR asserted -> GPIO0 low
  //   RTS asserted -> EN low (reset)
  assign wifi_gpio0 = ~dtr;
  assign wifi_en    = ~rts;

endmodule
