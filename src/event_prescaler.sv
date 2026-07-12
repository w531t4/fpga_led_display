// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Event prescaler: emits one output pulse per DIVISOR input pulses.
//
// Contract:
//   - pulse_out is a one-clk pulse, coincident with the DIVISOR-th input
//   - the remainder carries across pulses (a modulo counter, never reset by
//     output), so the long-run output count is exactly floor(inputs/DIVISOR)
//   - reset zeroes the remainder
module event_prescaler #(
    parameter integer unsigned DIVISOR = 1,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input        clk,
    input        reset,
    input        pulse_in,
    output logic pulse_out
);
    // Inputs seen since the last output, 0..DIVISOR-1.
    typedef logic [calc::safe_clog2(DIVISOR)-1:0] remainder_t;
    localparam remainder_t REMAINDER_LAST = remainder_t'(DIVISOR - 1);

    remainder_t remainder;

    always @(posedge clk) begin
        if (reset) begin
            remainder <= '0;
            pulse_out <= 1'b0;
        end else begin
            pulse_out <= 1'b0;
            if (pulse_in) begin
                if (remainder == REMAINDER_LAST) begin
                    remainder <= '0;
                    pulse_out <= 1'b1;
                end else begin
                    remainder <= remainder + 1'b1;
                end
            end
        end
    end
endmodule
