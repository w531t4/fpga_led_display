// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Snapshot mailbox: turns a register-read request into a stable, CRC-sealed
// reply frame, stamped with a sequence number for freshness detection.
// inputs: latch pulse + {addr, value}
// output: frame = {addr, seq, value, crc(addr||seq||value)}
// sizes live in params:: (STATUS_*_BYTES); shapes in types:: (status_*_t)
//
// Containerization (BODY = what the CRC covers; FRAME = what the wire carries):
//
//   |<------------------ FRAME (STATUS_FRAME_BYTES) ------------>|
//   |<-------- BODY (STATUS_BODY_BYTES) ----------->|
//   +--------+--------+-----------------------------+------------+
//   |  addr  |  seq   |            value            |    crc     |
//   +--------+--------+-----------------------------+------------+
//    sent 1st                                          sent last
//        \____________________ crc ____________________/^
//                  (computed over BODY,
//                   rides in the FRAME -- it cannot cover itself)
//
// Contract:
//   - pulse latch: addr/value are captured atomically on that edge;
//     two clk edges later the complete frame is on `frame`
//   - frame holds stable until the next latch (reads don't consume); a new
//     latch overwrites (last writer wins)
//   - seq counts accepted latches: +1 per latch (retries included), 8-bit,
//     wraps mod 256 THROUGH zero -- seq 0 is an ordinary live value
//   - host freshness rule: a reply is fresh iff its seq differs from the
//     last accepted frame's ("changed", not "+1": retries bump seq too)
//   - the never-latched sentinel is identified by addr==STATUS_ADDR_NONE (a
//     reserved address), NOT by seq; after reset: addr STATUS_ADDR_NONE,
//     seq 0, zero value (the CRC field converges one cycle after reset
//     releases)
//   - frame.addr is the first byte sent by a HIGH_INDEX_FIRST byte_feeder
//   - two-stage on purpose: the CRC tree stays a short reg->reg timing path
//     instead of reaching back into the value sources
module reg_mailbox #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input                        clk,
    input                        reset,
    input                        latch,
    input  types::status_addr_t  addr,
    input  types::status_value_t value,
    output types::status_reply_t frame
);
    types::status_seq_t seq_q;
    // The post-latch sequence number, typed by declaration (no literal widths).
    wire types::status_seq_t seq_next = seq_q + 1'b1;
    types::status_body_t body_q;
    wire types::status_crc_t body_crc;
    crc16 #(
        .DATA_BITS($bits(body_q))
    ) body_crc16 (
        .data_in(body_q),
        .crc_out(body_crc)
    );

    always @(posedge clk) begin
        if (reset) begin
            // Sentinel: reserved addr, all other fields zero (field assigns
            // after the clears; both NBAs apply in order).
            seq_q       <= '0;
            body_q      <= '0;
            body_q.addr <= types::STATUS_ADDR_NONE;
            frame       <= '0;
            frame.addr  <= types::STATUS_ADDR_NONE;
        end else begin
            if (latch) begin
                seq_q        <= seq_next;
                body_q.addr  <= addr;
                body_q.seq   <= seq_next;
                body_q.value <= value;
            end
            frame <= {body_q, body_crc};
        end
    end
endmodule
