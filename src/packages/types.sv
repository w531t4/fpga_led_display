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
        logic red;
        logic green;
        logic blue;
    } rgb_signals_t;

    typedef struct packed {
        red_t   red;
        green_t green;
        blue_t  blue;
    } color_t;
    typedef logic [$clog2(calc::num_bytes_to_contain($bits(color_t)))-1:0] color_index_t;

    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(color_t))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(color_t))-1:0][7:0] bytes;
        color_t                                                     color;
    } color_field_t;

    typedef struct packed {
`ifdef RGB24
        // verilog_format: off
        logic [calc::num_pixeldata_bits(params::BYTES_PER_PIXEL)-$bits(color_field_t)-1:0] pad;  // 4th byte slot for RGB24
        // verilog_format: on
`endif
        color_field_t field;
    } color_field_subpanel_t;
    // ==== /COLOR ====

    // ==== SUBPANEL ====
    typedef logic [calc::num_subpanelselect_bits(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT)-1:0] subpanel_addr_t;
    // ==== /SUBPANEL ====

    // ==== ROW SUBPANEL ADDRESS ====
    typedef logic [calc::num_row_address_bits(params::PIXEL_HALFHEIGHT)-1:0] row_subpanel_addr_t;

    // ==== /ROW SUBPANEL ADDRESS ====

    // ==== ROW ADDRESS ====
    typedef logic [calc::num_row_address_bits(params::PIXEL_HEIGHT)-1:0] row_addr_t;

    // handle values from [0, PIXEL_HEIGHT]
    typedef logic [calc::num_row_address_bits(params::PIXEL_HEIGHT+1)-1:0] row_addr_count_t;

    typedef logic [calc::num_bytes_to_contain($bits(row_addr_t))*8-1:0] row_addr_view_t;

    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(row_addr_t))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(row_addr_t))-1:0][7:0] bytes;
    } row_addr_field_t;

    function automatic row_addr_t row_addr_from_field(input row_addr_field_t field);
        row_addr_from_field = field.raw[$bits(row_addr_t)-1:0];
    endfunction
    // ==== /ROW ADDRESS ====

    // ==== COLUMN ADDRESS ====
    typedef logic [calc::num_column_address_bits(params::PIXEL_WIDTH)-1:0] col_addr_t;

    // handle values from [0, PIXEL_WIDTH]
    typedef logic [calc::num_column_address_bits(params::PIXEL_WIDTH+1)-1:0] col_addr_count_t;

    typedef logic [calc::num_bytes_to_contain($bits(col_addr_t))*8-1:0] col_addr_view_t;

    typedef union packed {
        logic [calc::num_bytes_to_contain($bits(col_addr_t))*8-1:0]    raw;
        logic [calc::num_bytes_to_contain($bits(col_addr_t))-1:0][7:0] bytes;  // bytes[0] = LSB
    } col_addr_field_t;

    function automatic col_addr_t col_addr_from_field(input col_addr_field_t field);
        col_addr_from_field = field.raw[$bits(col_addr_t)-1:0];
    endfunction
    typedef logic [$clog2(calc::num_bytes_to_contain($bits(col_addr_t))+1)-1:0] col_addr_field_byte_count_t;
    typedef logic [calc::safe_clog2(calc::num_bytes_to_contain($bits(col_addr_t)))-1:0] col_addr_field_byte_index_t;
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

    // ==== MEM READ/WRITE ====
    // Address A (port A write address):
    //  -  upper bits select the “lane” (subpanel select + pixel‑byte select)
    //  -  lower bits are the same row+column “body” address used by port B
    //  -  YYYYrrrrccccXXXX (where)
    //          YYYY = num_subpanelselect_bits(PIXEL_HEIGHT, PIXEL_HALFHEIGHT)
    //          rrrr = log2(PIXEL_HALFHEIGHT)
    //          cccc = log2(PIXEL_WIDTH)
    //          XXXX = num_pixelcolorselect_bits(BYTES_PER_PIXEL)
    typedef struct packed {
        subpanel_addr_t subpanel;
        row_subpanel_addr_t row;
        col_addr_t col;
        pixel_addr_t pixel;
    } mem_write_addr_t;

    // aka: data A
    typedef logic [calc::num_data_a_bits()-1:0] mem_write_data_t;

    // aka: address B
    typedef struct packed {
        row_subpanel_addr_t row;
        col_addr_t col;
    } mem_read_addr_t;

    typedef struct packed {
        subpanel_addr_t subpanel;
        pixel_addr_t    pixel;
    } mem_structure_t;

    function automatic mem_structure_t mem_structure(mem_write_addr_t a);
        // written with row/col below (of which are then truncated) to avoid linting issues
        mem_structure = mem_structure_t'({a.row, a.col, a.subpanel, a.pixel});
    endfunction

    typedef union packed {
        logic [calc::num_data_b_bits(params::PIXEL_HEIGHT,
                                     params::BYTES_PER_PIXEL,
                                     params::PIXEL_HALFHEIGHT)-1:0] raw;
        color_field_subpanel_t [calc::num_subpanels(params::PIXEL_HEIGHT,
                                                    params::PIXEL_HALFHEIGHT)-1:0] subpanel;
        mem_write_data_t [(1 << $bits(mem_structure_t))-1:0] lane;
    } mem_read_data_t;

    // ==== /MEM READ/WRITE ====

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

    typedef logic [$clog2(params::BRIGHTNESS_BASE_TIMEOUT) + params::BRIGHTNESS_LEVELS-1:0] brightness_timeout_t;
    typedef logic [$clog2(params::BRIGHTNESS_LEVELS)-1:0] brightness_index_t;
    typedef logic [$clog2(params::BRIGHTNESS_LEVELS + 1)-1:0] brightness_count_t;
    // ==== /BRIGHTNESS ====

    // ==== ROW ====
    typedef logic [(params::PIXEL_WIDTH*params::BYTES_PER_PIXEL*8)-1:0] row_data_t;
    typedef union packed {
        row_data_t                                                     raw;
        logic [(params::PIXEL_WIDTH*params::BYTES_PER_PIXEL)-1:0][7:0] bytes;
        row_data_t                                                     data;
    } row_data_field_t;
    // ==== /ROW ====

    // ==== FRAME ====
    // Full-frame payload for readframe: row-major stream of row_data_t blocks.
    // This typedef keeps frame sizing in one place instead of re-deriving $bits(row_data_t).
    typedef logic [(params::PIXEL_HEIGHT*params::PIXEL_WIDTH*params::BYTES_PER_PIXEL*8)-1:0] frame_data_t;
    typedef struct packed {
        cmd::opcode_t opcode;
        frame_data_t  data;
    } readframe_cmd_t;
    // ==== /FRAME ====

    // ==== WATCHDOG ====
    typedef logic [params::WATCHDOG_SIGBYTES*8-1:0] watchdog_pattern_t;
    typedef union packed {
        logic [$bits(watchdog_pattern_t)-1:0]                                  raw;
        logic [calc::num_bytes_to_contain($bits(watchdog_pattern_t))-1:0][7:0] bytes;
        watchdog_pattern_t                                                     data;
    } watchdog_field_t;
    typedef logic [$clog2(params::WATCHDOG_CONTROL_TICKS)-1:0] watchdog_tick_index_t;
    typedef logic [$clog2(params::WATCHDOG_SIGBYTES)-1:0] watchdog_sigbyte_index_t;
    // ==== /WATCHDOG ====

    // ==== READY HOLDOFF ====
    typedef logic [$clog2(params::READY_HOLDOFF_TICKS + 1)-1:0] ready_holdoff_count_t;
    // ==== /READY HOLDOFF ====

    //
    // COMMANDS
    //
    typedef struct packed {
        // TODO: consistent ordering of row/column across commands
        cmd::opcode_t opcode;
        row_addr_field_t y1;
        col_addr_field_t x1;
        color_field_t color;
    } readpixel_cmd_t;

    typedef struct packed {
        cmd::opcode_t opcode;
        color_t color;
    } fillpanel_cmd_t;

    typedef struct packed {cmd::opcode_t opcode;} blankpanel_cmd_t;

    typedef struct packed {
        cmd::opcode_t opcode;
        col_addr_field_t x1;
        row_addr_field_t y1;
        col_addr_field_t width;
        row_addr_field_t height;
        color_field_t color;
    } fillrect_cmd_t;

    typedef struct packed {
        cmd::opcode_t      opcode;
        brightness_field_t level;
    } readbrightness_cmd_t;

    typedef struct packed {
        cmd::opcode_t    opcode;
        row_addr_field_t y1;
        row_data_field_t data;
    } readrow_cmd_t;

    typedef struct packed {
        cmd::opcode_t    opcode;
        watchdog_field_t data;
    } watchdog_cmd_t;

    // TODO: change opcode only commands to something like opcode_cmd_t
    typedef struct packed {cmd::opcode_t opcode;} brightness3_cmd_t;

endpackage
