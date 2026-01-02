// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package types;
    typedef int unsigned uint_t;
    // SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
    // SPDX-License-Identifier: MIT

    // Note: localparam X __X_ZERO = '0; lines are because yosys must have a
    //       typed object (when using bits)

    // ==== COLOR ====
`ifdef RGB24
    typedef logic [7:0] red_t;
    typedef logic [7:0] green_t;
    typedef logic [7:0] blue_t;
`else
    typedef logic [4:0] red_t;
    typedef logic [5:0] green_t;
    typedef logic [4:0] blue_t;
`endif

    typedef struct packed {
        red_t   red;
        green_t green;
        blue_t  blue;
    } color_t;

    color_t __COLOR_T_ZERO = '0;
    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(__COLOR_T_ZERO))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(__COLOR_T_ZERO))-1:0][7:0] bytes;
        color_t                                                            color;
    } color_field_t;
    // ==== /COLOR ====

    // ==== ROW ADDRESS ====
    typedef logic [calc::num_row_address_bits(params::PIXEL_HEIGHT)-1:0] row_addr_t;
    row_addr_t __ROW_ADDR_T_ZERO = '0;
    typedef struct packed {
        logic [calc::num_padding_bits_needed_to_reach_byte_boundry($bits(__ROW_ADDR_T_ZERO))-1:0] pad;
        row_addr_t                                                                                address;
    } row_addr_view_t;

    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(__ROW_ADDR_T_ZERO))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(__ROW_ADDR_T_ZERO))-1:0][7:0] bytes;
        row_addr_view_t                                                       addr;
    } row_field_t;
    // ==== /ROW ADDRESS ====

    // ==== COLUMN ADDRESS ====
    typedef logic [calc::num_column_address_bits(params::PIXEL_WIDTH)-1:0] col_addr_t;
    col_addr_t __COL_ADDR_T_ZERO = '0;
    typedef struct packed {
        logic [calc::num_padding_bits_needed_to_reach_byte_boundry($bits(__COL_ADDR_T_ZERO))-1:0] pad;  // unused MSBs
        col_addr_t address;  // LSBs
    } col_addr_view_t;

    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(__COL_ADDR_T_ZERO))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(__COL_ADDR_T_ZERO))-1:0][7:0] bytes;  // bytes[0] = LSB
        col_addr_view_t                                                       addr;
    } col_field_t;
    // ==== /COLUMN ADDRESS ====

    // ==== PIXEL ADDRESS ====
    typedef logic [calc::num_pixelcolorselect_bits(params::BYTES_PER_PIXEL)-1:0] pixel_addr_t;
    // ==== /PIXEL ADDRESS ====

    // ==== FRAMEBUFFER ADDRESS ====
    typedef struct packed {
        row_addr_t   row;
        col_addr_t   col;
        pixel_addr_t pixel;
    } fb_addr_t;
    // ==== /FRAMEBUFFER ADDRESS ====

    // ==== BRIGHTNESS ====
    typedef logic [params::BRIGHTNESS_LEVELS-1:0] brightness_level_t;

    typedef struct packed {
`ifndef RGB24
        logic [8-params::BRIGHTNESS_LEVELS-1:0] pad;
`endif
        brightness_level_t level;
    } brightness_level_view_t;

    typedef union packed {
        logic [7:0] raw;
        brightness_level_view_t brightness;
    } brightness_field_t;
    // ==== /BRIGHTNESS ====

    // ==== ROW ====
    typedef logic [(params::PIXEL_WIDTH*params::BYTES_PER_PIXEL*8)-1:0] row_data_t;
    typedef union packed {
        row_data_t                                                     raw;
        logic [(params::PIXEL_WIDTH*params::BYTES_PER_PIXEL)-1:0][7:0] bytes;
        row_data_t                                                     data;
    } row_data_field_t;
    // ==== /ROW ====

    // ==== WATCHDOG ====
    typedef logic [params::WATCHDOG_SIGNATURE_BITS-1:0] watchdog_pattern_t;
    watchdog_pattern_t __WATCHDOG_DATA_T_ZERO = '0;
    typedef union packed {
        logic [$bits(__WATCHDOG_DATA_T_ZERO)-1:0]                                  raw;
        logic [calc::num_bytes_to_contain($bits(__WATCHDOG_DATA_T_ZERO))-1:0][7:0] bytes;
        watchdog_pattern_t                                                         data;
    } watchdog_field_t;
    // ==== /WATCHDOG ====

    //
    // COMMANDS
    //
    typedef struct packed {
        // TODO: consistent ordering of row/column across commands
        cmd::opcode_t opcode;
        row_field_t   y1;
        col_field_t   x1;
        color_field_t color;
    } readpixel_cmd_t;

    typedef struct packed {
        cmd::opcode_t opcode;
        color_t color;
    } fillpanel_cmd_t;

    typedef struct packed {cmd::opcode_t opcode;} blankpanel_cmd_t;

    typedef struct packed {
        cmd::opcode_t opcode;
        col_field_t   x1;
        row_field_t   y1;
        col_field_t   width;
        row_field_t   height;
        color_field_t color;
    } fillrect_cmd_t;

    typedef struct packed {
        cmd::opcode_t      opcode;
        brightness_field_t level;
    } readbrightness_cmd_t;

    typedef struct packed {
        cmd::opcode_t    opcode;
        row_field_t      y1;
        row_data_field_t data;
    } readrow_cmd_t;

    typedef struct packed {
        cmd::opcode_t    opcode;
        watchdog_field_t data;
    } watchdog_cmd_t;

    // TODO: change opcode only commands to something like opcode_cmd_t
    typedef struct packed {cmd::opcode_t opcode;} brightness3_cmd_t;

endpackage
