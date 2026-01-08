// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readpixel #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input clk,
    input enable,

    output types::fb_addr_t addr,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    localparam integer unsigned _NUM_COLUMN_BYTES_NEEDED = calc::num_bytes_to_contain($bits(types::col_addr_t));
    localparam types::col_addr_field_byte_index_t LAST_COL_BYTE_INDEX = types::col_addr_field_byte_index_t'(_NUM_COLUMN_BYTES_NEEDED - 1);
    typedef enum {
        STATE_ROW_CAPTURE,
        STATE_COLUMN_CAPTURE,
        STATE_PIXEL_PRIMEMEMWRITE,
        STATE_READ_PIXELBYTES,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    types::col_addr_field_t column_bits;
    types::col_addr_field_byte_index_t column_byte_counter;

    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_CAPTURE;
            addr.row <= 'b0;
            addr.pixel <= 'b0;
            done <= 1'b0;
            column_byte_counter <= 'b0;
            column_bits <= 'b0;
            addr.col <= 'b0;
        end else begin
            addr.col <= types::col_addr_from_field(column_bits);
            case (state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        ram_write_enable <= 1'b0;
                        done <= 1'b0;
                        state <= STATE_COLUMN_CAPTURE;
                        addr.row <= types::row_addr_t'(data_in);
                        column_byte_counter <= 'b0;
                        column_bits <= 'b0;
                    end
                end
                STATE_COLUMN_CAPTURE: begin
                    // Big Endian
                    if (enable) begin
                        ram_write_enable <= 1'b0;
                        // load (potentially multibyte) column number
                        //   - if multibyte, expect big endian (MSB -> LSB)
                        column_bits.bytes[LAST_COL_BYTE_INDEX - column_byte_counter] <= data_in;
                        if (column_byte_counter == LAST_COL_BYTE_INDEX) begin
                            state <= STATE_PIXEL_PRIMEMEMWRITE;
                            addr.pixel <= types::color_index_t'(params::BYTES_PER_PIXEL - 1);
                        end else column_byte_counter <= column_byte_counter + 1;
                    end
                end
                STATE_PIXEL_PRIMEMEMWRITE: begin
                    if (enable) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        if (params::BYTES_PER_PIXEL == 1) begin
                            done  <= 1'b1;
                            state <= STATE_DONE;
                        end else begin
                            state <= STATE_READ_PIXELBYTES;
                        end
                    end
                end
                STATE_READ_PIXELBYTES: begin
                    // Big Endian
                    if (enable) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        if (addr.pixel == 'd1) begin
                            done  <= 1'b1;
                            state <= STATE_DONE;
                        end
                        if (addr.pixel != 'b0) begin
                            addr.pixel <= addr.pixel - 1;
                        end
                    end
                end
                STATE_DONE: begin
                    state <= STATE_ROW_CAPTURE;
                    done <= 1'b0;
                    data_out <= 8'b0;
                    ram_write_enable <= 1'b0;
                    column_byte_counter <= 'b0;
                    ram_access_start <= 1'b0;
                    addr.row <= 'd0;
                    column_bits <= 'd0;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
