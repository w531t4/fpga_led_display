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

    // ==== COLUMN ====
    typedef logic [(params::PIXEL_HEIGHT*params::BYTES_PER_PIXEL*8)-1:0] column_data_t;
    typedef union packed {
        column_data_t                                                   raw;
        logic [(params::PIXEL_HEIGHT*params::BYTES_PER_PIXEL)-1:0][7:0] bytes;
        column_data_t                                                   data;
    } column_data_field_t;
    // ==== /COLUMN ====

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

    // ==== FRAMEBUFFER FETCH ====
    typedef logic [$clog2(params::FB_FETCH_TIMEOUT_TICKS + 1)-1:0] fb_fetch_count_t;
    // ==== /FRAMEBUFFER FETCH ====


    // ==== EDGES ====
    typedef logic [1:0] edge_detect_t;

    function automatic logic falling_edge(edge_detect_t s);
        return s == 2'b10;  // prev=1, curr=0
    endfunction

    function automatic logic rising_edge(edge_detect_t s);
        return s == 2'b01;  // prev=0, curr=1
    endfunction
    // ==== /EDGES ====
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
`ifdef DOUBLE_BUFFER
    typedef struct packed {cmd::opcode_t opcode;} copyframe_cmd_t;
`endif

    typedef struct packed {
        cmd::opcode_t opcode;
        col_addr_field_t x1;
        row_addr_field_t y1;
        col_addr_field_t width;
        row_addr_field_t height;
        color_field_t color;
    } fillrect_cmd_t;

    typedef struct packed {
        cmd::opcode_t opcode;
        col_addr_field_t x1;
        row_addr_field_t y1;
        col_addr_field_t width;
        row_addr_field_t height;
    } readrect_cmd_t;

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
        cmd::opcode_t       opcode;
        col_addr_field_t    x1;
        column_data_field_t data;
    } readcol_cmd_t;

    typedef struct packed {
        cmd::opcode_t    opcode;
        watchdog_field_t data;
    } watchdog_cmd_t;

    // TODO: change opcode only commands to something like opcode_cmd_t
    typedef struct packed {cmd::opcode_t opcode;} brightness3_cmd_t;

    // ==== STATUS READBACK ====
    // READSTATUS register map (USE_STATUS_SPI): the command's argument byte
    // selects ONE register; the reply returns that register's value. Keep the
    // ESP32-side parser in sync with this section.
    typedef enum logic [7:0] {
        STATUS_ADDR_FLAGS      = 8'h00,  // {5'b0, fpga_ready, ctrl_busy, ctrl_ready_for_data}
        STATUS_ADDR_RGB        = 8'h01,  // {5'b0, red, green, blue}
        STATUS_ADDR_BRIGHTNESS = 8'h02,  // brightness_enable (zero-padded high)
        STATUS_ADDR_RX_KBPS    = 8'h03,  // command-SPI receive rate, KBps, 5 s sliding window
        STATUS_ADDR_HUB75_FPS  = 8'h04,  // HUB75 frame-emit rate, Hz, 5 s sliding average
        STATUS_ADDR_FB_FPS     = 8'h05,  // framebuffer swap rate, /s, 5 s avg (0 if !DOUBLE_BUFFER)
        STATUS_ADDR_NONE       = 8'hFF   // reserved: the never-latched mailbox sentinel
    } status_addr_e;
    // Field shapes; the byte sizes live in params:: (STATUS_*_BYTES).
    typedef logic [params::STATUS_ADDR_BYTES*8-1:0] status_addr_t;
    typedef logic [params::STATUS_SEQ_BYTES*8-1:0] status_seq_t;
    typedef logic [params::STATUS_VALUE_BYTES*8-1:0] status_value_t;
    typedef logic [params::STATUS_CRC_BYTES*8-1:0] status_crc_t;
    // Reply frame, shifted out MSB-first under CS framing:
    //   - byte 0: address echo (the READSTATUS argument byte) -- pairing
    //     proof; 0xFF = never-latched sentinel (reserved address)
    //   - byte 1: seq -- mailbox latch counter, +1 per accepted request
    //     (retries included), wraps mod 256 through zero. Host freshness
    //     rule: fresh iff seq DIFFERS from the last accepted frame's
    //   - byte 2..: selected register value (see status_addr_e)
    //   - last STATUS_CRC_BYTES: CRC over all preceding bytes (MSB-first,
    //     init 0, CRC-16/XMODEM -- see crc16.sv)
    // Body = the CRC-covered content; the reply frame = body + crc.
    typedef struct packed {
        status_addr_t  addr;
        status_seq_t   seq;
        status_value_t value;
    } status_body_t;
    typedef struct packed {
        status_addr_t  addr;
        status_seq_t   seq;
        status_value_t value;
        status_crc_t   crc;
    } status_reply_t;
    // ==== /STATUS READBACK ====

endpackage
