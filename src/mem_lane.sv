// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// mem_lane: Single‑lane dual‑clock byte RAM
//      - writes on clka when enabled
//      - on clka, writes dia when enabled
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

    // Read: 2-cycle latency (addr reg + BRAM outreg)
    reg [ADDR_BITS-1:0] addrb_q;
    always @(posedge clkb) addrb_q <= addrb;
    always @(posedge clkb) begin
        if (rstb) dob <= '0;
        else if (enb) dob <= mem[addrb_q];
    end
endmodule
