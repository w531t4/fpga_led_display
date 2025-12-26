// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readrow #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,

    output logic [_NUM_ROW_ADDRESS_BITS-1:0] row,
    output logic [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    typedef enum {STATE_ROW_CAPTURE,
                  STATE_ROW_PRIMEMEMWRITE,
                  STATE_READ_ROWCONTENT,
                  STATE_DONE
                  } ctrl_fsm;
    ctrl_fsm state;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_CAPTURE;
            row <= {_NUM_ROW_ADDRESS_BITS{1'b0}};
            column <= {_NUM_COLUMN_ADDRESS_BITS{1'b0}};
            pixel <= {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
            done <= 1'b0;
        end else begin
            case(state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        row[_NUM_ROW_ADDRESS_BITS-1:0] <= data_in[4:0];
                        ram_write_enable <= 1'b0;
                        data_out <= 8'b0;
                        state <= STATE_ROW_PRIMEMEMWRITE;
                        done <= 1'b0;
                    end
                end
                STATE_ROW_PRIMEMEMWRITE: begin
                    if (enable) begin
                        /* first, get the row to write to */

                        state <= STATE_READ_ROWCONTENT;
                        column[_NUM_COLUMN_ADDRESS_BITS-1:0] <= (_NUM_COLUMN_ADDRESS_BITS)'(PIXEL_WIDTH - 1);
                        pixel <= (_NUM_PIXELCOLORSELECT_BITS)'(BYTES_PER_PIXEL - 1);
                        // Engage memory gears

                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                    end
                end
                STATE_READ_ROWCONTENT: begin
                    if (enable) begin
                        ram_access_start <= !ram_access_start;
                        if (column != 'd0 || pixel != 'd0) begin
                            if (pixel == 'd0) begin
                                pixel <= (_NUM_PIXELCOLORSELECT_BITS)'(BYTES_PER_PIXEL - 1);
                                column <= column - 'd1;
                            end else begin
                                if (column == 0 && ((pixel - 'd1) == 0)) begin
                                    done <= 1'b1;
                                    state <= STATE_DONE;
                                end
                                pixel <= pixel - 'd1;
                            end
                            data_out <= data_in;
                        end
                        /* store this byte */
                    end
                end
                STATE_DONE: begin
                    state <= STATE_ROW_CAPTURE;
                    done <= 1'b0;
                    ram_write_enable <= 1'b0;
                    data_out <= 8'b0;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
