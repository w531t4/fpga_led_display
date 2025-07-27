`default_nettype none
module control_module #(
    `include "params.vh"
    `include "memory_calcs.vh"
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH),
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    input [7:0] data_rx,
    input data_ready_n,
    output logic [2:0] rgb_enable,
    output logic [BRIGHTNESS_LEVELS-1:0] brightness_enable,
    output logic [_NUM_DATA_A_BITS-1:0] ram_data_out,
    output logic [_NUM_ADDRESS_A_BITS-1:0] ram_address,     // with 64x32 matrix at 2bytes per pixel, this is 12 bits [11:0]
    output logic ram_write_enable,
    output logic ram_clk_enable
    `ifdef DEBUGGER
        ,
        output [2:0] cmd_line_state2,
        output ram_access_start2,
        output ram_access_start_latch2,
        output [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr2,
        output logic [7:0] num_commands_processed
    `endif
);
    // for now, if adding new states, ensure cmd_line_state2 is updated.
    typedef enum {STATE_IDLE,
                  STATE_CMD_READROW,
                  STATE_CMD_READBRIGHTNESS,
                  STATE_CMD_READPIXEL
                  } ctrl_fsm;
    logic [BRIGHTNESS_LEVELS-1:0] brightness_temp;
    logic ram_access_start;
    logic ram_access_start_latch;
    wire [1:0] timer_counter_unused;
    ctrl_fsm cmd_line_state;
    logic [$clog2(PIXEL_HEIGHT)-1:0] cmd_line_addr_row;     // For 32 bit high displays, [4:0]
    logic [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_line_addr_col; // For 64 bit wide displays @ 2 bytes per pixel == 128, -> 127 -> [6:0]
    logic [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_line_pixelselect_num;
    wire [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr =
        {  cmd_line_addr_row[$clog2(PIXEL_HEIGHT)-1:0],
          ~cmd_line_addr_col,
          ~cmd_line_pixelselect_num}; // <-- use this to toggle endainness. ~ == little endain
                                      //                                      == bit endian
                                      // NOTE: uart/alphabet.uart is BIG ENDIAN.
    logic state_done;
    logic brightness_change_enable;
    logic [BRIGHTNESS_LEVELS-1:0] brightness_data_out;

    `ifdef DEBUGGER
        assign cmd_line_state2 = cmd_line_state;
        assign cmd_line_addr2 = cmd_line_addr;
        assign ram_access_start2 = ram_access_start;
        assign ram_access_start_latch2 = ram_access_start_latch;
    `endif

    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_cmd_line_write (
        .reset(reset),
        .clk_in(~clk_in),
        .start(ram_access_start ^ ram_access_start_latch), // ^ is exclusive or
        .value(2'b10),
        .counter(timer_counter_unused),
        .running(ram_clk_enable)
    );

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

    wire cmd_readrow_we, cmd_readrow_as, cmd_readrow_done;
    wire [7:0] cmd_readrow_do;
    wire [$clog2(PIXEL_HEIGHT)-1:0] cmd_readrow_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_readrow_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readrow_pixel_addr;

    control_cmd_readrow #(
    ) cmd_readrow (
        // .cmd_enable(cmd_line_state == STATE_CMD_READROW),
        .reset(reset),
        .data_in(data_rx),
        .enable(cmd_line_state == STATE_CMD_READROW),
        .clk_n(data_ready_n),

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
    wire [$clog2(PIXEL_HEIGHT)-1:0] cmd_readpixel_row_addr;
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] cmd_readpixel_col_addr;
    wire [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_readpixel_pixel_addr;

    control_cmd_readpixel #(
    ) cmd_readpixel (
        // .cmd_enable(cmd_line_state == STATE_CMD_READROW),
        .reset(reset),
        .data_in(data_rx),
        .clk_n(data_ready_n),
        .enable(cmd_line_state == STATE_CMD_READPIXEL),
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
    wire [BRIGHTNESS_LEVELS-1:0] cmd_readbrightness_do;
    control_cmd_readbrightness #(
    ) cmd_readbrightness (
        .reset(reset),
        .data_in(data_rx),
        .clk_n(data_ready_n),
        .enable(cmd_line_state == STATE_CMD_READBRIGHTNESS),
        .data_out(cmd_readbrightness_do),
        .brightness_change_en(cmd_readbrightness_be),
        .done(cmd_readbrightness_done)
    );

    always @(*) begin
        cmd_line_addr_row = {$clog2(PIXEL_HEIGHT){1'b0}};
        cmd_line_addr_col = {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
        cmd_line_pixelselect_num = {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
        ram_data_out = 8'b0;
        ram_write_enable = 1'b0;
        ram_access_start = 1'b0;
        state_done = 1'b0;
        brightness_change_enable = 1'b0;
        brightness_data_out = {BRIGHTNESS_LEVELS{1'b0}};

        case (cmd_line_state)
            STATE_CMD_READBRIGHTNESS: begin
                brightness_change_enable = cmd_readbrightness_be;
                brightness_data_out = cmd_readbrightness_do;
                state_done = cmd_readbrightness_done;
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
            STATE_CMD_READPIXEL: begin
                cmd_line_addr_row = cmd_readpixel_row_addr;
                cmd_line_addr_col = cmd_readpixel_col_addr;
                cmd_line_pixelselect_num = cmd_readpixel_pixel_addr;
                ram_data_out = cmd_readpixel_do;
                ram_write_enable = cmd_readpixel_we;
                ram_access_start = cmd_readpixel_as;
                state_done = cmd_readpixel_done;
            end
            default: begin
            end
        endcase
    end

    always @(negedge data_ready_n, posedge reset) begin
        if (reset) begin
            rgb_enable <= 3'b111;
            brightness_enable <= {BRIGHTNESS_LEVELS{1'b1}};
            brightness_temp <= {BRIGHTNESS_LEVELS{1'b1}};

            cmd_line_state <= STATE_IDLE;
            `ifdef DEBUGGER
                num_commands_processed <= 8'b0;
            `endif
        end
        else begin
            if (brightness_enable != brightness_temp) begin
                brightness_enable <= brightness_temp;
            end else if (brightness_change_enable) begin
                brightness_enable <= brightness_data_out;
                brightness_temp <= brightness_data_out;
            end
            /* CMD: Main */
            if (cmd_line_state == STATE_IDLE || state_done) begin
                case (data_rx)
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
                        brightness_temp[BRIGHTNESS_LEVELS - 1] <= ~brightness_enable[BRIGHTNESS_LEVELS - 1];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "2": begin
                        brightness_temp[BRIGHTNESS_LEVELS - 2] <= ~brightness_enable[BRIGHTNESS_LEVELS - 2];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "3": begin
                        brightness_temp[BRIGHTNESS_LEVELS - 3] <= ~brightness_enable[BRIGHTNESS_LEVELS - 3];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "4": begin
                        brightness_temp[BRIGHTNESS_LEVELS - 4] <= ~brightness_enable[BRIGHTNESS_LEVELS - 4];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "5": begin
                        brightness_temp[BRIGHTNESS_LEVELS - 5] <= ~brightness_enable[BRIGHTNESS_LEVELS - 5];
                        cmd_line_state <= STATE_IDLE;
                    end
                    "6": begin
                        brightness_temp[BRIGHTNESS_LEVELS - 6] <= ~brightness_enable[BRIGHTNESS_LEVELS - 6];
                        cmd_line_state <= STATE_IDLE;
                    end
                    `ifdef RGB24
                        "7": begin
                            brightness_temp[BRIGHTNESS_LEVELS - 7] <= ~brightness_enable[BRIGHTNESS_LEVELS - 7];
                            cmd_line_state <= STATE_IDLE;
                        end
                        "8": begin
                            brightness_temp[BRIGHTNESS_LEVELS - 8] <= ~brightness_enable[BRIGHTNESS_LEVELS - 8];
                            cmd_line_state <= STATE_IDLE;
                        end
                    `endif
                    "0": begin
                        brightness_temp <= {BRIGHTNESS_LEVELS{1'b0}};
                        cmd_line_state <= STATE_IDLE;
                    end
                    "9": begin
                        brightness_temp <= {BRIGHTNESS_LEVELS{1'b1}};
                        cmd_line_state <= STATE_IDLE;
                    end
                    "T": cmd_line_state <= STATE_CMD_READBRIGHTNESS;
                    "L": begin
                        cmd_line_state <= STATE_CMD_READROW;
                    end
                    "P": cmd_line_state <= STATE_CMD_READPIXEL;
                    default: begin
                        cmd_line_state <= STATE_IDLE;
                        if (brightness_change_enable) brightness_temp <= brightness_data_out;
                    end
                endcase
            end
        end
    end
    wire _unused_ok = &{1'b0,
                        timer_counter_unused,
                        1'b0};
endmodule
