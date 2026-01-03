// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_subcmd_fillarea #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input enable,
    input clk,
    input ack,
    input types::col_addr_t x1,
    input types::row_addr_t y1,
    input types::col_addr_t width,
    input types::row_addr_t height,
    input types::color_t color,  // must be byte aligned

    output types::row_addr_t row,
    output types::col_addr_t column,
    output types::pixel_addr_t pixel,
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
    wire types::col_addr_t x2;
    wire types::row_addr_t y2;

    assign x2 = x1 + width;
    assign y2 = y1 + height;

    typedef enum {
        STATE_ROW_PRIMEMEMWRITE,
        STATE_ROW_MEMWRITE,
        STATE_WAIT_FOR_RESET
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_PRIMEMEMWRITE;
            row <= 'b0;
            column <= 'b0;
            pixel <= 'b0;
            done <= 1'b0;
        end else begin
            case (state)
                STATE_ROW_PRIMEMEMWRITE: begin
                    if (enable) begin

                        state <= STATE_ROW_MEMWRITE;
                        row <= y2 - 1;
                        column <= x2 - 1;
                        pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                        // Engage memory gears
                        ram_write_enable <= 1'b1;
                        data_out <= color[(((32)'(pixel)+1)*8)-1-:8];
                        ram_access_start <= !ram_access_start;
                    end
                end
                STATE_ROW_MEMWRITE: begin
                    if (enable) begin
                        ram_access_start <= !ram_access_start;
                        if (row > y1 || column > x1 || pixel != 'd0) begin
                            if (pixel == 'd0) begin
                                pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                                if (column == x1) begin
                                    column <= x2 - 1;
                                    row <= row - 'd1;
                                end else begin
                                    column <= column - 'd1;
                                end
                            end else begin
                                if (row == y1 && column == x1 && ((pixel - 'd1) == 0)) done <= 1'b1;
                                pixel <= pixel - 'd1;
                            end
                            data_out <= color[(((32)'(pixel)+1)*8)-1-:8];
                        end else begin
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
                        done  <= 1'b0;
                    end
                end
                default: state <= state;
            endcase
        end
    end
endmodule
