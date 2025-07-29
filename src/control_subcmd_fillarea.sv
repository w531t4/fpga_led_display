`default_nettype none
module control_subcmd_fillarea #(
    `include "params.vh"
    `include "memory_calcs.vh"
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH),
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input enable,
    input clk,
    input ack,
    input [_NUM_COLUMN_ADDRESS_BITS-1:0] x1,
    input [$clog2(PIXEL_HEIGHT)-1:0] y1,
    input [_NUM_COLUMN_ADDRESS_BITS-1:0] width,
    input [$clog2(PIXEL_HEIGHT)-1:0] height,
    input [(BYTES_PER_PIXEL*8)-1:0] color, // must be byte aligned

    output logic [$clog2(PIXEL_HEIGHT)-1:0] row,
    output logic [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    /* fillrect
            .(0,0)
            |----------------------
            |    v(x1,y1)
            |    .-------
            |    |cccccc|
            |    |cccccc|
            |    -------.
            |           ^(x1+width, y1+height)
    */
    wire [_NUM_COLUMN_ADDRESS_BITS-1:0] x2;
    wire [$clog2(PIXEL_HEIGHT)-1:0] y2;

    assign x2 = x1 + width;
    assign y2 = y1 + height;

    typedef enum {STATE_ROW_PRIMEMEMWRITE,
                  STATE_ROW_MEMWRITE,
                  STATE_WAIT_FOR_RESET
                  } ctrl_fsm;
    ctrl_fsm state;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_PRIMEMEMWRITE;
            row <= {$clog2(PIXEL_HEIGHT){1'b0}};
            column <= {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
            pixel <= {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
            done <= 1'b0;
        end
        else begin
            case(state)
                STATE_ROW_PRIMEMEMWRITE: begin
                    if (enable) begin

                        state <= STATE_ROW_MEMWRITE;
                        row <= ($clog2(PIXEL_HEIGHT))'(y2-1);
                        column[_NUM_COLUMN_ADDRESS_BITS-1:0] <= (_NUM_COLUMN_ADDRESS_BITS)'(x2-1);
                        pixel <= (_NUM_PIXELCOLORSELECT_BITS)'(BYTES_PER_PIXEL - 1);
                        // Engage memory gears
                        ram_write_enable <= 1'b1;
                        data_out <= color[(((32)'(pixel) + 1) * 8)-1 -: 8];
                        ram_access_start <= !ram_access_start;
                    end
                end
                STATE_ROW_MEMWRITE: begin
                    if (enable) begin
                        ram_access_start <= !ram_access_start;
                        if (row > y1 || column > x1 || pixel != 'd0) begin
                            if (pixel == 'd0) begin
                                pixel <= (_NUM_PIXELCOLORSELECT_BITS)'(BYTES_PER_PIXEL - 1);
                                if (column == x1) begin
                                    column[_NUM_COLUMN_ADDRESS_BITS-1:0] <= (_NUM_COLUMN_ADDRESS_BITS)'(x2-1);
                                    row <= row - 'd1;
                                end else begin
                                    column <= column - 'd1;
                                end
                            end else begin
                                if (row == y1 && column == x1 && ((pixel - 'd1) == 0)) done <= 1'b1;
                                pixel <= pixel - 'd1;
                            end
                            data_out <= color[(((32)'(pixel) + 1) * 8)-1 -: 8];
                        end
                        else begin
                            state <= STATE_WAIT_FOR_RESET;
                            ram_write_enable <= 1'b0;
                            data_out <= 8'b0;
                        end
                        /* store this byte */
                    end
                end
                STATE_WAIT_FOR_RESET: begin
                    if (ack) begin
                        state <= STATE_ROW_PRIMEMEMWRITE;
                        done <= 1'b0;
                    end
                end
                default: state <= state;
            endcase
        end
    end
endmodule
