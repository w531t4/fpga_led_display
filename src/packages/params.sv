// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package params;
    // verilator lint_off UNUSEDPARAM
`ifdef CLK_110
    parameter int unsigned ROOT_CLOCK = 110_000_000;
    parameter int unsigned PLL_SPEED = 5;
`elsif CLK_100
    parameter int unsigned ROOT_CLOCK = 100_000_000;
    parameter int unsigned PLL_SPEED = 4;
`elsif CLK_90
    parameter int unsigned ROOT_CLOCK = 90_000_000;
    parameter int unsigned PLL_SPEED = 3;
`elsif CLK_80
    parameter int unsigned ROOT_CLOCK = 80_000_000;
    parameter int unsigned PLL_SPEED = 2;
`elsif CLK_50
    parameter int unsigned ROOT_CLOCK = 50_000_000;
    parameter int unsigned PLL_SPEED = 1;
`else
    parameter int unsigned ROOT_CLOCK = 16_000_000;
    parameter int unsigned PLL_SPEED = 0;
`endif
    // !SPI
    // Use this to determine what baudrate to require at ctrl/rx_in
    parameter int unsigned CTRLR_UART_RX_FREQ_GOAL = 244444;
    parameter int unsigned CTRLR_CLK_TICKS_PER_BIT = $rtoi(ROOT_CLOCK / CTRLR_UART_RX_FREQ_GOAL * 1.0);

    // DEBUGGER
    // Describes the baudrate for sending messages to debugger client
    parameter int unsigned DEBUG_UART_TX_FREQ_GOAL = 115200;
    parameter int unsigned DEBUG_TX_UART_TICKS_PER_BIT = ROOT_CLOCK / DEBUG_UART_TX_FREQ_GOAL;
    parameter int unsigned DEBUG_UART_RX_FREQ_GOAL = 244444;
    parameter int unsigned DEBUG_MSGS_PER_SEC_TICKS = ROOT_CLOCK / DEBUG_UART_RX_FREQ_GOAL;

    // Use this to tune what clock freq we expose to matrix_scan
    parameter int unsigned DIVIDE_CLK_BY_X_FOR_MATRIX = 2;
    // FRAMEBUFFER FETCH
`ifdef USE_FM6126A
    parameter int unsigned FB_FETCH_TIMEOUT_TICKS = 2;
`else
    parameter int unsigned FB_FETCH_TIMEOUT_TICKS = 3;
`endif
    parameter int unsigned FB_FETCH_SAMPLE_TICK = FB_FETCH_TIMEOUT_TICKS - 1;

    // READY HOLDOFF
    parameter longint unsigned READY_HOLDOFF_MSEC = 50;
    parameter longint unsigned READY_HOLDOFF_TICKS = (longint'(ROOT_CLOCK) * READY_HOLDOFF_MSEC) / 1000;

    // USE_WATCHDOG
    // reset control logic if watchdog isn't satisfied within x seconds
    parameter real WATCHDOG_CONTROL_FREQ_GOAL = 1;  // 1 second
`ifdef WATCHDOG_CONTROL_TICKS
    parameter int unsigned WATCHDOG_CONTROL_TICKS = `WATCHDOG_CONTROL_TICKS;
`else
    parameter int unsigned WATCHDOG_CONTROL_TICKS = $rtoi(ROOT_CLOCK / WATCHDOG_CONTROL_FREQ_GOAL * 1.0);
`endif
    parameter logic [63:0] WATCHDOG_SIGNATURE_PATTERN = 64'hDEADBEEFFEEBDAED;
    parameter int unsigned WATCHDOG_SIGBYTES = ($bits(WATCHDOG_SIGNATURE_PATTERN) + 7) / 8;

    // SIM
`ifdef SIM_HALF_PERIOD_NS
    parameter real SIM_HALF_PERIOD_NS = `SIM_HALF_PERIOD_NS;
`else
    parameter real SIM_HALF_PERIOD_NS = ((1.0 / ROOT_CLOCK) * 1000000000) / 2.0;
`endif

    // SIM !SPI
    // Use smaller value in testbench so we don't infinitely sim.
    parameter int unsigned DEBUG_MSGS_PER_SEC_TICKS_SIM = 'd15;

    // SDRAM controller geometry/timing.
`ifdef SDRAM_DATA_BITS
    parameter int unsigned SDRAM_DATA_BITS = `SDRAM_DATA_BITS;
`else
    parameter int unsigned SDRAM_DATA_BITS = 16;
`endif
`ifdef SDRAM_DQM_BITS
    parameter int unsigned SDRAM_DQM_BITS = `SDRAM_DQM_BITS;
`else
    parameter int unsigned SDRAM_DQM_BITS = SDRAM_DATA_BITS / 8;
`endif
`ifdef SDRAM_BANK_BITS
    parameter int unsigned SDRAM_BANK_BITS = `SDRAM_BANK_BITS;
`else
    parameter int unsigned SDRAM_BANK_BITS = 2;
`endif
`ifdef SDRAM_ADDR_BITS
    parameter int unsigned SDRAM_ADDR_BITS = `SDRAM_ADDR_BITS;
`else
    parameter int unsigned SDRAM_ADDR_BITS = 13;
`endif
`ifdef SDRAM_ROW_BITS
    parameter int unsigned SDRAM_ROW_BITS = `SDRAM_ROW_BITS;
`else
    parameter int unsigned SDRAM_ROW_BITS = 13;
`endif
`ifdef SDRAM_COLUMN_BITS
    parameter int unsigned SDRAM_COLUMN_BITS = `SDRAM_COLUMN_BITS;
`else
    parameter int unsigned SDRAM_COLUMN_BITS = 9;
`endif
`ifdef SDRAM_BURST_LENGTH
    parameter int unsigned SDRAM_BURST_LENGTH = `SDRAM_BURST_LENGTH;
`else
    parameter int unsigned SDRAM_BURST_LENGTH = 4;
`endif
`ifdef SDRAM_CAS_LATENCY
    parameter int unsigned SDRAM_CAS_LATENCY = `SDRAM_CAS_LATENCY;
`else
    parameter int unsigned SDRAM_CAS_LATENCY = 2;
`endif
`ifdef SDRAM_TRP_CYCLES
    parameter int unsigned SDRAM_TRP_CYCLES = `SDRAM_TRP_CYCLES;
`else
    parameter int unsigned SDRAM_TRP_CYCLES = 2;
`endif
`ifdef SDRAM_TRCD_CYCLES
    parameter int unsigned SDRAM_TRCD_CYCLES = `SDRAM_TRCD_CYCLES;
`else
    parameter int unsigned SDRAM_TRCD_CYCLES = 2;
`endif
`ifdef SDRAM_TRFC_CYCLES
    parameter int unsigned SDRAM_TRFC_CYCLES = `SDRAM_TRFC_CYCLES;
`else
    parameter int unsigned SDRAM_TRFC_CYCLES = 7;
`endif
`ifdef SDRAM_TMRD_CYCLES
    parameter int unsigned SDRAM_TMRD_CYCLES = `SDRAM_TMRD_CYCLES;
`else
    parameter int unsigned SDRAM_TMRD_CYCLES = 2;
`endif
`ifdef SDRAM_INIT_WAIT_CYCLES
    parameter int unsigned SDRAM_INIT_WAIT_CYCLES = `SDRAM_INIT_WAIT_CYCLES;
`elsif SIM
    parameter int unsigned SDRAM_INIT_WAIT_CYCLES = 8;
`else
    parameter int unsigned SDRAM_INIT_WAIT_CYCLES = 10_000;
`endif
`ifdef SDRAM_REFRESH_INTERVAL_CYCLES
    parameter int unsigned SDRAM_REFRESH_INTERVAL_CYCLES = `SDRAM_REFRESH_INTERVAL_CYCLES;
`elsif SIM
    parameter int unsigned SDRAM_REFRESH_INTERVAL_CYCLES = 32;
`else
    parameter int unsigned SDRAM_REFRESH_INTERVAL_CYCLES = 781;
`endif

`ifdef RGB24
    parameter int unsigned _BYTES_PER_PIXEL = 3;
    parameter int unsigned _BRIGHTNESS_LEVELS = 8;
`else  //  RGB16
    parameter int unsigned _BYTES_PER_PIXEL = 2;
    parameter int unsigned _BRIGHTNESS_LEVELS = 6;
`endif  //  RGB24

`ifdef BYTES_PER_PIXEL
    parameter int unsigned BYTES_PER_PIXEL = `BYTES_PER_PIXEL;
`else
    parameter int unsigned BYTES_PER_PIXEL = _BYTES_PER_PIXEL;
`endif

`ifdef BRIGHTNESS_LEVELS
    parameter int unsigned BRIGHTNESS_LEVELS = `BRIGHTNESS_LEVELS;
`else
    parameter int unsigned BRIGHTNESS_LEVELS = _BRIGHTNESS_LEVELS;
`endif

`ifdef W128
`ifdef SIM
    parameter int unsigned _PIXEL_WIDTH = 64 * 6;
`else  // SIM
    parameter int unsigned _PIXEL_WIDTH = 64 * 12;
`endif  // SIM
`else  // W128
    parameter int unsigned _PIXEL_WIDTH = 64;
`endif  // W128
`ifdef PIXEL_WIDTH
    parameter int unsigned PIXEL_WIDTH = `PIXEL_WIDTH;
`else
    parameter int unsigned PIXEL_WIDTH = _PIXEL_WIDTH;
`endif

`ifdef PIXEL_HEIGHT
    parameter int unsigned PIXEL_HEIGHT = `PIXEL_HEIGHT;
`else
    parameter int unsigned PIXEL_HEIGHT = 32;
`endif

`ifdef PIXEL_HALFHEIGHT
    parameter int unsigned PIXEL_HALFHEIGHT = `PIXEL_HALFHEIGHT;
`else
    parameter int unsigned PIXEL_HALFHEIGHT = 16;
`endif

    parameter integer BRIGHTNESS_BASE_TIMEOUT = 10;
    parameter integer BRIGHTNESS_STATE_TIMEOUT_OVERLAP = 'd67;
`ifdef DOUBLE_BUFFER
    parameter integer unsigned NUM_FRAMEBUFFERS = 2;
`else
    parameter integer unsigned NUM_FRAMEBUFFERS = 1;
`endif
    // verilator lint_on UNUSEDPARAM
endpackage
