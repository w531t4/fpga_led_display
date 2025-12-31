// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

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

typedef union packed {
    logic [calc_pkg::num_bytes_to_contain($bits(color_t))*8-1:0]    raw;
    logic [calc_pkg::num_bytes_to_contain($bits(color_t))-1:0][7:0] bytes;
    color_t                                                         color;
} color_field_t;
// ==== /COLOR ====

// ==== ROW ADDRESS ====
typedef logic [calc_pkg::num_row_address_bits(PIXEL_HEIGHT)-1:0] row_addr_t;
typedef struct packed {
    logic [calc_pkg::num_padding_bits_needed_to_reach_byte_boundry($bits(row_addr_t))-1:0] pad;
    row_addr_t                                                                             address;
} row_addr_view_t;

typedef union packed {
    logic [calc_pkg::num_bytes_to_contain($bits(row_addr_t))*8-1:0]    raw;
    logic [calc_pkg::num_bytes_to_contain($bits(row_addr_t))-1:0][7:0] bytes;
    row_addr_view_t                                                    addr;
} row_field_t;
// ==== /ROW ADDRESS ====

// ==== COLUMN ADDRESS ====
typedef logic [calc_pkg::num_column_address_bits(PIXEL_WIDTH)-1:0] col_addr_t;
typedef struct packed {
    logic [calc_pkg::num_padding_bits_needed_to_reach_byte_boundry($bits(col_addr_t))-1:0] pad;      // unused MSBs
    col_addr_t                                                                             address;  // LSBs
} col_addr_view_t;

typedef union packed {
    logic [calc_pkg::num_bytes_to_contain($bits(col_addr_t))*8-1:0]    raw;
    logic [calc_pkg::num_bytes_to_contain($bits(col_addr_t))-1:0][7:0] bytes;  // bytes[0] = LSB
    col_addr_view_t                                                    addr;
} col_field_t;
// ==== /COLUMN ADDRESS ====

// ==== PIXEL ADDRESS ====
typedef logic [calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel_addr_t;
// ==== /PIXEL ADDRESS ====

// ==== FRAMEBUFFER ADDRESS ====
typedef struct packed {
    row_addr_t   row;
    col_addr_t   col;
    pixel_addr_t pixel;
} fb_addr_t;
// ==== /FRAMEBUFFER ADDRESS ====

// ==== BRIGHTNESS ====
typedef logic [BRIGHTNESS_LEVELS-1:0] brightness_level_t;

typedef struct packed {
`ifndef RGB24
    logic [8-BRIGHTNESS_LEVELS-1:0] pad;
`endif
    brightness_level_t level;
} brightness_level_view_t;

typedef union packed {
    logic [7:0] raw;
    brightness_level_view_t brightness;
} brightness_field_t;
// ==== /BRIGHTNESS ====

// ==== ROW ====
typedef logic [(PIXEL_WIDTH*BYTES_PER_PIXEL*8)-1:0] row_data_t;
typedef union packed {
    row_data_t                                     raw;
    logic [(PIXEL_WIDTH*BYTES_PER_PIXEL)-1:0][7:0] bytes;
    row_data_t                                     data;
} row_data_field_t;
// ==== /ROW ====


//
// COMMANDS
//
typedef struct packed {
    // TODO: consistent ordering of row/column across commands
    commands_pkg::cmd_opcode_t opcode;
    row_field_t                y1;
    col_field_t                x1;
    color_field_t              color;
} readpixel_cmd_t;

typedef struct packed {
    commands_pkg::cmd_opcode_t opcode;
    color_t color;
} fillpanel_cmd_t;

typedef struct packed {commands_pkg::cmd_opcode_t opcode;} blankpanel_cmd_t;

typedef struct packed {
    commands_pkg::cmd_opcode_t opcode;
    col_field_t                x1;
    row_field_t                y1;
    col_field_t                width;
    row_field_t                height;
    color_field_t              color;
} fillrect_cmd_t;

typedef struct packed {
    commands_pkg::cmd_opcode_t opcode;
    brightness_field_t         level;
} readbrightness_cmd_t;

typedef struct packed {
    commands_pkg::cmd_opcode_t opcode;
    row_field_t                y1;
    row_data_field_t           data;
} readrow_cmd_t;

/*

readframe
watchdog
fillarea
*/

//localparam row_pixel_cmd_t myled_row_pixel2 = '{opcode: 8'h50, row: 8'h01, col: 8'h32, pixel: 8'h30, value: 8'h40};

