// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7

// Use this to determine what baudrate to require at ctrl/rx_in
parameter CTRLR_CLK_TICKS_PER_BIT = 7'd65,

// Use this to tune what clock freq we expose to matrix_scan
parameter DIVIDE_CLK_BY_X_FOR_MATRIX = 3,

`ifdef DEBUGGER
    // context: TX DEBUG baud
    // 16000000hz / 115200hz = 138.8889 ticks width=8
    // tgt_hz variation (after rounding): -0.08%
    // 16000000hz / 115108hz = 139 ticks width=8
    parameter DEBUG_TX_UART_TICKS_PER_BIT = 8'd139,

    // context: Debug msg rate
    // 16000000hz / 22hz = 727272.7273 ticks width=20
    // tgt_hz variation (after rounding): -0.00%
    // 16000000hz / 22hz = 727273 ticks width=20
    parameter DEBUG_MSGS_PER_SEC_TICKS = 20'd727273,
`endif

`ifdef SIM
    // use smaller value in testbench so we don't infinitely sim
    parameter DEBUG_MSGS_PER_SEC_TICKS_SIM = 4'd15,
`endif

`ifdef W128
    parameter PIXEL_WIDTH = 128,
`else
    parameter PIXEL_WIDTH = 64,
`endif

parameter PIXEL_HEIGHT = 32,
parameter PIXEL_HALFHEIGHT = 16,
parameter BYTES_PER_PIXEL = 2,
