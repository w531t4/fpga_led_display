// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readframe #(
    // Unproven yet
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,

    output types::row_addr_t row,
    output types::col_addr_t column,
    output types::pixel_addr_t pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    typedef enum {
        STATE_FRAME_PRIMEMEMWRITE,
        STATE_READ_FRAMECONTENT,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_FRAME_PRIMEMEMWRITE;
            row <= 'b0;
            column <= 'b0;
            pixel <= 'b0;
            done <= 1'b0;
        end else begin
            case (state)
                STATE_FRAME_PRIMEMEMWRITE: begin
                    if (enable) begin
                        /* first, get the row to write to */
                        state <= STATE_READ_FRAMECONTENT;
                        row <= types::row_addr_t'(params::PIXEL_HEIGHT - 1);
                        column <= types::col_addr_t'(params::PIXEL_WIDTH - 1);
                        pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                        // Engage memory gears
                        data_out <= data_in;
                        ram_write_enable <= 1'b1;
                        ram_access_start <= !ram_access_start;
                    end
                end
                STATE_READ_FRAMECONTENT: begin
                    if (enable) begin
                        ram_access_start <= !ram_access_start;
                        data_out <= data_in;
                        if (row > 'd0 || column > 'd0 || pixel != 'd0) begin
                            if (pixel == 'd0) begin
                                pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                                if (column == 'd0) begin
                                    column <= types::col_addr_t'(params::PIXEL_WIDTH - 1);
                                    row <= row - 'd1;
                                end else begin
                                    column <= column - 'd1;
                                end
                            end else begin
                                if (row == 'd0 && column == 'd0 && ((pixel - 'd1) == 0)) begin
                                    done <= 1'b1;
                                end
                                pixel <= pixel - 'd1;
                            end
                        end else begin
                            state <= STATE_DONE;
                            data_out <= 8'b0;
                            done <= 1'b0;
                        end
                    end
                end
                STATE_DONE: begin
                    state <= STATE_FRAME_PRIMEMEMWRITE;
                    done <= 1'b0;
                    ram_write_enable <= 1'b0;
                    data_out <= 8'b0;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
