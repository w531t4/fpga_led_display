// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// mem_lane: Single‑lane dual‑clock byte RAM
//      - writes on clka when enabled
//      - on clka, writes dia when enabled
//      - on clka, outputs doa (used for copy‑engine reads)
//      - on clkb:
//          - outputs dob after two pipeline stages
//          - rstb forces dob to zero
//      - used as the per‑lane storage block in multimem
`default_nettype none (* keep_hierarchy = "yes" *)
module mem_lane #(
    parameter integer ADDR_BITS = 11,
    parameter integer DW        = 8
) (
    input wire                 clka,
    input wire                 ena,
    input wire                 wea,
    input wire [ADDR_BITS-1:0] addra,
    input wire [       DW-1:0] dia,
    output reg  [       DW-1:0] doa,

    input  wire                 clkb,
    input  wire                 enb,
    input  wire                 rstb,
    input  wire [ADDR_BITS-1:0] addrb,
    output reg  [       DW-1:0] dob
);
    localparam int DEPTH = (1 << ADDR_BITS);

    // Force BRAM, avoid hazard glue
    (* ram_style="block", no_rw_check *)
    reg [DW-1:0] mem[DEPTH];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    end
    // synthesis translate_on

    // Write port
    always @(posedge clka) begin
        if (ena && wea) mem[addra] <= dia;
    end

    // Port A read: registered output for copy engine.
    // Keep this unconditional to avoid routing a wide enable into every BRAM OCEA.
    always @(posedge clka) begin
        doa <= mem[addra];
    end

    // Port B read: 2-cycle latency (sync read + explicit outreg stage)
    // Keep the output stage explicit so the ECP5 outreg plugin can pack it into DP16KD.
    // NOTE: enb is intentionally not used here; driving CEB/OCEB with a global
    // enable creates a long fanout path. Gate usage of dob downstream instead.
    reg [DW-1:0] dob_q;
    always @(posedge clkb) begin
        if (rstb) dob_q <= '0;
        else dob_q <= mem[addrb];
    end
    // Let the output stage run every cycle so single-cycle enb pulses still return data.
    always @(posedge clkb) begin
        if (rstb) dob <= '0;
        else dob <= dob_q;
    end
    // enb intentionally unused: keep CEB/OCEB constant to avoid long enable fanout.
    wire _unused_ok_enb = &{1'b0, enb, 1'b0};
endmodule
