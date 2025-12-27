// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilator lint_off UNUSEDPARAM
// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
`ifdef USE_WATCHDOG
    parameter WATCHDOG_SIGNATURE_BITS = 64,
    parameter WATCHDOG_SIGNATURE_PATTERN = 64'hDEADBEEFFEEBDAED,
`endif

`ifdef DEBUGGER
    // context: TX DEBUG baud
    // 16000000hz / 115200hz = 138.8889 ticks width=8
    // tgt_hz variation (after rounding): -0.08%
    // 16000000hz / 115108hz = 139 ticks width=8
    parameter DEBUG_UART_TX_FREQ_GOAL = 115200,
    parameter DEBUG_TX_UART_TICKS_PER_BIT = params_pkg::ROOT_CLOCK / DEBUG_UART_TX_FREQ_GOAL,

    // context: Debug msg rate
    // 16000000hz / 22hz = 727272.7273 ticks width=20
    // tgt_hz variation (after rounding): -0.00%
    // 16000000hz / 22hz = 727273 ticks width=20
    parameter DEBUG_UART_RX_FREQ_GOAL = 244444,
    parameter DEBUG_MSGS_PER_SEC_TICKS = params_pkg::ROOT_CLOCK / DEBUG_UART_RX_FREQ_GOAL,
`endif

`ifdef SIM
    `ifndef SPI
        // use smaller value in testbench so we don't infinitely sim
        parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15,
    `endif
    // period = (1 / 16000000hz) / 2 = 31.25000 //31.25000*6, // *6 to match current clock divider in main
    parameter SIM_HALF_PERIOD_NS = ((1.0/params_pkg::ROOT_CLOCK) * 1000000000)/2.0, //31.25,
`endif

// ROOT_CLOCK, PLL_SPEED, CTRLR_UART_RX_FREQ_GOAL, CTRLR_CLK_TICKS_PER_BIT, DIVIDE_CLK_BY_X_FOR_MATRIX,
// WATCHDOG_CONTROL_FREQ_GOAL, WATCHDOG_CONTROL_TICKS, PIXEL_WIDTH, PIXEL_HEIGHT, PIXEL_HALFHEIGHT,
// BYTES_PER_PIXEL, and BRIGHTNESS_LEVELS now live in params_pkg.sv
//verilator lint_on UNUSEDPARAM
