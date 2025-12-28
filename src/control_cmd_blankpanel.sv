// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_blankpanel #(
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input enable,
    input clk,
    input mem_clk,

    output logic [_NUM_ROW_ADDRESS_BITS-1:0] row,
    output logic [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
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
    } ctrl_fsm;
    logic local_reset;
    ctrl_fsm state;
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

    control_subcmd_fillarea subcmd_fillarea (
        .reset(reset || local_reset),
        .enable(subcmd_enable),
        .clk(mem_clk),
        .ack(done),
        .x1(0),
        .y1(0),
        .width((_NUM_COLUMN_ADDRESS_BITS)'(params_pkg::PIXEL_WIDTH)),
        .height((_NUM_ROW_ADDRESS_BITS)'(params_pkg::PIXEL_HEIGHT)),
        .color({(params_pkg::BYTES_PER_PIXEL * 8) {1'b0}}),
        .row(row),
        .column(column),
        .pixel(pixel),
        .data_out(data_out),
        .ram_write_enable(ram_write_enable),
        .ram_access_start(ram_access_start),
        .done(cmd_blankpanel_done)
    );

endmodule
