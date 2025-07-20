`default_nettype none
module control_module #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in, /* clk_root =  133MHZ */

    input [7:0] data_rx,
    input data_ready_n,
    output logic [2:0] rgb_enable,
    output logic [BRIGHTNESS_LEVELS-1:0] brightness_enable,

    output logic [_NUM_DATA_A_BITS-1:0] ram_data_out,
    //      with 64x32 matrix at 2bytes per pixel, this is 12 bits [11:0]
    output logic [_NUM_ADDRESS_A_BITS-1:0] ram_address,
    output logic ram_write_enable,
    output ram_clk_enable
    `ifdef DEBUGGER
        ,
        output [1:0] cmd_line_state2,
        output ram_access_start2,
        output ram_access_start_latch2,
        output [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr2,
        output logic [7:0] num_commands_processed
    `endif
);
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH);
    wire ram_clk_enable_real;
    logic ram_access_start;
    logic ram_access_start_latch;
    `ifdef DEBUGGER
        assign ram_access_start2 = ram_access_start;
        assign ram_access_start_latch2 = ram_access_start_latch;
    `endif
    wire [1:0] timer_counter_unused;
    logic  [1:0]  cmd_line_state;
    // For 32 bit high displays, [4:0]
    logic  [$clog2(PIXEL_HEIGHT)-1:0]  cmd_line_addr_row;
    // For 64 bit wide displays @ 2 bytes per pixel == 128, -> 127 -> [6:0]
    logic  [_NUM_COLUMN_ADDRESS_BITS-1:0]  cmd_line_addr_col;
    logic [_NUM_PIXELCOLORSELECT_BITS-1:0] cmd_line_pixelselect_num;
    wire [_NUM_ADDRESS_A_BITS-1:0] cmd_line_addr =
        {  cmd_line_addr_row[$clog2(PIXEL_HEIGHT)-1:0],
          ~cmd_line_addr_col,
          ~cmd_line_pixelselect_num}; // <-- use this to toggle endainness. ~ == little endain
                                    //                                      == bit endian
                                    // NOTE: uart/alphabet.uart is BIG ENDIAN.

    `ifdef DEBUGGER
        assign cmd_line_state2[1:0] = cmd_line_state[1:0];
        assign cmd_line_addr2 = cmd_line_addr;
    `endif



    // ^ is exclusive or
    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_cmd_line_write (
        .reset(reset),
        .clk_in(~clk_in),
        .start(ram_access_start ^ ram_access_start_latch),
        .value(2'b10),
        .counter(timer_counter_unused),
        .running(ram_clk_enable_real)
    );
    assign ram_clk_enable = ram_clk_enable_real;
    always @(posedge clk_in) begin
        if (reset) begin
            ram_access_start_latch <= 1'b0;
        end
        else begin
            if (ram_clk_enable_real) begin
                ram_access_start_latch <= ram_access_start;
            end
            else begin
            end
        end
    end

    always @(negedge data_ready_n, posedge reset) begin
        if (reset) begin
            rgb_enable <= 3'b111;
            brightness_enable <= {BRIGHTNESS_LEVELS{1'b1}};

            ram_data_out <= 8'd0;
            ram_address <= {_NUM_ADDRESS_A_BITS{1'b0}};
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;

            cmd_line_state <= 2'd0;
            cmd_line_addr_row <= {$clog2(PIXEL_HEIGHT){1'b0}};
            cmd_line_addr_col <= {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
            `ifdef DEBUGGER
                num_commands_processed <= 8'b0;
            `endif
        end


        /* CMD: Line */
        else if (cmd_line_state == 2'd2 && data_rx != "L" ) begin
            /* first, get the row to write to */
            cmd_line_addr_row[$clog2(PIXEL_HEIGHT)-1:0] <= data_rx[4:0];

            /* and start clocking in the column data
               64 pixels x 2 bytes each = 128 bytes */
            // parameter PIXEL_WIDTH = 'd64,
            // parameter BYTES_PER_PIXEL = 'd2
            // cmd_line_addr_col[6:0] <= 7'd127;
            cmd_line_pixelselect_num <= BYTES_PER_PIXEL - 1;
            cmd_line_addr_col[_NUM_COLUMN_ADDRESS_BITS-1:0] <= (_NUM_COLUMN_ADDRESS_BITS)'(PIXEL_WIDTH - 1);
            cmd_line_state <= 2'd1;
        end
        else if (cmd_line_state == 2'd1) begin
            /* decrement the column address (or finish the load) */
            if (cmd_line_addr_col != 'd0 || cmd_line_pixelselect_num != 'd0) begin
                if (cmd_line_pixelselect_num == 'd0) begin
                    cmd_line_pixelselect_num <= BYTES_PER_PIXEL - 1;
                    cmd_line_addr_col <= cmd_line_addr_col - 'd1;
                end else
                    cmd_line_pixelselect_num <= cmd_line_pixelselect_num - 'd1;
            end
            else begin
                cmd_line_state <= 2'd0;
                `ifdef DEBUGGER
                    num_commands_processed <= num_commands_processed + 1'b1;
                `endif
            end

            /* store this byte */
            ram_data_out <= data_rx[7:0];
            ram_address <= cmd_line_addr;
            ram_write_enable <= 1'b1;
            ram_access_start <= !ram_access_start;
        end

        /* CMD: Main */
        else if (cmd_line_state != 2'd2 && !data_ready_n) begin
            //2650000
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
                "1": brightness_enable[BRIGHTNESS_LEVELS - 1] <= ~brightness_enable[BRIGHTNESS_LEVELS - 1];
                "2": brightness_enable[BRIGHTNESS_LEVELS - 2] <= ~brightness_enable[BRIGHTNESS_LEVELS - 2];
                "3": brightness_enable[BRIGHTNESS_LEVELS - 3] <= ~brightness_enable[BRIGHTNESS_LEVELS - 3];
                "4": brightness_enable[BRIGHTNESS_LEVELS - 4] <= ~brightness_enable[BRIGHTNESS_LEVELS - 4];
                "5": brightness_enable[BRIGHTNESS_LEVELS - 5] <= ~brightness_enable[BRIGHTNESS_LEVELS - 5];
                "6": brightness_enable[BRIGHTNESS_LEVELS - 6] <= ~brightness_enable[BRIGHTNESS_LEVELS - 6];
                `ifdef RGB24
                    "7": brightness_enable[BRIGHTNESS_LEVELS - 7] <= ~brightness_enable[BRIGHTNESS_LEVELS - 7];
                    "8": brightness_enable[BRIGHTNESS_LEVELS - 8] <= ~brightness_enable[BRIGHTNESS_LEVELS - 8];
                `endif
                "0": begin
                    brightness_enable <= {BRIGHTNESS_LEVELS{1'b0}};
                end
                "9": begin
                    brightness_enable <= {BRIGHTNESS_LEVELS{1'b1}};
                end
                "L": begin
                    cmd_line_state <= 2'd2;
                end
                default: begin
                    cmd_line_state <= 2'd0;
                    ram_write_enable <= 1'b0;
                end
            endcase
        end
    end
    wire _unused_ok = &{1'b0,
                        timer_counter_unused,
                        1'b0};
endmodule
