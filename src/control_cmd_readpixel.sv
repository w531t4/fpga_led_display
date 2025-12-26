// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readpixel #(
    `include "params.vh"
    `include "memory_calcs.vh"
    localparam _NUM_COLUMN_BYTES_NEEDED = ((_NUM_COLUMN_ADDRESS_BITS + 8 - 1) / 8),
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input clk,
    input enable,

    output logic [_NUM_ROW_ADDRESS_BITS-1:0] row,
    output [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    localparam safe_bits_needed_for_column_byte_counter = _NUM_COLUMN_BYTES_NEEDED > 1 ? $clog2(
        _NUM_COLUMN_BYTES_NEEDED
    ) : 1;
    typedef enum {
        STATE_ROW_CAPTURE,
        STATE_COLUMN_CAPTURE,
        STATE_READ_PIXELBYTES,
        STATE_DONE
    } ctrl_fsm;
    ctrl_fsm state;
    logic [(_NUM_COLUMN_BYTES_NEEDED*8)-1:0] column_bits;
    logic [safe_bits_needed_for_column_byte_counter-1:0] column_byte_counter;

    assign column = column_bits[_NUM_COLUMN_ADDRESS_BITS-1:0];

    always @(posedge clk) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_CAPTURE;
            row <= {_NUM_ROW_ADDRESS_BITS{1'b0}};
            pixel <= {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
            done <= 1'b0;
            column_byte_counter <= {safe_bits_needed_for_column_byte_counter{1'b0}};
            column_bits <= {(_NUM_COLUMN_BYTES_NEEDED * 8) {1'b0}};
        end else begin
            case (state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        ram_write_enable <= 1'b0;
                        done <= 1'b0;
                        column_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
                        state <= STATE_COLUMN_CAPTURE;
                        row[_NUM_ROW_ADDRESS_BITS-1:0] <= data_in[4:0];
                    end
                end
                STATE_COLUMN_CAPTURE: begin
                    if (enable) begin
                        // load (potentially multibyte) column number
                        //   - if multibyte, expect little endian (LSB -> MSB)
                        column_bits[((_NUM_COLUMN_BYTES_NEEDED-(32)'(column_byte_counter))*8)-1-:8] <= data_in[7:0];
                        if (column_byte_counter == 'b0) begin
                            state <= STATE_READ_PIXELBYTES;
                            ram_write_enable <= 1'b1;
                            ram_access_start <= !ram_access_start;
                            data_out <= data_in;
                            pixel <= ($clog2(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
                        end else column_byte_counter <= column_byte_counter - 1;
                    end
                end
                STATE_READ_PIXELBYTES: begin
                    if (enable) begin
                        /* decrement the column address (or finish the load) */
                        /* store this byte */
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        if (pixel != 'b0) begin
                            if ((pixel - 'd1) == 0) begin
                                done  <= 1'b1;
                                state <= STATE_DONE;
                            end
                            pixel <= pixel - 1;
                        end
                    end
                end
                STATE_DONE: begin
                    state <= STATE_ROW_CAPTURE;
                    done <= 1'b0;
                    data_out <= 8'b0;
                    ram_write_enable <= 1'b0;
                    ram_access_start <= 1'b0;
                    row <= 'd0;
                    column_bits <= 'd0;
                end
                default: state <= state;
            endcase
        end
    end
    wire _unused_ok = &{1'b0,
    // TODO: This breaks if width=256
    column_bits[(_NUM_COLUMN_BYTES_NEEDED*8)-1:_NUM_COLUMN_ADDRESS_BITS], 1'b0};
endmodule
