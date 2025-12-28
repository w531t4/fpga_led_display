// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_fillpanel #(
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,
    input mem_clk,

    output logic [_NUM_ROW_ADDRESS_BITS-1:0] row,
    output logic [_NUM_COLUMN_ADDRESS_BITS-1:0] column,
    output logic [_NUM_PIXELCOLORSELECT_BITS-1:0] pixel,
    output logic [7:0] data_out,
    output logic ram_write_enable,
    output logic ram_access_start,
    output logic ready_for_data,
    output logic done
);
    typedef enum {
        STATE_COLOR_CAPTURE,
        STATE_START,
        STATE_RUNNING,
        STATE_PREDONE,
        STATE_DONE
    } ctrl_fsm;
    logic local_reset;
    ctrl_fsm state;
    logic subcmd_enable;
    wire cmd_blankpanel_done;
    logic [(params_pkg::BYTES_PER_PIXEL*8)-1:0] selected_color;
    logic [$clog2(params_pkg::BYTES_PER_PIXEL)-1:0] capturebytes_remaining;

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
            state <= STATE_COLOR_CAPTURE;
            done_inside <= 1'b0;
            capturebytes_remaining <= ($clog2(params_pkg::BYTES_PER_PIXEL))'(params_pkg::BYTES_PER_PIXEL - 1);
            ready_for_data <= 1'b1;
            selected_color <= {(params_pkg::BYTES_PER_PIXEL * 8) {1'b0}};
            local_reset <= 1'b0;
        end else begin
            case (state)
                STATE_COLOR_CAPTURE: begin
                    if (enable) begin
                        selected_color[(((32)'(capturebytes_remaining)+1)*8)-1-:8] <= data_in;
                        if (capturebytes_remaining == 0) begin
                            state <= STATE_START;
                            ready_for_data <= 1'b0;
                        end else begin
                            ready_for_data <= 1'b1;
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
                        subcmd_enable <= 1'b0;
                        local_reset <= 1'b1;
                    end
                end
                STATE_PREDONE: begin
                    done_inside <= 1'b1;
                    local_reset <= 1'b0;
                    state <= STATE_DONE;
                end
                STATE_DONE: begin
                    done_inside <= 1'b0;
                    local_reset <= 1'b0;
                    ready_for_data <= 1'b1;
                    state <= STATE_COLOR_CAPTURE;
                    capturebytes_remaining <= ($clog2(params_pkg::BYTES_PER_PIXEL))'(params_pkg::BYTES_PER_PIXEL - 1);
                    selected_color <= {(params_pkg::BYTES_PER_PIXEL * 8) {1'b0}};
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
