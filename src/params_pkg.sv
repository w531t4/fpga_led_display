// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package params_pkg;
`ifdef CLK_110
    parameter int unsigned ROOT_CLOCK = 110_000_000;
    parameter int unsigned PLL_SPEED = 4;
`elsif CLK_100
    parameter int unsigned ROOT_CLOCK = 100_000_000;
    parameter int unsigned PLL_SPEED = 3;
`elsif CLK_90
    parameter int unsigned ROOT_CLOCK = 90_000_000;
    parameter int unsigned PLL_SPEED = 2;
`elsif CLK_50
    parameter int unsigned ROOT_CLOCK = 50_000_000;
    parameter int unsigned PLL_SPEED = 1;
`else
    parameter int unsigned ROOT_CLOCK = 16_000_000;
    parameter int unsigned PLL_SPEED = 0;
`endif
`ifndef SPI
    // Use this to determine what baudrate to require at ctrl/rx_in
    parameter int unsigned CTRLR_UART_RX_FREQ_GOAL = 244444;
    parameter int unsigned CTRLR_CLK_TICKS_PER_BIT = $rtoi(ROOT_CLOCK / CTRLR_UART_RX_FREQ_GOAL * 1.0);
`endif
    // Use this to tune what clock freq we expose to matrix_scan
    parameter int unsigned DIVIDE_CLK_BY_X_FOR_MATRIX = 2;
`ifdef USE_WATCHDOG
    // reset control logic if watchdog isn't satisfied within x seconds
    parameter real WATCHDOG_CONTROL_FREQ_GOAL = 0.1;  // 10 seconds
    parameter int unsigned WATCHDOG_CONTROL_TICKS = $rtoi(ROOT_CLOCK / WATCHDOG_CONTROL_FREQ_GOAL * 1.0);
    parameter int unsigned WATCHDOG_SIGNATURE_BITS = 64;
`endif
`ifdef SIM
    // verilator lint_off UNUSEDPARAM
    parameter real SIM_HALF_PERIOD_NS = ((1.0 / ROOT_CLOCK) * 1000000000) / 2.0;
    // verilator lint_on UNUSEDPARAM
`ifndef SPI
    // Use smaller value in testbench so we don't infinitely sim.
    parameter int unsigned DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15;
`endif
`endif
`ifdef RGB24
    parameter int unsigned BYTES_PER_PIXEL = 3;
    parameter int unsigned BRIGHTNESS_LEVELS = 8;
`else
    parameter int unsigned BYTES_PER_PIXEL = 2;
    parameter int unsigned BRIGHTNESS_LEVELS = 6;
`endif
`ifdef W128
`ifdef SIM
    parameter int unsigned PIXEL_WIDTH = 64 * 6;
`else
    parameter int unsigned PIXEL_WIDTH = 64 * 12;
`endif
`else
    parameter int unsigned PIXEL_WIDTH = 64;
`endif
    parameter int unsigned PIXEL_HEIGHT = 32;
    parameter int unsigned PIXEL_HALFHEIGHT = 16;
endpackage
