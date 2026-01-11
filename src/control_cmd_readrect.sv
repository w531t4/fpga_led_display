// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readrect #(
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
    localparam integer unsigned _NUM_COLUMN_BYTES_NEEDED = calc::num_bytes_to_contain($bits(types::col_addr_t));
    localparam types::col_addr_field_byte_index_t LAST_COL_BYTE_INDEX = types::col_addr_field_byte_index_t'(
        _NUM_COLUMN_BYTES_NEEDED - 1
    );

    // Header capture -> payload streaming state machine.
    typedef enum {
        STATE_X1_CAPTURE,          // capture x1 bytes (big endian)
        STATE_Y1_CAPTURE,          // capture y1 byte
        STATE_WIDTH_CAPTURE,       // capture width bytes (big endian)
        STATE_HEIGHT_CAPTURE,      // capture height byte and clamp
        STATE_ROW_PRIMEMEMWRITE,   // prime first payload write
        STATE_ROW_MEMWRITE,        // stream payload writes
        STATE_DONE                 // cleanup for next command
    } ctrl_fsm_t;
    ctrl_fsm_t state;

    // Header fields captured from the incoming stream.
    types::col_addr_field_t x1;
    types::col_addr_field_t width;
    types::col_addr_field_byte_index_t x1_byte_counter;
    types::col_addr_field_byte_index_t width_byte_counter;
    types::row_addr_t y1;
    types::row_addr_count_t height;

    // Precompute bounds for row/column traversal.
    wire types::col_addr_t x1_addr = types::col_addr_t'(x1);
    wire types::col_addr_t x2;
    wire types::row_addr_t y2;
    assign x2 = types::col_addr_t'(types::col_addr_count_t'(x1_addr)
                                  + types::col_addr_count_t'(width)
                                  - types::col_addr_count_t'(1));
    assign y2 = types::row_addr_t'(types::row_addr_count_t'(y1)
                                  + height
                                  - types::row_addr_count_t'(1));

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_X1_CAPTURE;
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            done <= 1'b0;
            addr.row <= 'b0;
            addr.col <= 'b0;
            addr.pixel <= 'b0;
            x1 <= 'b0;
            width <= 'b0;
            y1 <= 'b0;
            height <= 'b0;
            x1_byte_counter <= 'b0;
            width_byte_counter <= 'b0;
        end else begin
            case (state)
                STATE_X1_CAPTURE: begin
                    // Big endian capture of x1.
                    ram_write_enable <= 1'b0;
                    done <= 1'b0;
                    if (enable) begin
                        x1.bytes[LAST_COL_BYTE_INDEX - x1_byte_counter] <= data_in;
                        if (x1_byte_counter == LAST_COL_BYTE_INDEX) begin
                            state <= STATE_Y1_CAPTURE;
                        end else begin
                            x1_byte_counter <= x1_byte_counter + 1;
                        end
                    end
                end
                STATE_Y1_CAPTURE: begin
                    ram_write_enable <= 1'b0;
                    done <= 1'b0;
                    if (enable) begin
                        y1 <= types::row_addr_t'(data_in);
                        state <= STATE_WIDTH_CAPTURE;
                    end
                end
                STATE_WIDTH_CAPTURE: begin
                    // Big endian capture of width.
                    ram_write_enable <= 1'b0;
                    done <= 1'b0;
                    if (enable) begin
                        width.bytes[LAST_COL_BYTE_INDEX - width_byte_counter] <= data_in;
                        if (width_byte_counter == LAST_COL_BYTE_INDEX) begin
                            state <= STATE_HEIGHT_CAPTURE;
                        end else begin
                            width_byte_counter <= width_byte_counter + 1;
                        end
                    end
                end
                STATE_HEIGHT_CAPTURE: begin
                    ram_write_enable <= 1'b0;
                    done <= 1'b0;
                    if (enable) begin
                        // Clamp width/height so the stream never writes out of bounds.
                        width <= types::col_addr_field_t'(calc::clamp_remaining_dimension(
                            types::uint_t'(x1), types::uint_t'(width), params::PIXEL_WIDTH
                        ));
                        height <= types::row_addr_count_t'(calc::clamp_remaining_dimension(
                            types::uint_t'(y1), types::uint_t'(data_in), params::PIXEL_HEIGHT
                        ));
                        state <= STATE_ROW_PRIMEMEMWRITE;
                    end
                end
                STATE_ROW_PRIMEMEMWRITE: begin
                    // First payload byte seeds row/col/pixel traversal.
                    done <= 1'b0;
                    if (enable) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        addr.row <= y1;
                        addr.col <= x1_addr;
                        addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                        state <= STATE_ROW_MEMWRITE;
                    end
                end
                STATE_ROW_MEMWRITE: begin
                    if (enable) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        done <= 1'b0;
                        // Walk pixels: decrement pixel index, then advance columns/rows.
                        if (addr.row < y2 || addr.col < x2 || addr.pixel != 'd0) begin
                            if (addr.pixel == 'd0) begin
                                addr.pixel <= types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);
                                if (addr.col == x2) begin
                                    addr.col <= x1_addr;
                                    addr.row <= addr.row + 'd1;
                                end else begin
                                    addr.col <= addr.col + 'd1;
                                end
                            end else begin
                                if (addr.row == y2 && addr.col == x2 && ((addr.pixel - 'd1) == 0)) begin
                                    done <= 1'b1;
                                end
                                addr.pixel <= addr.pixel - 'd1;
                            end
                        end else begin
                            state <= STATE_DONE;
                        end
                    end
                end
                STATE_DONE: begin
                    // Clear outputs/counters so the next command starts cleanly.
                    state <= STATE_X1_CAPTURE;
                    done <= 1'b0;
                    ram_write_enable <= 1'b0;
                    ram_access_start <= 1'b0;
                    data_out <= 8'b0;
                    addr.row <= 'b0;
                    addr.col <= 'b0;
                    addr.pixel <= 'b0;
                    x1 <= 'b0;
                    width <= 'b0;
                    y1 <= 'b0;
                    height <= 'b0;
                    x1_byte_counter <= 'b0;
                    width_byte_counter <= 'b0;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
