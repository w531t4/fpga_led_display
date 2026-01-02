// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_readbrightness #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    // verilator lint_off UNUSEDSIGNAL
    input [7:0] data_in,
    // verilator lint_on UNUSEDSIGNAL
    input clk,
    input enable,

    output types::brightness_level_t data_out,
    output logic brightness_change_en,
    output logic done
);
    typedef enum {
        STATE_READY,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    always @(posedge clk) begin
        if (reset) begin
            data_out <= 'b0;
            done <= 1'b0;
            state <= STATE_READY;
            brightness_change_en <= 1'b0;
        end else begin
            case (state)
                STATE_READY: begin
                    if (enable) begin
                        done <= 1'b1;
                        brightness_change_en <= 1'b1;
                        data_out <= data_in;
                        state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b0;
                    brightness_change_en <= 1'b0;
                    data_out <= 'b0;
                    state <= STATE_READY;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
