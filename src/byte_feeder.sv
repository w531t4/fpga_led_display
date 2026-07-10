// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Serves a fixed frame to a byte-oriented consumer, one byte at a time.
// inputs: frame as bytes; HIGH_INDEX_FIRST selects the send order
// output: bytes across clk edges
//
// Contract:
//   - HIGH_INDEX_FIRST=1: frame_in[FRAME_BYTES-1] is sent first (matches a
//     packed {first, .., last} concat); =0: frame_in[0] is sent first
//   - while reset is high the counters are held at zero, so the first byte
//     is already presented when reset releases, before any clk edge
//   - data_out advances at each 8th rising clk edge; a consumer that samples
//     between rising edges always sees a settled byte
//   - past the last frame byte data_out holds 8'hFF (idle fill if the
//     consumer keeps clocking); reset returning high re-frames
module byte_feeder #(
    parameter integer unsigned FRAME_BYTES = 1,
    parameter bit HIGH_INDEX_FIRST = 1'b1,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                               clk,
    input                               reset,
    input        [FRAME_BYTES-1:0][7:0] frame_in,
    output logic [                 7:0] data_out
);
    // Counts completed bytes, 0..FRAME_BYTES inclusive (the +1 in the width:
    // it must hold the final count, not just the last index).
    typedef logic [$clog2(FRAME_BYTES+1)-1:0] byte_count_t;
    // Saturation point: all frame bytes served -> the 0xFF-pad region.
    localparam byte_count_t BYTE_COUNT_MAX = byte_count_t'(FRAME_BYTES);

    // Indexes frame bytes, 0..FRAME_BYTES-1 (safe_clog2: a single-byte frame
    // still gets a one-bit index type).
    typedef logic [calc::safe_clog2(FRAME_BYTES)-1:0] byte_index_t;
    localparam byte_index_t BYTE_INDEX_LAST = byte_index_t'(FRAME_BYTES - 1);

    logic [2:0] bit_in_byte;
    byte_count_t byte_count;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bit_in_byte <= '0;
            byte_count  <= '0;
        end else begin
            bit_in_byte <= bit_in_byte + 1'b1;  // wraps 7 -> 0
            if (bit_in_byte == 3'd7 && byte_count != BYTE_COUNT_MAX) begin
                byte_count <= byte_count + 1'b1;
            end
        end
    end

    // Send-order index derived from the count. Only consumed while
    // byte_count < FRAME_BYTES (the saturated case serves the pad byte), so
    // the count->index narrowing is value-safe.
    byte_index_t send_index;
    always_comb begin
        send_index = byte_index_t'(byte_count);
        if (HIGH_INDEX_FIRST) send_index = BYTE_INDEX_LAST - send_index;
    end

    // After k completed bytes, the k-th byte in send order is served.
    always_comb begin
        if (byte_count == BYTE_COUNT_MAX) begin
            data_out = 8'hFF;
        end else begin
            data_out = frame_in[send_index];
        end
    end
endmodule
