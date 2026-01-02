// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_fillrect #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,
    input mem_clk,

    output logic [calc::num_row_address_bits(PIXEL_HEIGHT)-1:0] row,
    output types::col_addr_t column,
    output logic [calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic ready_for_data,
    output logic done
);
    localparam integer unsigned _NUM_COLUMN_BYTES_NEEDED = calc::num_bytes_to_contain($bits(types::col_addr_t));
    localparam integer unsigned safe_bits_needed_for_column_byte_counter = calc::safe_bits(_NUM_COLUMN_BYTES_NEEDED);
    typedef enum {
        STATE_X1_CAPTURE,      // 0
        STATE_Y1_CAPTURE,      // 1
        STATE_WIDTH_CAPTURE,   // 2
        STATE_HEIGHT_CAPTURE,  // 3
        STATE_COLOR_CAPTURE,   // 4
        STATE_START,           // 5
        STATE_RUNNING,         // 6
        STATE_PREDONE,         // 7
        STATE_DONE             // 8
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    logic local_reset;
    // verilator lint_off UNUSEDSIGNAL
    logic [(_NUM_COLUMN_BYTES_NEEDED*8)-1:0] x1;
    logic [(_NUM_COLUMN_BYTES_NEEDED*8)-1:0] width;
    // verilator lint_on UNUSEDSIGNAL
    logic [safe_bits_needed_for_column_byte_counter-1:0] x1_byte_counter;
    logic [safe_bits_needed_for_column_byte_counter-1:0] width_byte_counter;
    logic [calc::num_row_address_bits(PIXEL_HEIGHT)-1:0] y1;
    logic [calc::num_row_address_bits(PIXEL_HEIGHT)-1:0] height;
    logic subcmd_enable;
    wire cmd_blankpanel_done;
    logic [(BYTES_PER_PIXEL*8)-1:0] selected_color;
    logic [$clog2(BYTES_PER_PIXEL)-1:0] capturebytes_remaining;


    logic done_inside, done_level;
    ff_sync #(
        .INIT_STATE(1'b0)
    ) done_sync (
        .clk(clk),
        .signal(done_inside),
        .reset(reset),
        .sync_level(done_level),
        .sync_pulse(done)
    );

    always @(posedge clk) begin
        if (reset) begin
            subcmd_enable <= 1'b0;
            state <= STATE_X1_CAPTURE;
            done_inside <= 1'b0;
            ready_for_data <= 1'b1;
            capturebytes_remaining <= ($clog2(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
            selected_color <= {(BYTES_PER_PIXEL * 8) {1'b0}};
            x1_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
            width_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
            x1 <= {(_NUM_COLUMN_BYTES_NEEDED * 8) {1'b0}};
            width <= {(_NUM_COLUMN_BYTES_NEEDED * 8) {1'b0}};
            y1 <= {calc::num_row_address_bits(PIXEL_HEIGHT) {1'b0}};
            height <= {calc::num_row_address_bits(PIXEL_HEIGHT) {1'b0}};
            local_reset <= 1'b0;
        end else begin
            case (state)
                STATE_X1_CAPTURE: begin
                    if (enable) begin
                        x1[((_NUM_COLUMN_BYTES_NEEDED-(32)'(x1_byte_counter))*8)-1-:8] <= data_in[7:0];
                        if (x1_byte_counter == 'b0) begin
                            state <= STATE_Y1_CAPTURE;
                        end else x1_byte_counter <= x1_byte_counter - 1;
                    end
                end
                STATE_Y1_CAPTURE: begin
                    if (enable) begin
                        y1 <= data_in[calc::num_row_address_bits(PIXEL_HEIGHT)-1:0];
                        state <= STATE_WIDTH_CAPTURE;
                    end
                end
                STATE_WIDTH_CAPTURE: begin
                    if (enable) begin
                        width[((_NUM_COLUMN_BYTES_NEEDED-(32)'(width_byte_counter))*8)-1-:8] <= data_in[7:0];
                        if (width_byte_counter == 'b0) begin
                            state <= STATE_HEIGHT_CAPTURE;
                        end else width_byte_counter <= width_byte_counter - 1;
                    end
                end
                STATE_HEIGHT_CAPTURE: begin
                    if (enable) begin
                        height <= data_in[calc::num_row_address_bits(PIXEL_HEIGHT)-1:0];
                        state  <= STATE_COLOR_CAPTURE;
                    end
                end
                STATE_COLOR_CAPTURE: begin
                    if (enable) begin
                        selected_color[(((32)'(capturebytes_remaining)+1)*8)-1-:8] <= data_in;
                        if (capturebytes_remaining == 0) begin
                            state <= STATE_START;
                            ready_for_data <= 1'b0;
                        end else begin
                            capturebytes_remaining <= capturebytes_remaining - 'd1;
                        end
                    end
                end
                STATE_START: begin
                    subcmd_enable <= 1'b1;
                    state <= STATE_RUNNING;
                end
                STATE_RUNNING: begin
                    if (cmd_blankpanel_done) begin
                        state <= STATE_PREDONE;
                        local_reset <= 1'b1;
                        subcmd_enable <= 1'b0;
                    end
                end
                STATE_PREDONE: begin
                    done_inside <= 1'b1;
                    local_reset <= 1'b0;
                    state <= STATE_DONE;
                end
                STATE_DONE: begin
                    done_inside <= 1'b0;
                    ready_for_data <= 1'b1;
                    state <= STATE_X1_CAPTURE;
                    x1_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
                    width_byte_counter <= (safe_bits_needed_for_column_byte_counter)'(_NUM_COLUMN_BYTES_NEEDED - 1);
                    capturebytes_remaining <= ($clog2(BYTES_PER_PIXEL))'(BYTES_PER_PIXEL - 1);
                    selected_color <= {(BYTES_PER_PIXEL * 8) {1'b0}};
                    x1 <= {(_NUM_COLUMN_BYTES_NEEDED * 8) {1'b0}};
                    width <= {(_NUM_COLUMN_BYTES_NEEDED * 8) {1'b0}};
                    y1 <= {calc::num_row_address_bits(PIXEL_HEIGHT) {1'b0}};
                    height <= {calc::num_row_address_bits(PIXEL_HEIGHT) {1'b0}};
                end
                default state <= state;
            endcase
        end
    end

    control_subcmd_fillarea #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        ._UNUSED('d0)
    ) subcmd_fillarea (
        .reset(reset || local_reset),
        .enable(subcmd_enable),
        .clk(mem_clk),
        .ack(done),
        .x1(types::col_addr_t'(x1)),
        .y1(y1),
        .width(types::col_addr_t'(width)),
        .height((calc::num_row_address_bits(PIXEL_HEIGHT))'(height)),
        .color(selected_color),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(cmd_blankpanel_done)
    );
    wire _unused_ok = &{1'b0, done_level, 1'b0};
endmodule
