// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readrow #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,

    output types::fb_addr_t addr,
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
            addr.row <= 'b0;
            addr.col <= 'b0;
            addr.pixel <= 'b0;
            done <= 1'b0;
        end else begin
            case (state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        addr.row <= types::row_addr_t'(data_in);
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
                        addr.col <= 'b0;
                        addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                        // Engage memory gears

                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                    end
                end
                STATE_READ_ROWCONTENT: begin
                    if (enable) begin
                        ram_access_start <= !ram_access_start;
                        if (addr.col != types::col_addr_t'(params::PIXEL_WIDTH - 1) || addr.pixel != 'd0) begin
                            if (addr.pixel == 'd0) begin
                                addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                                addr.col   <= addr.col + 'd1;
                            end else begin
                                if (addr.col == types::col_addr_t'(params::PIXEL_WIDTH - 1) && ((addr.pixel - 'd1) == 0)) begin
                                    done  <= 1'b1;
                                    state <= STATE_DONE;
                                end
                                addr.pixel <= addr.pixel - 'd1;
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
