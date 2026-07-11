// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// READSTATUS: latch the addr argument byte and pulse status_latch_en so the
// reg_mailbox captures a fresh snapshot for the host to read.
module control_cmd_readstatus #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input clk,
    input enable,

    output types::status_addr_t data_out,
    output logic status_latch_en,
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
            status_latch_en <= 1'b0;
        end else begin
            case (state)
                STATE_READY: begin
                    if (enable) begin
                        done <= 1'b1;
                        status_latch_en <= 1'b1;
                        data_out <= data_in;
                        state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b0;
                    status_latch_en <= 1'b0;
                    // data_out stays latched; the mailbox samples it while
                    // status_latch_en is high.
                    state <= STATE_READY;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
