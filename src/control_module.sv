// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_module #(
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    input [7:0] data_rx,
    input data_ready_n,
    output logic [2:0] rgb_enable,
    output logic [params_pkg::BRIGHTNESS_LEVELS-1:0] brightness_enable,
    output logic [_NUM_DATA_A_BITS-1:0] ram_data_out,
    output logic [_NUM_ADDRESS_A_BITS-1:0] ram_address,     // with 64x32 matrix at 2bytes per pixel, this is 12 bits [11:0]
    output logic ram_write_enable,
    output busy,
    output ready_for_data,
    `ifdef DOUBLE_BUFFER
        output logic frame_select,
    `endif
    `ifdef USE_WATCHDOG
        output logic watchdog_reset,
    `endif
    `ifdef DEBUGGER
        output [3:0] cmd_line_state2,
        output ram_access_start2,
        output ram_access_start_latch2,
        output [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr2,
        output logic [7:0] num_commands_processed,
    `endif
    output logic ram_clk_enable

);
    // for now, if adding new states, ensure cmd_line_state2 is updated.
    typedef enum logic [3:0] {STATE_IDLE,               // 0
                              STATE_CMD_READROW,        // 1
                              STATE_CMD_READBRIGHTNESS, // 2
                              STATE_CMD_BLANKPANEL,     // 3
                              STATE_CMD_FILLPANEL,      // 4
                              STATE_CMD_FILLRECT,       // 5
                              STATE_CMD_READPIXEL,      // 6
                              STATE_CMD_READFRAME       // 7
                              `ifdef USE_WATCHDOG
                                ,
                                STATE_CMD_WATCHDOG       // 8
                              `endif
                              } ctrl_fsm;
    logic [7:0] data_rx_latch;
    logic ready_for_data_logic;
    logic [params_pkg::BRIGHTNESS_LEVELS-1:0] brightness_temp;
    logic ram_access_start;
    logic ram_access_start_latch;
    ctrl_fsm cmd_line_state;
    logic [_NUM_ROW_ADDRESS_BITS-1:0] cmd_line_addr_row;     // For 32 bit high displays, [4:0]
    logic [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_line_addr_col; // For 64 bit wide displays @ 2 bytes per pixel == 128, -> 127 -> [6:0]
    logic [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_line_pixelselect_num;
    wire [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr =
        {  cmd_line_addr_row[_NUM_ROW_ADDRESS_BITS-1:0],
           cmd_line_addr_col,
          ~cmd_line_pixelselect_num}; // <-- use this to toggle endainness. ~ == little endain
                                      //                                      == bit endian
                                      // NOTE: uart/alphabet.uart is BIG ENDIAN.
    logic state_done;
    logic brightness_change_enable;
    logic [params_pkg::BRIGHTNESS_LEVELS-1:0] brightness_data_out;

    `ifdef DEBUGGER
        assign cmd_line_state2 = cmd_line_state;
        assign cmd_line_addr2 = cmd_line_addr;
        assign ram_access_start2 = ram_access_start;
        assign ram_access_start_latch2 = ram_access_start_latch;
    `endif

    assign ram_clk_enable = ram_access_start ^ ram_access_start_latch;
    always @(posedge clk_in) begin
        if (reset) begin
            ram_access_start_latch <= 1'b0;
        end
        else begin
            if (ram_clk_enable) begin
                ram_access_start_latch <= ram_access_start;
            end
            else begin
            end
        end
    end

    // this prevents testbench from continuing to send data (even though we're not ready to accept)
    always_ff @(posedge clk_in) begin
        if (reset) begin
            data_rx_latch <= 8'd0;
        end else if (ready_for_data) begin
            data_rx_latch <= data_rx;
        end
    end

    wire cmd_readrow_we, cmd_readrow_as, cmd_readrow_done;
    wire [7:0] cmd_readrow_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0] cmd_readrow_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_readrow_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readrow_pixel_addr;

    control_cmd_readrow cmd_readrow (
        // .cmd_enable(cmd_line_state == STATE_CMD_READROW),
        .reset(reset),
        .data_in(data_rx_latch),
        // .enable(cmd_line_state == STATE_CMD_READROW),
        .enable((cmd_line_state == STATE_CMD_READROW) && ~data_ready_n),
        .clk(clk_in),

        .row(cmd_readrow_row_addr),
        .column(cmd_readrow_col_addr),
        .pixel(cmd_readrow_pixel_addr),
        .data_out(cmd_readrow_do),
        .ram_write_enable(cmd_readrow_we),
        .ram_access_start(cmd_readrow_as),
        .done(cmd_readrow_done)
    );
    assign ram_address = cmd_line_addr;

    wire cmd_readpixel_we, cmd_readpixel_as, cmd_readpixel_done;
    wire [7:0] cmd_readpixel_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0] cmd_readpixel_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_readpixel_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readpixel_pixel_addr;

    control_cmd_readpixel cmd_readpixel (
        // .cmd_enable(cmd_line_state == STATE_CMD_READROW),
        .reset(reset),
        .data_in(data_rx_latch),
        .clk(clk_in),
        // .enable(cmd_line_state == STATE_CMD_READPIXEL),
        .enable((cmd_line_state == STATE_CMD_READPIXEL) && ~data_ready_n),
        .row(cmd_readpixel_row_addr),
        .column(cmd_readpixel_col_addr),
        .pixel(cmd_readpixel_pixel_addr),
        .data_out(cmd_readpixel_do),
        .ram_write_enable(cmd_readpixel_we),
        .ram_access_start(cmd_readpixel_as),
        // .address_change_en(cmd_readpixel_ace),
        .done(cmd_readpixel_done)
    );

    wire cmd_readbrightness_done, cmd_readbrightness_be;
    wire [params_pkg::BRIGHTNESS_LEVELS-1:0] cmd_readbrightness_do;
    control_cmd_readbrightness cmd_readbrightness (
        .reset(reset),
        .data_in(data_rx_latch),
        .clk(clk_in),
        // .enable(cmd_line_state == STATE_CMD_READBRIGHTNESS),
        .enable((cmd_line_state == STATE_CMD_READBRIGHTNESS) && ~data_ready_n),
        .data_out(cmd_readbrightness_do),
        .brightness_change_en(cmd_readbrightness_be),
        .done(cmd_readbrightness_done)
    );

    wire cmd_blankpanel_we, cmd_blankpanel_as, cmd_blankpanel_done;
    wire [7:0] cmd_blankpanel_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0] cmd_blankpanel_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_blankpanel_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_blankpanel_pixel_addr;

    control_cmd_blankpanel cmd_blankpanel (
        .reset(reset),
        // This command requires no arguments, therefore it can operate at clock speed (no ~data_ready_n)
        .enable(cmd_line_state == STATE_CMD_BLANKPANEL),
        .clk(clk_in),
        .mem_clk(clk_in),

        .row(cmd_blankpanel_row_addr),
        .column(cmd_blankpanel_col_addr),
        .pixel(cmd_blankpanel_pixel_addr),
        .data_out(cmd_blankpanel_do),
        .ram_write_enable(cmd_blankpanel_we),
        .ram_access_start(cmd_blankpanel_as),
        .done(cmd_blankpanel_done)
    );

    wire                                  cmd_fillpanel_we;
    wire                                  cmd_fillpanel_as;
    wire                                  cmd_fillpanel_done;
    wire [7:0]                            cmd_fillpanel_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0]      cmd_fillpanel_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0]   cmd_fillpanel_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_fillpanel_pixel_addr;
    wire                                  cmd_fillpanel_rfd;

    control_cmd_fillpanel cmd_fillpanel (
        .reset(reset),
        // .enable(cmd_line_state == STATE_CMD_FILLPANEL),
        .enable((cmd_line_state == STATE_CMD_FILLPANEL) && ~data_ready_n),
        .clk(clk_in),
        .mem_clk(clk_in),
        .data_in(data_rx_latch),
        .row(             cmd_fillpanel_row_addr),
        .column(          cmd_fillpanel_col_addr),
        .pixel(           cmd_fillpanel_pixel_addr),
        .data_out(        cmd_fillpanel_do),
        .ram_write_enable(cmd_fillpanel_we),
        .ram_access_start(cmd_fillpanel_as),
        .ready_for_data(  cmd_fillpanel_rfd),
        .done(            cmd_fillpanel_done)
    );

    wire                                  cmd_fillrect_we;
    wire                                  cmd_fillrect_as;
    wire                                  cmd_fillrect_done;
    wire [7:0]                            cmd_fillrect_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0]      cmd_fillrect_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0]   cmd_fillrect_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_fillrect_pixel_addr;
    wire                                  cmd_fillrect_rfd;

    control_cmd_fillrect cmd_fillrect (
        .reset(reset),
        // .enable(cmd_line_state == STATE_CMD_FILLRECT),
        .enable((cmd_line_state == STATE_CMD_FILLRECT) && ~data_ready_n),
        .clk(clk_in),
        .mem_clk(clk_in),
        .data_in(data_rx),
        .row(             cmd_fillrect_row_addr),
        .column(          cmd_fillrect_col_addr),
        .pixel(           cmd_fillrect_pixel_addr),
        .data_out(        cmd_fillrect_do),
        .ram_write_enable(cmd_fillrect_we),
        .ram_access_start(cmd_fillrect_as),
        .ready_for_data(  cmd_fillrect_rfd),
        .done(            cmd_fillrect_done)
    );

    wire                                  cmd_readframe_we;
    wire                                  cmd_readframe_as;
    wire                                  cmd_readframe_done;
    wire [7:0]                            cmd_readframe_do;
    wire [_NUM_ROW_ADDRESS_BITS-1:0]      cmd_readframe_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0]   cmd_readframe_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readframe_pixel_addr;

    control_cmd_readframe cmd_readframe (
        .reset(reset),
        // .enable(cmd_line_state == STATE_CMD_FILLRECT),
        .enable((cmd_line_state == STATE_CMD_READFRAME) && ~data_ready_n),
        .clk(clk_in),
        .data_in(data_rx_latch),
        .row(             cmd_readframe_row_addr),
        .column(          cmd_readframe_col_addr),
        .pixel(           cmd_readframe_pixel_addr),
        .data_out(        cmd_readframe_do),
        .ram_write_enable(cmd_readframe_we),
        .ram_access_start(cmd_readframe_as),
        .done(            cmd_readframe_done)
    );

    `ifdef USE_WATCHDOG
        wire                                  cmd_watchdog_done;
        wire                                  cmd_watchdog_sysreset;

        control_cmd_watchdog cmd_watchdog (
            .reset(reset),
            .enable((cmd_line_state == STATE_CMD_WATCHDOG) && ~data_ready_n),
            .clk(clk_in),
            .data_in(data_rx_latch),
            .sys_reset(       cmd_watchdog_sysreset),
            .done(            cmd_watchdog_done)
        );
        assign watchdog_reset = cmd_watchdog_sysreset;
    `endif

    always @(*) begin
        cmd_line_addr_row = {_NUM_ROW_ADDRESS_BITS{1'b0}};
        cmd_line_addr_col = {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
        cmd_line_pixelselect_num = {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
        ram_data_out = 8'b0;
        ram_write_enable = 1'b0;
        ram_access_start = 1'b0;
        state_done = 1'b0;
        brightness_change_enable = 1'b0;
        brightness_data_out = {params_pkg::BRIGHTNESS_LEVELS{1'b0}};
        ready_for_data_logic = 1'b1;
        case (cmd_line_state)
            STATE_CMD_READBRIGHTNESS: begin
                brightness_change_enable = cmd_readbrightness_be;
                brightness_data_out = cmd_readbrightness_do;
                state_done = cmd_readbrightness_done;
            end
            STATE_CMD_READFRAME: begin
                cmd_line_addr_row =        cmd_readframe_row_addr;
                cmd_line_addr_col =        cmd_readframe_col_addr;
                cmd_line_pixelselect_num = cmd_readframe_pixel_addr;
                ram_data_out =             cmd_readframe_do;
                ram_write_enable =         cmd_readframe_we;
                ram_access_start =         cmd_readframe_as;
                state_done =               cmd_readframe_done;
            end
            STATE_CMD_READROW: begin
                cmd_line_addr_row = cmd_readrow_row_addr;
                cmd_line_addr_col = cmd_readrow_col_addr;
                cmd_line_pixelselect_num = cmd_readrow_pixel_addr;
                ram_data_out = cmd_readrow_do;
                ram_write_enable = cmd_readrow_we;
                ram_access_start = cmd_readrow_as;
                state_done = cmd_readrow_done;
            end
            STATE_CMD_BLANKPANEL: begin
                cmd_line_addr_row = cmd_blankpanel_row_addr;
                cmd_line_addr_col = cmd_blankpanel_col_addr;
                cmd_line_pixelselect_num = cmd_blankpanel_pixel_addr;
                ram_data_out = cmd_blankpanel_do;
                ram_write_enable = cmd_blankpanel_we;
                ram_access_start = cmd_blankpanel_as;
                state_done = cmd_blankpanel_done;
                ready_for_data_logic = 1'b0;
            end
            STATE_CMD_FILLPANEL: begin
                cmd_line_addr_row =        cmd_fillpanel_row_addr;
                cmd_line_addr_col =        cmd_fillpanel_col_addr;
                cmd_line_pixelselect_num = cmd_fillpanel_pixel_addr;
                ram_data_out =             cmd_fillpanel_do;
                ram_write_enable =         cmd_fillpanel_we;
                ram_access_start =         cmd_fillpanel_as;
                state_done =               cmd_fillpanel_done;
                ready_for_data_logic =     cmd_fillpanel_rfd;
            end
            STATE_CMD_FILLRECT: begin
                cmd_line_addr_row =        cmd_fillrect_row_addr;
                cmd_line_addr_col =        cmd_fillrect_col_addr;
                cmd_line_pixelselect_num = cmd_fillrect_pixel_addr;
                ram_data_out =             cmd_fillrect_do;
                ram_write_enable =         cmd_fillrect_we;
                ram_access_start =         cmd_fillrect_as;
                state_done =               cmd_fillrect_done;
                ready_for_data_logic =     cmd_fillrect_rfd;
            end
            STATE_CMD_READPIXEL: begin
                cmd_line_addr_row = cmd_readpixel_row_addr;
                cmd_line_addr_col = cmd_readpixel_col_addr;
                cmd_line_pixelselect_num = cmd_readpixel_pixel_addr;
                ram_data_out = cmd_readpixel_do;
                ram_write_enable = cmd_readpixel_we;
                ram_access_start = cmd_readpixel_as;
                state_done = cmd_readpixel_done;
            end
            `ifdef USE_WATCHDOG
                STATE_CMD_WATCHDOG: begin
                    state_done =               cmd_watchdog_done;
                end
            `endif
            default: begin
            end
        endcase
    end
    assign busy = ~(cmd_line_state == STATE_IDLE || state_done);
    assign ready_for_data = ready_for_data_logic || ~busy;
    `ifdef DOUBLE_BUFFER
        logic frame_select_temp;
    `endif
    always @(posedge clk_in) begin
        if (reset) begin
            rgb_enable <= 3'b111;
            `ifdef DOUBLE_BUFFER
                frame_select <= 1'b0;
                frame_select_temp <= 1'b0;
            `endif
            brightness_enable <= {params_pkg::BRIGHTNESS_LEVELS{1'b1}};
            brightness_temp <= {params_pkg::BRIGHTNESS_LEVELS{1'b1}};

            cmd_line_state <= STATE_IDLE;
            `ifdef DEBUGGER
                num_commands_processed <= 8'b0;
            `endif
        end
        else begin
            if (state_done) begin
                if (data_ready_n && cmd_line_state != STATE_IDLE ) cmd_line_state <= STATE_IDLE;
                `ifdef DEBUGGER
                    num_commands_processed <= num_commands_processed + 'd1;
                `endif
            end
            if (brightness_enable != brightness_temp) begin
                brightness_enable <= brightness_temp;
            end else if (brightness_change_enable) begin
                brightness_enable <= brightness_data_out;
                brightness_temp <= brightness_data_out;
            end
            `ifdef DOUBLE_BUFFER
                if (frame_select_temp != frame_select)
                    frame_select <= frame_select_temp;
            `endif
            /* CMD: Main */
            if ((cmd_line_state == STATE_IDLE || state_done) && ~data_ready_n) begin
                case (data_rx_latch)
                    "R": begin
                        rgb_enable[0] <= 1'b1;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "r": begin
                        rgb_enable[0] <= 1'b0;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "G": begin
                        rgb_enable[1] <= 1'b1;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "g": begin
                        rgb_enable[1] <= 1'b0;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "B": begin
                        rgb_enable[2] <= 1'b1;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "b": begin
                        rgb_enable[2] <= 1'b0;
                        cmd_line_state <= STATE_IDLE;
                    end
                    "1": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 1] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 1];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "2": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 2] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 2];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "3": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 3] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 3];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "4": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 4] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 4];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "5": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 5] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 5];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "6": begin
                        brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 6] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 6];
                        cmd_line_state <= STATE_IDLE;
                    end
                    `ifdef RGB24
                        "7": begin
                            brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 7] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 7];
                            cmd_line_state <= STATE_IDLE;
                        end
                        "8": begin
                            brightness_temp[params_pkg::BRIGHTNESS_LEVELS - 8] <= ~brightness_enable[params_pkg::BRIGHTNESS_LEVELS - 8];
                            cmd_line_state <= STATE_IDLE;
                        end
                    `endif
                    "0": begin
                        brightness_temp <= {params_pkg::BRIGHTNESS_LEVELS{1'b0}};
                        cmd_line_state <= STATE_IDLE;
                    end
                    "9": begin
                        brightness_temp <= {params_pkg::BRIGHTNESS_LEVELS{1'b1}};
                        cmd_line_state <= STATE_IDLE;
                    end
                    "T": cmd_line_state <= STATE_CMD_READBRIGHTNESS;
                    "Z": cmd_line_state <= STATE_CMD_BLANKPANEL;
                    "F": cmd_line_state <= STATE_CMD_FILLPANEL;
                    "f": cmd_line_state <= STATE_CMD_FILLRECT;
                    "Y": cmd_line_state <= STATE_CMD_READFRAME;
                    "L": begin
                        cmd_line_state <= STATE_CMD_READROW;
                    end
                    "P": cmd_line_state <= STATE_CMD_READPIXEL;
                    `ifdef USE_WATCHDOG
                        "W": cmd_line_state <= STATE_CMD_WATCHDOG;
                    `endif
                    `ifdef DOUBLE_BUFFER
                        "t": frame_select_temp <= ~frame_select;
                    `endif
                    default: begin
                        cmd_line_state <= STATE_IDLE;
                        if (brightness_change_enable) brightness_temp <= brightness_data_out;
                    end
                endcase
            end
        end
    end
    wire _unused_ok = &{1'b0,
                        1'b0};
endmodule
