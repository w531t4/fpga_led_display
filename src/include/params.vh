// verilator lint_off UNUSEDPARAM
// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
`ifdef CLK_110
    parameter ROOT_CLOCK = 110_000_000,
    parameter PLL_SPEED = 4,
`elsif CLK_100
    parameter ROOT_CLOCK = 100_000_000,
    parameter PLL_SPEED = 3,
`elsif CLK_90
    parameter ROOT_CLOCK = 90_000_000,
    parameter PLL_SPEED = 2,
`elsif CLK_50
    parameter ROOT_CLOCK = 50_000_000,
    parameter PLL_SPEED = 1,
`else
    parameter ROOT_CLOCK = 16_000_000,
    parameter PLL_SPEED = 0,
`endif

`ifndef SPI
    // Use this to determine what baudrate to require at ctrl/rx_in
    parameter CTRLR_UART_RX_FREQ_GOAL = 244444,
    parameter CTRLR_CLK_TICKS_PER_BIT = $rtoi(ROOT_CLOCK / CTRLR_UART_RX_FREQ_GOAL * 1.0),
`endif

// Use this to tune what clock freq we expose to matrix_scan
parameter DIVIDE_CLK_BY_X_FOR_MATRIX = 2,

`ifdef USE_WATCHDOG
    // reset control logic if watchdog isn't satisfied within x seconds
    parameter WATCHDOG_CONTROL_FREQ_GOAL = 0.5, // 2 seconds
    parameter WATCHDOG_CONTROL_TICKS = $rtoi(ROOT_CLOCK / WATCHDOG_CONTROL_FREQ_GOAL * 1.0),
    parameter WATCHDOG_SIGNATURE_BITS = 64,
    parameter WATCHDOG_SIGNATURE_PATTERN = 64'hDEADBEEFFEEBDAED,
`endif

`ifdef DEBUGGER
    // context: TX DEBUG baud
    // 16000000hz / 115200hz = 138.8889 ticks width=8
    // tgt_hz variation (after rounding): -0.08%
    // 16000000hz / 115108hz = 139 ticks width=8
    parameter DEBUG_UART_TX_FREQ_GOAL = 115200,
    parameter DEBUG_TX_UART_TICKS_PER_BIT = ROOT_CLOCK / DEBUG_UART_TX_FREQ_GOAL,

    // context: Debug msg rate
    // 16000000hz / 22hz = 727272.7273 ticks width=20
    // tgt_hz variation (after rounding): -0.00%
    // 16000000hz / 22hz = 727273 ticks width=20
    parameter DEBUG_UART_RX_FREQ_GOAL = 244444,
    parameter DEBUG_MSGS_PER_SEC_TICKS = ROOT_CLOCK / DEBUG_UART_RX_FREQ_GOAL,
`endif

`ifdef SIM
    `ifndef SPI
        // use smaller value in testbench so we don't infinitely sim
        parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15,
    `endif
    // period = (1 / 16000000hz) / 2 = 31.25000 //31.25000*6, // *6 to match current clock divider in main
    parameter SIM_HALF_PERIOD_NS = ((1.0/ROOT_CLOCK) * 1000000000)/2.0, //31.25,
`endif

`ifdef W128
    parameter PIXEL_WIDTH = 64*12,
`else
    parameter PIXEL_WIDTH = 64,
`endif

parameter PIXEL_HEIGHT = 32,
parameter PIXEL_HALFHEIGHT = 16,


`ifdef RGB24
    parameter BYTES_PER_PIXEL = 3,
    parameter BRIGHTNESS_LEVELS = 8,
`else
    parameter BYTES_PER_PIXEL = 2,
    parameter BRIGHTNESS_LEVELS = 6,
`endif
//verilator lint_on UNUSEDPARAM
