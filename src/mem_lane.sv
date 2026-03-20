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
    input  wire                 clka,
    input  wire                 ena,
    input  wire                 wea,
    input  wire [ADDR_BITS-1:0] addra,
    input  wire [       DW-1:0] dia,
    output reg  [       DW-1:0] doa,

    input  wire                 clkb,
    input  wire                 enb,
    input  wire                 rstb,
    input  wire [ADDR_BITS-1:0] addrb,
    output reg  [       DW-1:0] dob
);
    localparam int DEPTH = (1 << ADDR_BITS);
    localparam integer unsigned PORT_A_LATENCY = 1;
    localparam integer unsigned PORT_B_LATENCY = 2;

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
    // NOTE: the OUTREG stage for Port A lives in multimem (qa_lane_q), not here.
    reg [PORT_A_LATENCY-1:0][DW-1:0] doa_pipe;
    always @(posedge clka) begin
        doa_pipe[0] <= mem[addra];
        for (int stage = 1; stage < PORT_A_LATENCY; stage++) doa_pipe[stage] <= doa_pipe[stage-1];
    end
    assign doa = doa_pipe[PORT_A_LATENCY-1];

    // Port B read: 2-cycle latency (sync read + explicit outreg stage)
    // Keep the output stage explicit so the ECP5 outreg plugin can pack it into DP16KD.
    // NOTE: enb is intentionally not used here; driving CEB/OCEB with a global
    // enable creates a long fanout path. Gate usage of dob downstream instead.
    reg [PORT_B_LATENCY-1:0][DW-1:0] dob_pipe;

    always @(posedge clkb) begin
        if (rstb) begin
            for (int stage = 0; stage < PORT_B_LATENCY; stage++) dob_pipe[stage] <= '0;
        end else begin
            dob_pipe[0] <= mem[addrb];
            for (int stage = 1; stage < PORT_B_LATENCY; stage++) dob_pipe[stage] <= dob_pipe[stage-1];
        end
    end
    assign dob = dob_pipe[PORT_B_LATENCY-1];

    // enb intentionally unused: keep CEB/OCEB constant to avoid long enable fanout.
    wire _unused_ok_enb = &{1'b0, enb, 1'b0};
endmodule
