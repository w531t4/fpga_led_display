// context: RX DATA baud
// 16000000hz / 244444hz = 65.4547 ticks width=7
// tgt_hz variation (after rounding): 0.70%
// 16000000hz / 246154hz = 65 ticks width=7
parameter CTRLR_CLK_TICKS_PER_BIT = 7'd65,

`ifdef W128
    parameter PIXEL_WIDTH = 128,
`else
    parameter PIXEL_WIDTH = 64,
`endif
parameter PIXEL_HEIGHT = 32,
parameter PIXEL_HALFHEIGHT = 16,
parameter BYTES_PER_PIXEL = 2,
