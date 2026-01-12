// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readframe #(
    // Unproven yet
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
        STATE_FRAME_PRIMEMEMWRITE,
        STATE_READ_FRAMECONTENT,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    // Cache the last valid address so we can assert done only after the final byte is accepted.
    localparam types::row_addr_t LAST_ROW = types::row_addr_t'(params::PIXEL_HEIGHT - 1);
    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_FRAME_PRIMEMEMWRITE;
            addr.row <= 'b0;
            addr.col <= 'b0;
            addr.pixel <= 'b0;
            done <= 1'b0;
        end else begin
            case (state)
                STATE_FRAME_PRIMEMEMWRITE: begin
                    if (enable) begin
                        /* first, get the row to write to */
                        state <= STATE_READ_FRAMECONTENT;
                        addr.row <= 'b0;
                        addr.col <= 'b0;
                        addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
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
                        done <= 1'b0;
                        if (addr.pixel == 'd0) begin
                                addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                            if (addr.col == LAST_COL) begin
                                    addr.col <= 'b0;
                                    addr.row <= addr.row + 'd1;
                                end else begin
                                    addr.col <= addr.col + 'd1;
                                end
                            end else begin
                            // Assert done on the last payload byte so we
                            // do not consume the next opcode as frame data.
                            if ((addr.row == LAST_ROW) && (addr.col == LAST_COL) && ((addr.pixel - 'd1) == 0)) begin
                                    done <= 1'b1;
                                state <= STATE_DONE;
                                end
                                addr.pixel <= addr.pixel - 'd1;
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
