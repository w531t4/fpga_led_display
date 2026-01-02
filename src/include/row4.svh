// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`include "sim_data.svh"
`ifdef RGB24
`ifdef W128
localparam readrow_cmd_t cmd_readrow = readrow_cmd_t'({
    cmd::READROW, row_addr_view_t'('h04), row_data_t'('h`W384_RGB24_ROW_HEX)
});
`else  // W128
localparam readrow_cmd_t cmd_readrow = readrow_cmd_t'({
    cmd::READROW, row_addr_view_t'('h04), row_data_t'('h`W64_RGB24_ROW_HEX)
});

`endif  // W128
`else  // RGB24
`ifdef W128
localparam readrow_cmd_t cmd_readrow = readrow_cmd_t'({
    cmd::READROW, row_addr_view_t'('h04), row_data_t'('h`W384_RGB565_ROW_HEX)
});

`else  // W128
localparam readrow_cmd_t cmd_readrow = readrow_cmd_t'({
    cmd::READROW, row_addr_view_t'('h04), row_data_t'('h`W64_RGB565_ROW_HEX)
});
`endif  // W128
`endif  // RGB24
// Add tests for pixel set command
localparam brightness3_cmd_t cmd_brightness_1 = brightness3_cmd_t'({cmd::BRIGHTNESS_THREE});

localparam readbrightness_cmd_t cmd_brightness_2 = readbrightness_cmd_t'({
    cmd::READBRIGHTNESS, brightness_level_view_t'('h23)
});  // "T" + \x23
localparam readbrightness_cmd_t cmd_brightness_3 = readbrightness_cmd_t'({
    cmd::READBRIGHTNESS, brightness_level_view_t'('h38)
});  // "T" + \x38

localparam blankpanel_cmd_t cmd_blankpanel = blankpanel_cmd_t'({cmd::BLANKPANEL});

`ifdef USE_WATCHDOG
localparam watchdog_cmd_t cmd_watchdog = watchdog_cmd_t'({
    cmd::WATCHDOG, watchdog_pattern_t'(params::WATCHDOG_SIGNATURE_PATTERN)
});  // "W" + "DEADBEEFFEEBDAED"
`endif  // USE_WATCHDOG
`ifdef RGB24
`ifdef W128
localparam readpixel_cmd_t cmd_pixel_1 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h0078), color_t'('h132040)
});
localparam readpixel_cmd_t cmd_pixel_2 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h0079), color_t'('h304013)
});
localparam fillrect_cmd_t cmd_fillrect = fillrect_cmd_t'({
    cmd::FILLRECT,
    col_field_t'('h0001),
    row_field_t'('h0A),
    col_field_t'('h0071),
    row_field_t'('h05),
    color_t'('hE0A932)
});
`else  // W128
localparam readpixel_cmd_t cmd_pixel_1 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h30), color_t'('h132040)
});
localparam readpixel_cmd_t cmd_pixel_2 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h32), color_t'('h304013)
});
localparam fillrect_cmd_t cmd_fillrect = fillrect_cmd_t'({
    cmd::FILLRECT,
    col_field_t'('h05),
    row_field_t'('h0A),
    col_field_t'('h10),
    row_field_t'('h05),
    color_t'('hE0A932)
});
`endif  // W128
localparam fillpanel_cmd_t cmd_fillpanel = fillpanel_cmd_t'({cmd::FILLPANEL, color_t'('h314287)});
`else  // RGB24
`ifdef W128
localparam readpixel_cmd_t cmd_pixel_1 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h0078), color_t'('h1020)
});
localparam readpixel_cmd_t cmd_pixel_2 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h0079), color_t'('h3040)
});
localparam fillrect_cmd_t cmd_fillrect = fillrect_cmd_t'({
    cmd::FILLRECT,
    col_field_t'('h0001),
    row_field_t'('h0A),
    col_field_t'('h0071),
    row_field_t'('h05),
    color_t'('hE0A9)
});
`else  // W128
localparam readpixel_cmd_t cmd_pixel_1 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h30), color_t'('h1020)
});
localparam readpixel_cmd_t cmd_pixel_2 = readpixel_cmd_t'({
    cmd::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h32), color_t'('h3040)
});
localparam fillrect_cmd_t cmd_fillrect = fillrect_cmd_t'({
    cmd::FILLRECT,
    col_field_t'('h05),
    row_field_t'('h0A),
    col_field_t'('h10),
    row_field_t'('h05),
    color_t'('hE0A9)
});
`endif  // W128
localparam fillpanel_cmd_t cmd_fillpanel = fillpanel_cmd_t'({cmd::FILLPANEL, color_t'('h3142)});
`endif  // RGB24

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
    cmd_readrow
localparam logic [$bits({`CMD_SERIES_FIELDS})-1:0] cmd_series = {`CMD_SERIES_FIELDS};
