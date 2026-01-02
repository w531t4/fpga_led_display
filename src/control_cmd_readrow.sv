// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readrow #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,

    output logic [calc_pkg::num_row_address_bits(PIXEL_HEIGHT)-1:0] row,
    output logic [calc_pkg::num_column_address_bits(PIXEL_WIDTH)-1:0] column,
    output logic [calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    typedef enum {
        STATE_ROW_CAPTURE,
        STATE_ROW_PRIMEMEMWRITE,
        STATE_READ_ROWCONTENT,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_CAPTURE;
            row <= {calc_pkg::num_row_address_bits(PIXEL_HEIGHT) {1'b0}};
            column <= {calc_pkg::num_column_address_bits(PIXEL_WIDTH) {1'b0}};
            pixel <= {calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL) {1'b0}};
            done <= 1'b0;
        end else begin
            case (state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        row[calc_pkg::num_row_address_bits(PIXEL_HEIGHT)-1:0] <= data_in[4:0];
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
                        column[calc_pkg::num_column_address_bits(
                            PIXEL_WIDTH
                        )-1:0] <= (calc_pkg::num_column_address_bits(
                            PIXEL_WIDTH
                        ))'(PIXEL_WIDTH - 1);
                        pixel <= (calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
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
                                pixel  <= (calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
                                column <= column - 'd1;
                            end else begin
                                if (column == 0 && ((pixel - 'd1) == 0)) begin
                                    done  <= 1'b1;
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
