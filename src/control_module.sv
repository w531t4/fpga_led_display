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
        output ram_access_start2,
        output ram_access_start_latch2,
        output [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr2,
        output logic [7:0] num_commands_processed
    `endif
);
    typedef enum {STATE_IDLE,
                  STATE_CMD_READROW
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

    `ifdef DEBUGGER
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
    wire cmd_readrow_ace;

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

    always @(*) begin
        cmd_line_addr_row = {$clog2(PIXEL_HEIGHT){1'b0}};
        cmd_line_addr_col = {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
        cmd_line_pixelselect_num = {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
        ram_data_out = 8'b0;
        ram_write_enable = 1'b0;
        ram_access_start = 1'b0;
        state_done = 1'b0;
        case (cmd_line_state)
            STATE_CMD_READROW: begin
                cmd_line_addr_row = cmd_readrow_row_addr;
                cmd_line_addr_col = cmd_readrow_col_addr;
                cmd_line_pixelselect_num = cmd_readrow_pixel_addr;
                ram_data_out = cmd_readrow_do;
                ram_write_enable = cmd_readrow_we;
                ram_access_start = cmd_readrow_as;
                state_done = cmd_readrow_done;
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
            brightness_enable <= brightness_temp;
            /* CMD: Main */
            if (cmd_line_state == STATE_IDLE || state_done) begin
                case (data_rx)
                    "R": begin
                        rgb_enable[0] <= 1'b1;
                    end
                    "r": begin
                        rgb_enable[0] <= 1'b0;
                    end
                    "G": begin
                        rgb_enable[1] <= 1'b1;
                    end
                    "g": begin
                        rgb_enable[1] <= 1'b0;
                    end
                    "B": begin
                        rgb_enable[2] <= 1'b1;
                    end
                    "b": begin
                        rgb_enable[2] <= 1'b0;
                    end
                    "1": brightness_temp[BRIGHTNESS_LEVELS - 1] <= ~brightness_enable[BRIGHTNESS_LEVELS - 1];
                    "2": brightness_temp[BRIGHTNESS_LEVELS - 2] <= ~brightness_enable[BRIGHTNESS_LEVELS - 2];
                    "3": brightness_temp[BRIGHTNESS_LEVELS - 3] <= ~brightness_enable[BRIGHTNESS_LEVELS - 3];
                    "4": brightness_temp[BRIGHTNESS_LEVELS - 4] <= ~brightness_enable[BRIGHTNESS_LEVELS - 4];
                    "5": brightness_temp[BRIGHTNESS_LEVELS - 5] <= ~brightness_enable[BRIGHTNESS_LEVELS - 5];
                    "6": brightness_temp[BRIGHTNESS_LEVELS - 6] <= ~brightness_enable[BRIGHTNESS_LEVELS - 6];
                    `ifdef RGB24
                        "7": brightness_temp[BRIGHTNESS_LEVELS - 7] <= ~brightness_enable[BRIGHTNESS_LEVELS - 7];
                        "8": brightness_temp[BRIGHTNESS_LEVELS - 8] <= ~brightness_enable[BRIGHTNESS_LEVELS - 8];
                    `endif
                    "0": begin
                        brightness_temp <= {BRIGHTNESS_LEVELS{1'b0}};
                    end
                    "9": begin
                        brightness_temp <= {BRIGHTNESS_LEVELS{1'b1}};
                    end
                    "L": begin
                        cmd_line_state <= STATE_CMD_READROW;
                    end
                    default: begin
                        cmd_line_state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end
    wire _unused_ok = &{1'b0,
                        timer_counter_unused,
                        1'b0};
endmodule
