// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_module #(
    parameter int unsigned WATCHDOG_CONTROL_TICKS = params::WATCHDOG_CONTROL_TICKS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    input cmd::indata8_t data_rx,
    input data_ready_n,
    output types::rgb_signals_t rgb_enable,
    output types::brightness_level_t brightness_enable,
    output types::mem_write_data_t ram_data_out,
    output types::mem_write_addr_t ram_address,
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
    output types::mem_write_addr_t cmd_line_addr2,
    output logic [7:0] num_commands_processed,
`endif
    output logic ram_clk_enable

);
    localparam integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS;
    // for now, if adding new states, ensure cmd_line_state2 is updated.
    typedef enum logic [3:0] {
        STATE_IDLE,                // 0
        STATE_CMD_READROW,         // 1
        STATE_CMD_READBRIGHTNESS,  // 2
        STATE_CMD_BLANKPANEL,      // 3
        STATE_CMD_FILLPANEL,       // 4
        STATE_CMD_FILLRECT,        // 5
        STATE_CMD_READPIXEL,       // 6
        STATE_CMD_READFRAME        // 7
`ifdef USE_WATCHDOG,
        STATE_CMD_WATCHDOG         // 8
`endif
    } ctrl_fsm_t;
    cmd::indata8_t data_rx_latch;
    logic ready_for_data_logic;
    types::brightness_level_t brightness_temp;
    logic ram_access_start;
    logic ram_access_start_latch;
    ctrl_fsm_t cmd_line_state;
    types::fb_addr_t cmd_addr;

    wire types::mem_write_addr_t cmd_line_addr;
    assign cmd_line_addr = cmd_addr;

    logic state_done;
    logic brightness_change_enable;
    types::brightness_level_t brightness_data_out;

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
        end else begin
            if (ram_clk_enable) begin
                ram_access_start_latch <= ram_access_start;
            end else begin
            end
        end
    end

    // this prevents testbench from continuing to send data (even though we're not ready to accept)
    always_ff @(posedge clk_in) begin
        if (reset) begin
            data_rx_latch <= cmd::indata8_t'(0);
        end else if (ready_for_data) begin
            data_rx_latch <= data_rx;
        end
    end

    wire                        cmd_readrow_we;
    wire                        cmd_readrow_as;
    wire                        cmd_readrow_done;
    wire                  [7:0] cmd_readrow_do;
    wire types::fb_addr_t       cmd_readrow_addr;

    control_cmd_readrow #(
        ._UNUSED('d0)
    ) cmd_readrow (
        .reset(reset),
        .data_in(data_rx_latch),
        .enable((cmd_line_state == STATE_CMD_READROW) && ~data_ready_n),
        .clk(clk_in),
        .addr(cmd_readrow_addr),
        .data_out(cmd_readrow_do),
        .ram_write_enable(cmd_readrow_we),
        .ram_access_start(cmd_readrow_as),
        .done(cmd_readrow_done)
    );
    assign ram_address = cmd_line_addr;

    wire                        cmd_readpixel_we;
    wire                        cmd_readpixel_as;
    wire                        cmd_readpixel_done;
    wire                  [7:0] cmd_readpixel_do;
    wire types::fb_addr_t       cmd_readpixel_addr;

    control_cmd_readpixel #(
        ._UNUSED('d0)
    ) cmd_readpixel (
        .reset(reset),
        .data_in(data_rx_latch),
        .clk(clk_in),
        .enable((cmd_line_state == STATE_CMD_READPIXEL) && ~data_ready_n),
        .addr(cmd_readpixel_addr),
        .data_out(cmd_readpixel_do),
        .ram_write_enable(cmd_readpixel_we),
        .ram_access_start(cmd_readpixel_as),
        .done(cmd_readpixel_done)
    );

    wire                           cmd_readbrightness_done;
    wire                           cmd_readbrightness_be;
    wire types::brightness_level_t cmd_readbrightness_do;
    control_cmd_readbrightness #(
        ._UNUSED('d0)
    ) cmd_readbrightness (
        .reset(reset),
        .data_in(data_rx_latch),
        .clk(clk_in),
        .enable((cmd_line_state == STATE_CMD_READBRIGHTNESS) && ~data_ready_n),
        .data_out(cmd_readbrightness_do),
        .brightness_change_en(cmd_readbrightness_be),
        .done(cmd_readbrightness_done)
    );

    wire                        cmd_blankpanel_we;
    wire                        cmd_blankpanel_as;
    wire                        cmd_blankpanel_done;
    wire                  [7:0] cmd_blankpanel_do;
    wire types::fb_addr_t       cmd_blankpanel_addr;

    control_cmd_blankpanel #(
        ._UNUSED('d0)
    ) cmd_blankpanel (
        .reset(reset),
        // This command requires no arguments, therefore it can operate at clock speed (no ~data_ready_n)
        .enable(cmd_line_state == STATE_CMD_BLANKPANEL),
        .clk(clk_in),
        .mem_clk(clk_in),
        .addr(cmd_blankpanel_addr),
        .data_out(cmd_blankpanel_do),
        .ram_write_enable(cmd_blankpanel_we),
        .ram_access_start(cmd_blankpanel_as),
        .done(cmd_blankpanel_done)
    );

    wire                        cmd_fillpanel_we;
    wire                        cmd_fillpanel_as;
    wire                        cmd_fillpanel_done;
    wire                  [7:0] cmd_fillpanel_do;
    wire types::fb_addr_t       cmd_fillpanel_addr;
    wire                        cmd_fillpanel_rfd;

    control_cmd_fillpanel #(
        ._UNUSED('d0)
    ) cmd_fillpanel (
        .reset           (reset),
        .enable          ((cmd_line_state == STATE_CMD_FILLPANEL) && ~data_ready_n),
        .clk             (clk_in),
        .mem_clk         (clk_in),
        .data_in         (data_rx_latch),
        .addr            (cmd_fillpanel_addr),
        .data_out        (cmd_fillpanel_do),
        .ram_write_enable(cmd_fillpanel_we),
        .ram_access_start(cmd_fillpanel_as),
        .ready_for_data  (cmd_fillpanel_rfd),
        .done            (cmd_fillpanel_done)
    );

    wire                        cmd_fillrect_we;
    wire                        cmd_fillrect_as;
    wire                        cmd_fillrect_done;
    wire                  [7:0] cmd_fillrect_do;
    wire types::fb_addr_t       cmd_fillrect_addr;
    wire                        cmd_fillrect_rfd;

    control_cmd_fillrect #(
        ._UNUSED('d0)
    ) cmd_fillrect (
        .reset           (reset),
        .enable          ((cmd_line_state == STATE_CMD_FILLRECT) && ~data_ready_n),
        .clk             (clk_in),
        .mem_clk         (clk_in),
        .data_in         (data_rx_latch),
        .addr            (cmd_fillrect_addr),
        .data_out        (cmd_fillrect_do),
        .ram_write_enable(cmd_fillrect_we),
        .ram_access_start(cmd_fillrect_as),
        .ready_for_data  (cmd_fillrect_rfd),
        .done            (cmd_fillrect_done)
    );

    wire                        cmd_readframe_we;
    wire                        cmd_readframe_as;
    wire                        cmd_readframe_done;
    wire                  [7:0] cmd_readframe_do;
    wire types::fb_addr_t       cmd_readframe_addr;

    control_cmd_readframe #(
        ._UNUSED('d0)
    ) cmd_readframe (
        .reset           (reset),
        .enable          ((cmd_line_state == STATE_CMD_READFRAME) && ~data_ready_n),
        .clk             (clk_in),
        .data_in         (data_rx_latch),
        .addr            (cmd_readframe_addr),
        .data_out        (cmd_readframe_do),
        .ram_write_enable(cmd_readframe_we),
        .ram_access_start(cmd_readframe_as),
        .done            (cmd_readframe_done)
    );

`ifdef USE_WATCHDOG
    wire cmd_watchdog_done;
    wire cmd_watchdog_sysreset;

    control_cmd_watchdog #(
        .WATCHDOG_CONTROL_TICKS(WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) cmd_watchdog (
        .reset    (reset),
        .enable   ((cmd_line_state == STATE_CMD_WATCHDOG) && ~data_ready_n),
        .clk      (clk_in),
        .data_in  (data_rx_latch),
        .sys_reset(cmd_watchdog_sysreset),
        .done     (cmd_watchdog_done)
    );
    assign watchdog_reset = cmd_watchdog_sysreset;
`endif

    always_comb begin
        cmd_addr = 'b0;
        ram_data_out = 8'b0;
        ram_write_enable = 1'b0;
        ram_access_start = 1'b0;
        state_done = 1'b0;
        brightness_change_enable = 1'b0;
        brightness_data_out = 'b0;
        ready_for_data_logic = 1'b1;
        case (cmd_line_state)
            STATE_CMD_READBRIGHTNESS: begin
                brightness_change_enable = cmd_readbrightness_be;
                brightness_data_out = cmd_readbrightness_do;
                state_done = cmd_readbrightness_done;
            end
            STATE_CMD_READFRAME: begin
                cmd_addr         = cmd_readframe_addr;
                ram_data_out     = cmd_readframe_do;
                ram_write_enable = cmd_readframe_we;
                ram_access_start = cmd_readframe_as;
                state_done       = cmd_readframe_done;
            end
            STATE_CMD_READROW: begin
                cmd_addr         = cmd_readrow_addr;
                ram_data_out     = cmd_readrow_do;
                ram_write_enable = cmd_readrow_we;
                ram_access_start = cmd_readrow_as;
                state_done       = cmd_readrow_done;
            end
            STATE_CMD_BLANKPANEL: begin
                cmd_addr             = cmd_blankpanel_addr;
                ram_data_out         = cmd_blankpanel_do;
                ram_write_enable     = cmd_blankpanel_we;
                ram_access_start     = cmd_blankpanel_as;
                state_done           = cmd_blankpanel_done;
                ready_for_data_logic = 1'b0;
            end
            STATE_CMD_FILLPANEL: begin
                cmd_addr             = cmd_fillpanel_addr;
                ram_data_out         = cmd_fillpanel_do;
                ram_write_enable     = cmd_fillpanel_we;
                ram_access_start     = cmd_fillpanel_as;
                state_done           = cmd_fillpanel_done;
                ready_for_data_logic = cmd_fillpanel_rfd;
            end
            STATE_CMD_FILLRECT: begin
                cmd_addr             = cmd_fillrect_addr;
                ram_data_out         = cmd_fillrect_do;
                ram_write_enable     = cmd_fillrect_we;
                ram_access_start     = cmd_fillrect_as;
                state_done           = cmd_fillrect_done;
                ready_for_data_logic = cmd_fillrect_rfd;
            end
            STATE_CMD_READPIXEL: begin
                cmd_addr         = cmd_readpixel_addr;
                ram_data_out     = cmd_readpixel_do;
                ram_write_enable = cmd_readpixel_we;
                ram_access_start = cmd_readpixel_as;
                state_done       = cmd_readpixel_done;
            end
`ifdef USE_WATCHDOG
            STATE_CMD_WATCHDOG: begin
                state_done = cmd_watchdog_done;
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
            rgb_enable <= '1;  // all 1's
`ifdef DOUBLE_BUFFER
            frame_select <= 1'b0;
            frame_select_temp <= 1'b0;
`endif
            brightness_enable <= '1;  // all 1's
            brightness_temp <= '1;  // all 1's;

            cmd_line_state <= STATE_IDLE;
`ifdef DEBUGGER
            num_commands_processed <= 8'b0;
`endif
        end else begin
            if (state_done) begin
                if (data_ready_n && cmd_line_state != STATE_IDLE) cmd_line_state <= STATE_IDLE;
`ifdef DEBUGGER
                num_commands_processed <= num_commands_processed + 'd1;
`endif
            end
            if (brightness_enable != brightness_temp) begin
                brightness_enable <= brightness_temp;
            end else if (brightness_change_enable) begin
                brightness_enable <= brightness_data_out;
                brightness_temp   <= brightness_data_out;
            end
`ifdef DOUBLE_BUFFER
            if (frame_select_temp != frame_select) frame_select <= frame_select_temp;
`endif
            /* CMD: Main */
            if ((cmd_line_state == STATE_IDLE || state_done) && ~data_ready_n) begin
                case (data_rx_latch.opcode)
                    cmd::RED_ENABLE: begin
                        rgb_enable.red <= 1'b1;
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::RED_DISABLE: begin
                        rgb_enable.red <= 1'b0;
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::GREEN_ENABLE: begin
                        rgb_enable.green <= 1'b1;
                        cmd_line_state   <= STATE_IDLE;
                    end
                    cmd::GREEN_DISABLE: begin
                        rgb_enable.green <= 1'b0;
                        cmd_line_state   <= STATE_IDLE;
                    end
                    cmd::BLUE_ENABLE: begin
                        rgb_enable.blue <= 1'b1;
                        cmd_line_state  <= STATE_IDLE;
                    end
                    cmd::BLUE_DISABLE: begin
                        rgb_enable.blue <= 1'b0;
                        cmd_line_state  <= STATE_IDLE;
                    end
                    // TODO: Change this. If the scale is (off/dark) 0 -> 9 (on/bright), then BRIGHTNESS_ONE (alone) should be relatively dim.
                    //       However, this reads to me (as-is) that BRIGHTNESS_ONE will toggle the heights-weight bit
                    cmd::BRIGHTNESS_ONE: begin
                        brightness_temp[BRIGHTNESS_LEVELS-1] <= ~brightness_enable[BRIGHTNESS_LEVELS-1];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_TWO: begin
                        brightness_temp[BRIGHTNESS_LEVELS-2] <= ~brightness_enable[BRIGHTNESS_LEVELS-2];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_THREE: begin
                        brightness_temp[BRIGHTNESS_LEVELS-3] <= ~brightness_enable[BRIGHTNESS_LEVELS-3];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_FOUR: begin
                        brightness_temp[BRIGHTNESS_LEVELS-4] <= ~brightness_enable[BRIGHTNESS_LEVELS-4];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_FIVE: begin
                        brightness_temp[BRIGHTNESS_LEVELS-5] <= ~brightness_enable[BRIGHTNESS_LEVELS-5];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_SIX: begin
                        brightness_temp[BRIGHTNESS_LEVELS-6] <= ~brightness_enable[BRIGHTNESS_LEVELS-6];
                        cmd_line_state <= STATE_IDLE;
                    end
`ifdef RGB24
                    cmd::BRIGHTNESS_SEVEN: begin
                        brightness_temp[BRIGHTNESS_LEVELS-7] <= ~brightness_enable[BRIGHTNESS_LEVELS-7];
                        cmd_line_state <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_EIGHT: begin
                        brightness_temp[BRIGHTNESS_LEVELS-8] <= ~brightness_enable[BRIGHTNESS_LEVELS-8];
                        cmd_line_state <= STATE_IDLE;
                    end
`endif
                    cmd::BRIGHTNESS_ZERO: begin
                        brightness_temp <= 'b0;
                        cmd_line_state  <= STATE_IDLE;
                    end
                    cmd::BRIGHTNESS_NINE: begin
                        brightness_temp <= '1;  // all 1's
                        cmd_line_state  <= STATE_IDLE;
                    end
                    cmd::READBRIGHTNESS: cmd_line_state <= STATE_CMD_READBRIGHTNESS;
                    cmd::BLANKPANEL: cmd_line_state <= STATE_CMD_BLANKPANEL;
                    cmd::FILLPANEL: cmd_line_state <= STATE_CMD_FILLPANEL;
                    cmd::FILLRECT: cmd_line_state <= STATE_CMD_FILLRECT;
                    cmd::READFRAME: cmd_line_state <= STATE_CMD_READFRAME;
                    cmd::READROW: begin
                        cmd_line_state <= STATE_CMD_READROW;
                    end
                    cmd::READPIXEL: cmd_line_state <= STATE_CMD_READPIXEL;
`ifdef USE_WATCHDOG
                    cmd::WATCHDOG: cmd_line_state <= STATE_CMD_WATCHDOG;
`endif
`ifdef DOUBLE_BUFFER
                    cmd::TOGGLE_FRAME: frame_select_temp <= ~frame_select;
`endif
                    default: begin
                        cmd_line_state <= STATE_IDLE;
                        if (brightness_change_enable) brightness_temp <= brightness_data_out;
                    end
                endcase
            end
        end
    end
    wire _unused_ok = &{1'b0, 1'b0};
endmodule
