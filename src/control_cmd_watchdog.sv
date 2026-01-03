// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_watchdog #(
    parameter types::watchdog_pattern_t WATCHDOG_SIGNATURE_PATTERN = params::WATCHDOG_SIGNATURE_PATTERN,
    parameter int unsigned WATCHDOG_CONTROL_TICKS = params::WATCHDOG_CONTROL_TICKS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // input cmd_enable,
    input reset,
    input [7:0] data_in,
    input enable,
    input clk,

    output logic sys_reset,
    output logic done
);
    typedef enum {
        STATE_SIG_CAPTURE,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    types::watchdog_pattern_t cache;
    typedef logic [$clog2(WATCHDOG_CONTROL_TICKS)-1:0] watchdog_tick_index_t;
    watchdog_tick_index_t watchdog_counter;
    typedef logic [$clog2(params::WATCHDOG_SIGBYTES)-1:0] watchdog_sigbyte_index_t;
    watchdog_sigbyte_index_t sig_byte_counter;

    always @(posedge clk) begin
        if (reset) begin
            cache <= 'b0;
            watchdog_counter <= watchdog_tick_index_t'(WATCHDOG_CONTROL_TICKS);
            sig_byte_counter <= watchdog_sigbyte_index_t'(params::WATCHDOG_SIGBYTES);
            state <= STATE_SIG_CAPTURE;
            done <= 1'b0;
            sys_reset <= 1'b0;
        end else begin
            sys_reset <= (watchdog_counter == 'd0);
            case (state)
                STATE_SIG_CAPTURE: begin
                    if (enable) begin
                        // Update memory
                        cache <= (cache << 8) + types::watchdog_pattern_t'(data_in);
                        if (((cache << 8) + types::watchdog_pattern_t'(data_in)) == WATCHDOG_SIGNATURE_PATTERN) begin
                            watchdog_counter <= watchdog_tick_index_t'(WATCHDOG_CONTROL_TICKS);
                        end else begin
                            watchdog_counter <= watchdog_counter - 'd1;
                        end

                        if ((sig_byte_counter - 'd1) == 'd0) begin
                            state <= STATE_DONE;
                            done  <= 1'b1;
                        end else begin
                            sig_byte_counter <= sig_byte_counter - 'd1;
                        end
                    end else begin
                        watchdog_counter <= watchdog_counter - 'd1;
                    end
                end
                STATE_DONE: begin
                    state <= STATE_SIG_CAPTURE;
                    done <= 1'b0;
                    cache <= 'b0;
                    sig_byte_counter <= watchdog_sigbyte_index_t'(params::WATCHDOG_SIGBYTES);
                    watchdog_counter <= watchdog_counter - 'd1;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
