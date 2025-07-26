`default_nettype none
module control_cmd_readpixel #(
    `include "params.vh"
    `include "memory_calcs.vh"
    localparam _NUM_COLUMN_ADDRESS_BITS = $clog2(PIXEL_WIDTH),
    localparam _NUM_COLUMN_BYTES_NEEDED = ((_NUM_COLUMN_ADDRESS_BITS + 8 - 1) / 8),
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input clk_n,
    input enable,

    output logic [$clog2(PIXEL_HEIGHT)-1:0] row,
    output [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    localparam safe_bits_needed_for_column_byte_counter = _NUM_COLUMN_BYTES_NEEDED > 1 ? $clog2(_NUM_COLUMN_BYTES_NEEDED) : 1;
    typedef enum {STATE_ROW_CAPTURE,
                  STATE_COLUMN_CAPTURE,
                  STATE_PRIME_MEMWRITE,
                  STATE_READ_PIXELBYTES
                  } ctrl_fsm;
    ctrl_fsm state;
    logic [(_NUM_COLUMN_BYTES_NEEDED*8)-1:0] column_bits;
    logic [safe_bits_needed_for_column_byte_counter-1:0] column_byte_counter;

    assign column = column_bits[_NUM_COLUMN_ADDRESS_BITS-1:0];

    always @(negedge clk_n, posedge reset) begin
        if (reset) begin
            data_out <= 8'd0;
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;
            state <= STATE_ROW_CAPTURE;
            row <= {$clog2(PIXEL_HEIGHT){1'b0}};
            pixel <= {_NUM_PIXELCOLORSELECT_BITS{1'b0}};
            done <= 1'b0;
            column_byte_counter <= {safe_bits_needed_for_column_byte_counter{1'b0}};
            column_bits <= {(_NUM_COLUMN_BYTES_NEEDED*8){1'b0}};
        end
        else begin
            case (state)
                STATE_ROW_CAPTURE: begin
                    if (enable) begin
                        ram_write_enable <= 1'b0;
                        done <= 1'b0;
                        column_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
                        state <= STATE_COLUMN_CAPTURE;
                        row[$clog2(PIXEL_HEIGHT)-1:0] <= data_in[4:0];
                    end
                end
                STATE_COLUMN_CAPTURE: begin
                    if (enable) begin
                        // load (potentially multibyte) column number
                        //   - if multibyte, expect little endian (LSB -> MSB)
                        column_bits[((_NUM_COLUMN_BYTES_NEEDED-(32)'(column_byte_counter))*8)-1 -: 8] <= data_in[7:0];
                        if (column_byte_counter == 'b0) begin
                            state <= STATE_PRIME_MEMWRITE;
                        end else column_byte_counter <= column_byte_counter - 1;
                    end
                end
                STATE_PRIME_MEMWRITE: begin
                    if (enable) begin
                        state <= STATE_READ_PIXELBYTES;
                        ram_write_enable <= 1'b1;
                        ram_access_start <= !ram_access_start;
                        pixel <= ($clog2(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
                    end
                end
                STATE_READ_PIXELBYTES: begin
                    if (enable) begin
                        /* decrement the column address (or finish the load) */
                        /* store this byte */
                        data_out <= data_in;
                        ram_access_start <= !ram_access_start;
                        if (pixel == 'b0) begin
                            state <= STATE_ROW_CAPTURE;
                            done <= 1'b0;
                            data_out <= 8'b0;
                            ram_write_enable <= 1'b0;
                            ram_access_start <= 1'b0;
                            row <= 'd0;
                            column_bits <= 'd0;
                        end else begin
                            if ((pixel - 'd1) == 0) done <= 1'b1;
                            pixel <= pixel - 1;
                        end
                    end
                end
                default: state <= state;
            endcase
        end
    end
    wire _unused_ok = &{1'b0,
                        column_bits[(_NUM_COLUMN_BYTES_NEEDED*8)-1:_NUM_COLUMN_ADDRESS_BITS],
                        1'b0};
endmodule
