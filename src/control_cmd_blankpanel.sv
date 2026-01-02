// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_blankpanel #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input enable,
    input clk,
    input mem_clk,

    output logic [calc::num_row_address_bits(PIXEL_HEIGHT)-1:0] row,
    output logic [calc::num_column_address_bits(PIXEL_WIDTH)-1:0] column,
    output logic [calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic done
);
    typedef enum {
        STATE_START,
        STATE_RUNNING,
        STATE_PREDONE,
        STATE_DONE
    } ctrl_fsm_t;
    logic local_reset;
    ctrl_fsm_t state;
    logic subcmd_enable;
    wire cmd_blankpanel_done;

    always @(posedge clk) begin
        if (reset) begin
            subcmd_enable <= 1'b0;
            state <= STATE_START;
            done <= 1'b0;
            local_reset <= 1'b0;
        end else begin
            case (state)
                STATE_START: begin
                    if (enable) begin
                        subcmd_enable <= 1'b1;
                        state <= STATE_RUNNING;
                    end
                end
                STATE_RUNNING: begin
                    if (enable) begin
                        if (cmd_blankpanel_done) begin
                            state <= STATE_PREDONE;
                            subcmd_enable <= 1'b0;
                        end
                    end
                end
                STATE_PREDONE: begin
                    if (enable) begin
                        done <= 1'b1;
                        local_reset <= 1'b1;
                        state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b0;
                    local_reset <= 1'b0;
                    state <= STATE_START;
                end
                default state <= state;
            endcase
        end
    end

    control_subcmd_fillarea #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        ._UNUSED('d0)
    ) subcmd_fillarea (
        .reset(reset || local_reset),
        .enable(subcmd_enable),
        .clk(mem_clk),
        .ack(done),
        .x1(0),
        .y1(0),
        .width((calc::num_column_address_bits(PIXEL_WIDTH))'(PIXEL_WIDTH)),
        .height((calc::num_row_address_bits(PIXEL_HEIGHT))'(PIXEL_HEIGHT)),
        .color({(BYTES_PER_PIXEL * 8) {1'b0}}),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(cmd_blankpanel_done)
    );

endmodule
