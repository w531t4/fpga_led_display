// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readcol #(
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
    // Column index is streamed MSB-first; payload is row-major with pixel bytes MSB-first.
    localparam integer unsigned _NUM_COLUMN_BYTES_NEEDED = calc::num_bytes_to_contain($bits(types::col_addr_t));
    localparam types::col_addr_field_byte_index_t LAST_COL_BYTE_INDEX = types::col_addr_field_byte_index_t'(
        _NUM_COLUMN_BYTES_NEEDED - 1
    );
    localparam types::row_addr_t LAST_ROW = types::row_addr_t'(params::PIXEL_HEIGHT - 1);
    typedef enum {
        STATE_COLUMN_CAPTURE,      // capture column address bytes
        STATE_COLUMN_PRIMEMEMWRITE, // first payload byte primes addr/pixel
        STATE_READ_COLUMNCONTENT,  // stream remaining payload bytes
        STATE_DONE                 // cleanup and wait for next opcode
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    types::col_addr_field_t column_bits;
    types::col_addr_field_byte_index_t column_byte_counter;

    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_COLUMN_CAPTURE;
            addr.row <= 'b0;
            addr.col <= 'b0;
            addr.pixel <= 'b0;
            done <= 1'b0;
            column_byte_counter <= 'b0;
            column_bits <= 'b0;
        end else begin
            ram_access_start <= 1'b0;
            // Keep the decoded column address visible once the field is captured.
            addr.col <= types::col_addr_from_field(column_bits);
            case (state)
                STATE_COLUMN_CAPTURE: begin
                    // Header phase: latch the (possibly multi-byte) column index, MSB-first.
                    if (enable) begin
                        ram_write_enable <= 1'b0;
                        data_out <= 8'b0;
                        done <= 1'b0;
                        column_bits.bytes[LAST_COL_BYTE_INDEX - column_byte_counter] <= data_in;
                        if (column_byte_counter == LAST_COL_BYTE_INDEX) begin
                            state <= STATE_COLUMN_PRIMEMEMWRITE;
                        end else column_byte_counter <= column_byte_counter + 1;
                    end
                end
                STATE_COLUMN_PRIMEMEMWRITE: begin
                    // First payload byte: start at row 0 and the MSB byte of the pixel.
                    if (enable) begin
                        state <= STATE_READ_COLUMNCONTENT;
                        addr.row <= 'b0;
                        addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= 1'b1;
                    end
                end
                STATE_READ_COLUMNCONTENT: begin
                    // Payload phase: walk rows top-to-bottom, pixel bytes MSB-to-LSB per row.
                    if (enable) begin
                        ram_access_start <= 1'b1;
                        if (addr.row != LAST_ROW || addr.pixel != 'd0) begin
                            if (addr.pixel == 'd0) begin
                                addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                                addr.row <= addr.row + 'd1;
                            end else begin
                                if (addr.row == LAST_ROW && ((addr.pixel - 'd1) == 0)) begin
                                    done <= 1'b1;
                                    state <= STATE_DONE;
                                end
                                addr.pixel <= addr.pixel - 'd1;
                            end
                            data_out <= data_in;
                        end
                    end
                end
                STATE_DONE: begin
                    // Reset internal state so the next column stream starts cleanly.
                    state <= STATE_COLUMN_CAPTURE;
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
