// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Combinational CRC-16.
//
// Wire-format facts (an ESP32-side implementation must match all of these):
//   - polynomial 0x1021 (XMODEM), initial value 0, no reflection, no final XOR
//   - bit order (MSB-first)
//   - ESP32 ROM equivalent: crc == ~esp_rom_crc16_be(0xFFFF, buf, len)
//   - check value: the ASCII bytes of "123456789" produce 0x31C3
//   - because the initial value is 0, leading zero bits do not change the
//     result: zero-padded data produces the same CRC as unpadded data
module crc16 #(
    parameter integer unsigned DATA_BITS = 8,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED   = 0
    // verilator lint_on UNUSEDPARAM
) (
    input        [DATA_BITS-1:0] data_in,
    output logic [         15:0] crc_out
);
    // POLY holds the polynomial's low 16 terms (x^12 + x^5 + 1 = 0x1021). The
    // x^16 term is not stored: every degree-16 divisor has that bit set, so
    // it is left implicit.
    localparam logic [15:0] POLY = 16'h1021;

    // Polynomial long division, one message bit per iteration, high bits
    // first. Each iteration:
    //   - crc_out[15] is the bit about to shift off into the implicit x^16
    //     position; XORed with the incoming message bit it decides whether
    //     the divisor "goes into" the value at this position
    //   - if it does, subtract the divisor -- in GF(2), subtraction is XOR
    //     with POLY after the shift
    always_comb begin
        crc_out = '0;
        for (int i = DATA_BITS - 1; i >= 0; i = i - 1) begin
            if (crc_out[15] ^ data_in[i]) crc_out = {crc_out[14:0], 1'b0} ^ POLY;
            else crc_out = {crc_out[14:0], 1'b0};
        end
    end
endmodule
