// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// READSTATUS reply port (FPGA -> ESP32): reg_mailbox -> byte_feeder ->
// spi_slave (TX side enabled).
//
// Wire contract:
//   - request: READSTATUS on the main SPI bus pulses `latch` with {addr, value}
//   - reply: host clocks the frame out here; CS low, mode 3, MSB-first
//   - CS frames the transfer (slave rstb): byte 0 is the addr echo by
//     construction; every retry re-frames
//
// CDC (mailbox frame, clk_in -> sck, no synchronizer):
//   - handshake implemented in protocol: READSTATUS -> busy low -> read;
//     frame wires only move in the two clk_in cycles after a latch
//   - violation (or mid-read global reset) = torn frame; the CRC catches
//     all but ~2^-16, echo+seq narrow the rest, retry heals
//   - future: drop latches while cs_n is low (2-FF sync) to make tears
//     impossible; safe because a dropped latch leaves seq unchanged
module reg_spi_responder #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    // Mailbox load (clk_in domain)
    input                        clk_in,
    input                        reset,
    input                        latch,
    input  types::status_addr_t  addr_in,
    input  types::status_value_t value_in,
    // Host-clocked read port (sck domain)
    input                        sck,
    input                        cs_n,
    output                       miso
);
    // Mailbox (clk_in domain): latch -> stable, CRC-sealed frame two edges
    // later (see reg_mailbox.sv). `frame` is the CDC crossing (header note).
    wire types::status_reply_t frame;
    reg_mailbox mailbox (
        .clk  (clk_in),
        .reset(reset),
        .latch(latch),
        .addr (addr_in),
        .value(value_in),
        .frame(frame)
    );

    // Byte feeder (sck domain). Pairing made here:
    //   - HIGH_INDEX_FIRST matches the frame's packed layout (first-sent
    //     byte at the top index)
    //   - feeder advances on RISING sck edges; the mode-3 slave reloads on
    //     the following FALLING edge -- half a period for tdata to settle
    wire [7:0] tdata;
    byte_feeder #(
        .FRAME_BYTES(params::STATUS_FRAME_BYTES),
        .HIGH_INDEX_FIRST(1'b1)
    ) feeder (
        .clk     (sck),
        // CS high holds the feeder in reset -- same CS-only framing as rstb.
        .reset   (cs_n),
        .frame_in(frame),
        .data_out(tdata)
    );

    // Transport: spi_slave, TX enabled.
    //   - CS is deliberately the ONLY reset: global resets (watchdog) must
    //     not re-frame a transaction in flight
    wire       port_sdout;
    wire       port_done;
    wire [7:0] port_rdata;
    spi_slave port_slave (
        .rstb (~cs_n),
        .ten  (1'b1),
        .tdata(tdata),
        .mlb  (1'b1),        // shift msb first
        // ss tied selected: CS-high already holds rstb, making the internal
        // if(ss) branches redundant; keeps cs_n async-only (no sync sampling)
        .ss   (1'b0),
        .sck  (sck),
        .sdin (1'b0),        // no MOSI on this port
        .sdout(port_sdout),
        .done (port_done),
        .rdata(port_rdata)
    );
    // sdout tri-states while CS is high; resolve to idle-high push-pull.
    assign miso = cs_n ? 1'b1 : port_sdout;

    wire _unused_ok = &{1'b0, port_done, port_rdata, 1'b0};
endmodule
