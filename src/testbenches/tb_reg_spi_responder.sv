// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// Self-checking testbench for reg_spi_responder.
//
// Reads frames over the mode-3 port (CRC anchoring lives in tb_crc) and
// checks: bit-exact {addr, data, crc} readout, the 0xFF never-requested
// sentinel after reset, re-read stability without a new latch, frame update
// between transactions, 1-padding when over-clocked, and MISO idling high
// while CS is deasserted.
module tb_reg_spi_responder #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    // Sizes single-sourced from params:: / shapes from types::.
    localparam integer unsigned DATA_BITS = 8 * params::STATUS_VALUE_BYTES;
    localparam integer unsigned BODY_BITS = 8 * params::STATUS_BODY_BYTES;
    localparam integer unsigned FRAME_BITS = 8 * params::STATUS_FRAME_BYTES;
    // Width-agnostic test values for the value field.
    localparam logic [DATA_BITS-1:0] TEST_VALUE_A = 'h12;
    localparam logic [DATA_BITS-1:0] TEST_VALUE_B = 'hBE;
    localparam real SCK_HALF_NS = params::SIM_HALF_PERIOD_NS * 3.0;

    logic clk;
    logic reset;
    logic latch;
    logic [7:0] addr_in;
    logic [DATA_BITS-1:0] data_in;
    logic sck;
    logic cs_n;
    wire miso;

    reg_spi_responder dut (
        .clk_in  (clk),
        .reset   (reset),
        .latch   (latch),
        .addr_in (addr_in),
        .value_in(data_in),
        .sck     (sck),
        .cs_n    (cs_n),
        .miso    (miso)
    );

    // Reference CRC-16/XMODEM (poly 0x1021, init 0, MSB-first) over the body;
    // restated independently of crc16.sv on purpose.
    localparam types::status_crc_t REF_POLY = 'h1021;
    function automatic types::status_crc_t crc_ref(input logic [BODY_BITS-1:0] d);
        types::status_crc_t c;
        c = '0;
        for (int i = BODY_BITS - 1; i >= 0; i = i - 1) begin
            if (c[$bits(c)-1] ^ d[i]) c = {c[$bits(c)-2:0], 1'b0} ^ REF_POLY;
            else c = {c[$bits(c)-2:0], 1'b0};
        end
        return c;
    endfunction

    // Clock a burst of `nbits` off the port (mode 3: slave shifts on negedge,
    // sampled during the low phase) into `captured`, MSB-first.
    task automatic read_bits(input int unsigned nbits, output logic [FRAME_BITS+7:0] captured);
        captured = '0;
        for (int unsigned i = 0; i < nbits; i = i + 1) begin
            sck = 1'b0;
            #(SCK_HALF_NS);
            captured = {captured[FRAME_BITS+6:0], miso};
            sck = 1'b1;
            #(SCK_HALF_NS);
        end
    endtask

    // Latch a new mailbox value (clk domain).
    task automatic do_latch(input logic [7:0] addr, input logic [DATA_BITS-1:0] data);
        @(posedge clk);
        #1;
        addr_in = addr;
        data_in = data;
        latch   = 1'b1;
        @(posedge clk);
        #1;
        latch = 1'b0;
        @(posedge clk);
    endtask

    function automatic logic [FRAME_BITS-1:0] expected_frame(input logic [7:0] addr, input logic [7:0] seq,
                                                             input logic [DATA_BITS-1:0] data);
        return {addr, seq, data, crc_ref({addr, seq, data})};
    endfunction

    logic [FRAME_BITS+7:0] cap;

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_reg_spi_responder);
        clk = 0;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    initial begin
        reset   = 1;
        latch   = 0;
        addr_in = '0;
        data_in = '0;
        sck     = 1;  // mode 3: idle high
        cs_n    = 1;
        repeat (4) @(posedge clk);
        reset = 0;
        repeat (2) @(posedge clk);

        // MISO idles high while CS is deasserted.
        if (miso !== 1'b1) $fatal(1, "miso should idle high with cs_n deasserted");

        // 1) Reset state: addr sentinel 0xFF, zero data, valid CRC.
        cs_n = 1'b0;
        #(SCK_HALF_NS);
        read_bits(FRAME_BITS, cap);
        cs_n = 1'b1;
        #(SCK_HALF_NS);
        if (cap[FRAME_BITS-1:0] !== expected_frame(8'hFF, 8'h00, '0))
            $fatal(
                1,
                "reset frame mismatch: got %08x, expected %08x",
                cap[FRAME_BITS-1:0],
                expected_frame(
                    8'hFF, 8'h00, '0
                )
            );

        // 2) Latched frame reads back bit-exact, over-clocked tail pads 1s.
        do_latch(8'h3C, TEST_VALUE_A);
        cs_n = 1'b0;
        #(SCK_HALF_NS);
        read_bits(FRAME_BITS + 8, cap);
        cs_n = 1'b1;
        #(SCK_HALF_NS);
        if (cap[FRAME_BITS+7:8] !== expected_frame(8'h3C, 8'h01, TEST_VALUE_A))
            $fatal(
                1,
                "latched frame mismatch: got %08x, expected %08x",
                cap[FRAME_BITS+7:8],
                expected_frame(
                    8'h3C, 8'h01, TEST_VALUE_A
                )
            );
        if (cap[7:0] !== 8'hFF) $fatal(1, "over-clocked tail should pad 1s, got %02x", cap[7:0]);

        // 3) Re-read without a new latch returns the same frame.
        cs_n = 1'b0;
        #(SCK_HALF_NS);
        read_bits(FRAME_BITS, cap);
        cs_n = 1'b1;
        #(SCK_HALF_NS);
        if (cap[FRAME_BITS-1:0] !== expected_frame(8'h3C, 8'h01, TEST_VALUE_A))
            $fatal(1, "re-read frame mismatch: got %08x", cap[FRAME_BITS-1:0]);
        if (miso !== 1'b1) $fatal(1, "miso should return to idle high after CS deasserts");

        // 4) A new latch between transactions updates the frame.
        do_latch(8'hA7, TEST_VALUE_B);
        cs_n = 1'b0;
        #(SCK_HALF_NS);
        read_bits(FRAME_BITS, cap);
        cs_n = 1'b1;
        #(SCK_HALF_NS);
        if (cap[FRAME_BITS-1:0] !== expected_frame(8'hA7, 8'h02, TEST_VALUE_B))
            $fatal(
                1,
                "updated frame mismatch: got %08x, expected %08x",
                cap[FRAME_BITS-1:0],
                expected_frame(
                    8'hA7, 8'h02, TEST_VALUE_B
                )
            );

        $display("tb_reg_spi_responder: PASS");
        $finish;
    end

    initial begin
        #500000 $fatal(1, "tb_reg_spi_responder: timeout");
    end

endmodule
