// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`include "sim_data.svh"
`ifdef RGB24
`ifdef W128
localparam types::readrow_cmd_t cmd_readrow = types::readrow_cmd_t'({
    cmd::READROW, types::row_addr_view_t'('h04), types::row_data_t'(`W384_RGB24_ROW_HEX)
});
localparam types::readframe_cmd_t cmd_readframe = types::readframe_cmd_t'({cmd::READFRAME, `W384_RGB24_FRAME_HEX});
`else  // W128
localparam types::readrow_cmd_t cmd_readrow = types::readrow_cmd_t'({
    cmd::READROW, types::row_addr_view_t'('h04), types::row_data_t'(`W64_RGB24_ROW_HEX)
});
localparam types::readframe_cmd_t cmd_readframe = types::readframe_cmd_t'({cmd::READFRAME, `W64_RGB24_FRAME_HEX});

`endif  // W128
`else  // RGB24
`ifdef W128
localparam types::readrow_cmd_t cmd_readrow = types::readrow_cmd_t'({
    cmd::READROW, types::row_addr_view_t'('h04), types::row_data_t'(`W384_RGB565_ROW_HEX)
});
localparam types::readframe_cmd_t cmd_readframe = types::readframe_cmd_t'({cmd::READFRAME, `W384_RGB565_FRAME_HEX});

`else  // W128
localparam types::readrow_cmd_t cmd_readrow = types::readrow_cmd_t'({
    cmd::READROW, types::row_addr_view_t'('h04), types::row_data_t'(`W64_RGB565_ROW_HEX)
});
localparam types::readframe_cmd_t cmd_readframe = types::readframe_cmd_t'({cmd::READFRAME, `W64_RGB565_FRAME_HEX});
`endif  // W128
`endif  // RGB24
// Add tests for pixel set command
localparam types::brightness3_cmd_t cmd_brightness_1 = types::brightness3_cmd_t'({cmd::BRIGHTNESS_THREE});

localparam types::readbrightness_cmd_t cmd_brightness_2 = types::readbrightness_cmd_t'({
    cmd::READBRIGHTNESS, types::brightness_level_view_t'('h23)
});  // "T" + \x23
localparam types::readbrightness_cmd_t cmd_brightness_3 = types::readbrightness_cmd_t'({
    cmd::READBRIGHTNESS, types::brightness_level_view_t'('h38)
});  // "T" + \x38

localparam types::blankpanel_cmd_t cmd_blankpanel = types::blankpanel_cmd_t'({cmd::BLANKPANEL});

`ifdef USE_WATCHDOG
localparam types::watchdog_cmd_t cmd_watchdog = types::watchdog_cmd_t'({
    cmd::WATCHDOG, types::watchdog_pattern_t'(params::WATCHDOG_SIGNATURE_PATTERN)
});  // "W" + "DEADBEEFFEEBDAED"
`endif  // USE_WATCHDOG
`ifdef RGB24
`ifdef W128
localparam types::readpixel_cmd_t cmd_pixel_1 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h00), types::col_addr_view_t'('h0078), types::color_t'('h132040)
});
localparam types::readpixel_cmd_t cmd_pixel_2 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h01), types::col_addr_view_t'('h0079), types::color_t'('h304013)
});
localparam types::fillrect_cmd_t cmd_fillrect = types::fillrect_cmd_t'({
    cmd::FILLRECT,
    types::col_addr_field_t'('h0001),
    types::row_addr_field_t'('h0A),
    types::col_addr_field_t'('h0071),
    types::row_addr_field_t'('h05),
    types::color_t'('hE0A932)
});
`else  // W128
localparam types::readpixel_cmd_t cmd_pixel_1 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h00), types::col_addr_view_t'('h30), types::color_t'('h132040)
});
localparam types::readpixel_cmd_t cmd_pixel_2 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h01), types::col_addr_view_t'('h32), types::color_t'('h304013)
});
localparam types::fillrect_cmd_t cmd_fillrect = types::fillrect_cmd_t'({
    cmd::FILLRECT,
    types::col_addr_field_t'('h05),
    types::row_addr_field_t'('h0A),
    types::col_addr_field_t'('h10),
    types::row_addr_field_t'('h05),
    types::color_t'('hE0A932)
});
`endif  // W128
localparam types::fillpanel_cmd_t cmd_fillpanel = types::fillpanel_cmd_t'({cmd::FILLPANEL, types::color_t'('h314287)});
`else  // RGB24
`ifdef W128
localparam types::readpixel_cmd_t cmd_pixel_1 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h00), types::col_addr_view_t'('h0078), types::color_t'('h1020)
});
localparam types::readpixel_cmd_t cmd_pixel_2 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h01), types::col_addr_view_t'('h0079), types::color_t'('h3040)
});
localparam types::fillrect_cmd_t cmd_fillrect = types::fillrect_cmd_t'({
    cmd::FILLRECT,
    types::col_addr_field_t'('h0001),
    types::row_addr_field_t'('h0A),
    types::col_addr_field_t'('h0071),
    types::row_addr_field_t'('h05),
    types::color_t'('hE0A9)
});
`else  // W128
localparam types::readpixel_cmd_t cmd_pixel_1 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h00), types::col_addr_view_t'('h30), types::color_t'('h1020)
});
localparam types::readpixel_cmd_t cmd_pixel_2 = types::readpixel_cmd_t'({
    cmd::READPIXEL, types::row_addr_view_t'('h01), types::col_addr_view_t'('h32), types::color_t'('h3040)
});
localparam types::fillrect_cmd_t cmd_fillrect = types::fillrect_cmd_t'({
    cmd::FILLRECT,
    types::col_addr_field_t'('h05),
    types::row_addr_field_t'('h0A),
    types::col_addr_field_t'('h10),
    types::row_addr_field_t'('h05),
    types::color_t'('hE0A9)
});
`endif  // W128
localparam types::fillpanel_cmd_t cmd_fillpanel = types::fillpanel_cmd_t'({cmd::FILLPANEL, types::color_t'('h3142)});
`endif  // RGB24

// Readrect command payload: keep a small rectangle so pipelining can be exercised
// without making simulation excessively long.
localparam int unsigned READRECT_X1 = 2;
localparam int unsigned READRECT_Y1 = 1;
localparam int unsigned READRECT_W = 3;
localparam int unsigned READRECT_H = 2;
localparam int unsigned READRECT_PIXEL_COUNT = READRECT_W * READRECT_H;
localparam int unsigned READRECT_TOTAL_BYTES = READRECT_PIXEL_COUNT * params::BYTES_PER_PIXEL;
// Use a constant byte so payload order is unambiguous across RGB modes.
localparam logic [7:0] READRECT_PAYLOAD_BYTE = 8'hA5;
localparam logic [(READRECT_TOTAL_BYTES*8)-1:0] cmd_readrect_payload =
    {READRECT_TOTAL_BYTES{READRECT_PAYLOAD_BYTE}};
// Header fields are big endian on the wire; cast into the packed field types.
localparam types::readrect_cmd_t cmd_readrect_header = types::readrect_cmd_t'({
    cmd::READRECT,
    types::col_addr_field_t'(READRECT_X1),
    types::row_addr_field_t'(READRECT_Y1),
    types::col_addr_field_t'(READRECT_W),
    types::row_addr_field_t'(READRECT_H)
});
localparam logic [$bits(cmd_readrect_header)+(READRECT_TOTAL_BYTES*8)-1:0] cmd_readrect =
    {cmd_readrect_header, cmd_readrect_payload};

`define CMD_SERIES_FIELDS \
    cmd_blankpanel, \
`ifdef USE_WATCHDOG \
    cmd_watchdog, \
`endif \
    cmd_fillpanel, \
    cmd_fillrect, \
    cmd_pixel_1, \
    cmd_pixel_2, \
    cmd_brightness_1, \
    cmd_brightness_2, \
    cmd_brightness_3, \
    cmd_readrow, \
    cmd_readrect, \
    cmd_readframe, \
    cmd_pixel_1
`ifdef F2B_SERIES
// ---------------------------------------------------------------------------
// F2.b reproduction stream (host-faithful): a drawColumn ("K") burst across the
// magenta bar's high columns, immediately followed by swapFrame ("t") -- the
// exact host sequence whose right-edge drops on SDRAM. Each "K" blasts 96 payload
// bytes down 32 DIFFERENT SDRAM rows (a row-miss every write); the free-running
// master (TB_SPI_FREERUN) cannot be stalled per byte, so when the write FIFO
// drains slowly (SDRAM_SIM_SLOW_WRITES) the tail is still in flight when busy
// drops and the swap lands -> the high columns show the stale background.
// ---------------------------------------------------------------------------
localparam int unsigned F2B_NUM_COLS  = 48;
localparam int unsigned F2B_FIRST_COL = params::PIXEL_WIDTH - F2B_NUM_COLS;  // 720 @ W=768
localparam int unsigned F2B_K_BITS    = $bits(types::readcol_cmd_t);
localparam int unsigned F2B_T_BITS    = $bits(cmd::opcode_t);
localparam int unsigned F2B_TOTAL_BITS = F2B_NUM_COLS * F2B_K_BITS + F2B_T_BITS;

function automatic logic [F2B_TOTAL_BITS-1:0] f2b_build_series();
    logic [F2B_TOTAL_BITS-1:0]  s;
    types::column_data_field_t  mag;
    types::readcol_cmd_t        k;
    int unsigned                bitpos;
    mag = '1;                       // all-ones payload (color is irrelevant to the drain mechanism)
    s = '0;
    bitpos = F2B_TOTAL_BITS;        // fill MSB-first == on-the-wire send order
    for (int unsigned c = 0; c < F2B_NUM_COLS; c++) begin
        k = types::readcol_cmd_t'({cmd::READCOL,
                                   types::col_addr_field_t'(F2B_FIRST_COL + c),
                                   mag});
        bitpos -= F2B_K_BITS;
        s[bitpos +: F2B_K_BITS] = k;
    end
    bitpos -= F2B_T_BITS;
    s[bitpos +: F2B_T_BITS] = F2B_T_BITS'(cmd::TOGGLE_FRAME);
    f2b_build_series = s;
endfunction

localparam logic [F2B_TOTAL_BITS-1:0] cmd_series = f2b_build_series();
`elsif LIVE_F4_SERIES
// ---------------------------------------------------------------------------
// F4 reproduction (live/demo-mode cadence): fill a known BACKGROUND, then loop
// {fillrect a chunk -> TOGGLE_FRAME -> COPY_FRAME} for several frames -- the exact
// per-frame carry-forward + swap the live scene does (and the test pattern never
// does). The displayed background must survive; if it degrades into garbage, F4
// is reproduced in the displayed pixels (checked by reading the row_buf bank).
// ---------------------------------------------------------------------------
localparam int unsigned LF4_FRAMES  = 6;
localparam int unsigned LF4_FP_BITS = $bits(types::fillpanel_cmd_t);
localparam int unsigned LF4_FR_BITS = $bits(types::fillrect_cmd_t);
localparam int unsigned LF4_OP_BITS = $bits(cmd::opcode_t);
localparam int unsigned LF4_TOTAL_BITS = LF4_FP_BITS + 2*LF4_OP_BITS
                                       + LF4_FRAMES*(LF4_FR_BITS + 2*LF4_OP_BITS);

function automatic logic [LF4_TOTAL_BITS-1:0] lf4_build_series();
    logic [LF4_TOTAL_BITS-1:0] s;
    int unsigned bitpos;
    s = '0;
    bitpos = LF4_TOTAL_BITS;             // fill MSB-first == on-the-wire send order
    // initial: fill the back buffer with a known background, swap it to front, copy it back
    bitpos -= LF4_FP_BITS;
    s[bitpos +: LF4_FP_BITS] = types::fillpanel_cmd_t'({cmd::FILLPANEL, types::color_t'('h214387)});
    bitpos -= LF4_OP_BITS; s[bitpos +: LF4_OP_BITS] = LF4_OP_BITS'(cmd::TOGGLE_FRAME);
    bitpos -= LF4_OP_BITS; s[bitpos +: LF4_OP_BITS] = LF4_OP_BITS'(cmd::COPY_FRAME);
    // live frames: draw a chunk into the back buffer, swap, carry forward
    for (int unsigned f = 0; f < LF4_FRAMES; f++) begin
        bitpos -= LF4_FR_BITS;
        s[bitpos +: LF4_FR_BITS] = types::fillrect_cmd_t'({cmd::FILLRECT,
            types::col_addr_field_t'('h0064),                // x = 100
            types::row_addr_field_t'('h00),                  // y = 0
            types::col_addr_field_t'('h0010),                // w = 16
            types::row_addr_field_t'(params::PIXEL_HEIGHT),  // full height
            types::color_t'('hFF00FF)});                     // magenta chunk
        bitpos -= LF4_OP_BITS; s[bitpos +: LF4_OP_BITS] = LF4_OP_BITS'(cmd::TOGGLE_FRAME);
        bitpos -= LF4_OP_BITS; s[bitpos +: LF4_OP_BITS] = LF4_OP_BITS'(cmd::COPY_FRAME);
    end
    lf4_build_series = s;
endfunction

localparam logic [LF4_TOTAL_BITS-1:0] cmd_series = lf4_build_series();
`else
localparam logic [$bits({`CMD_SERIES_FIELDS})-1:0] cmd_series = {`CMD_SERIES_FIELDS};
`endif
