// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_watchdog #(
    parameter integer unsigned WATCHDOG_SIGNATURE_BITS = params::WATCHDOG_SIGNATURE_BITS,
    parameter logic [WATCHDOG_SIGNATURE_BITS-1:0] WATCHDOG_SIGNATURE_PATTERN = params::WATCHDOG_SIGNATURE_PATTERN,
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
    localparam integer unsigned WATCHDOG_SIGBYTES = $rtoi(WATCHDOG_SIGNATURE_BITS / 8);
    typedef enum {
        STATE_SIG_CAPTURE,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;
    logic [WATCHDOG_SIGNATURE_BITS-1:0] cache;
    logic [$clog2(WATCHDOG_CONTROL_TICKS)-1:0] watchdog_counter;
    logic [$clog2(WATCHDOG_SIGBYTES)-1:0] sig_byte_counter;

    always @(posedge clk) begin
        if (reset) begin
            cache <= {WATCHDOG_SIGNATURE_BITS{1'b0}};
            watchdog_counter <= ($clog2(WATCHDOG_CONTROL_TICKS))'(WATCHDOG_CONTROL_TICKS);
            sig_byte_counter <= ($clog2(WATCHDOG_SIGBYTES))'(WATCHDOG_SIGBYTES);
            state <= STATE_SIG_CAPTURE;
            done <= 1'b0;
            sys_reset <= 1'b0;
        end else begin
            sys_reset <= (watchdog_counter == 'd0);
            case (state)
                STATE_SIG_CAPTURE: begin
                    if (enable) begin
                        // Update memory
                        cache <= (cache << 8) + (WATCHDOG_SIGNATURE_BITS)'(data_in);
                        if (((cache << 8) + (WATCHDOG_SIGNATURE_BITS)'(data_in)) == WATCHDOG_SIGNATURE_PATTERN) begin
                            watchdog_counter <= ($clog2(WATCHDOG_CONTROL_TICKS))'(WATCHDOG_CONTROL_TICKS);
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
                    cache <= {WATCHDOG_SIGNATURE_BITS{1'b0}};
                    sig_byte_counter <= ($clog2(WATCHDOG_SIGBYTES))'(WATCHDOG_SIGBYTES);
                    watchdog_counter <= watchdog_counter - 'd1;
                end
                default: state <= state;
            endcase
        end
    end
endmodule
