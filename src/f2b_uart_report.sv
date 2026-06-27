// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// =============================================================================
// f2b_uart_report -- dead-simple plain-ASCII UART reporter for F2.b bring-up.
//
// Emits a repeating line "RC=0xHH\r\n" where HH is the HEX count of drawColumn
// (READCOL) commands the FPGA's control_module has actually decoded. Read it with
// any serial terminal -- `cat /dev/ttyUSB0`, `screen ... 115200` -- no client
// decoder, no struct, NOT the debugger module/uart_rx.py path. It reuses only the
// generic uart_tx byte-serializer primitive.
//
// (Hex, not decimal, on purpose: decimal needs a /100,/10 divider which lands a
// long carry chain on clk_root and drops Fmax below 50MHz. Hex is just nibble->
// ASCII -- a couple LUTs, off the critical path.)
//
// The one decisive F2.b measurement: the magenta bar streams 48 (=0x30) drawColumn
// commands; if this prints RC=0x30 the FPGA received them all (so the loss is
// inside the chip's write/display path), and if it prints fewer (e.g. 0x2B=43) the
// host/transport dropped the tail -- exactly the right-edge symptom.
// =============================================================================
module f2b_uart_report #(
    parameter integer unsigned UART_TICKS_PER_BIT = 191,
    // idle gap between lines (clk cycles); default ~0.2s @ 50MHz -> ~5 lines/sec
    parameter integer unsigned GAP_TICKS = 32'd10_000_000
) (
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] rc_count,   // READCOL (drawColumn) commands decoded
    output wire       tx
);
    localparam logic [27:0] GAP_MAX = 28'(GAP_TICKS - 1);

    // nibble -> ASCII hex (no divider, no carry chain)
    function automatic logic [7:0] hexd(input logic [3:0] n);
        hexd = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h41 + {4'd0, n} - 8'd10);
    endfunction

    // ---- snapshot of the count + message template "RC=0xHH\n" = 8 bytes ----
    // (LF only, no CR: many serial terminals translate CR to a newline of their
    // own, so a CRLF shows up as a double-spaced blank line between each report.)
    logic [7:0] rc_latch;
    logic [3:0] idx;
    logic [7:0] data;
    always_comb begin
        case (idx)
            4'd0:    data = "R";
            4'd1:    data = "C";
            4'd2:    data = "=";
            4'd3:    data = "0";
            4'd4:    data = "x";
            4'd5:    data = hexd(rc_latch[7:4]);
            4'd6:    data = hexd(rc_latch[3:0]);
            default: data = 8'h0A;             // \n  (idx 7)
        endcase
    end

    // ---- byte-at-a-time sender driving the uart_tx primitive ----
    typedef enum logic [1:0] {S_IDLE, S_LOAD, S_WAIT, S_GAP} state_e;
    state_e      state;
    logic        start;
    logic [27:0] gap;
    wire         tx_busy, tx_done;

    always @(posedge clk) begin
        if (reset) begin
            state    <= S_IDLE;
            idx      <= 4'd0;
            gap      <= 28'd0;
            start    <= 1'b0;
            rc_latch <= 8'd0;
        end else begin
            start <= 1'b0;  // default: start is a 1-cycle pulse
            case (state)
                S_IDLE: begin
                    rc_latch <= rc_count;   // snapshot so the line is consistent
                    idx      <= 4'd0;
                    state    <= S_LOAD;
                end
                S_LOAD: begin
                    if (!tx_busy) begin
                        start <= 1'b1;       // kick uart_tx with data[idx]
                        state <= S_WAIT;
                    end
                end
                S_WAIT: begin
                    if (tx_done) begin
                        if (idx == 4'd7) begin
                            gap   <= 28'd0;
                            state <= S_GAP;
                        end else begin
                            idx   <= idx + 4'd1;
                            state <= S_LOAD;
                        end
                    end
                end
                S_GAP: begin
                    if (gap == GAP_MAX) state <= S_IDLE;
                    else                gap   <= gap + 28'd1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    uart_tx #(
        .TICKS_PER_BIT(UART_TICKS_PER_BIT)
    ) u_tx (
        .i_clk  (clk),
        .i_start(start),
        .i_data (data),
        .o_done (tx_done),
        .o_busy (tx_busy),
        .o_dout (tx)
    );
endmodule
