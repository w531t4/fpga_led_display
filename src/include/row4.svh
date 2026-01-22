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
localparam logic [$bits({`CMD_SERIES_FIELDS})-1:0] cmd_series = {`CMD_SERIES_FIELDS};
