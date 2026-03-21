// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// mem_subpanel: Dual-clock RAM storing one subpanel's color payload per address.
//  - Port A writes a single byte slot within that payload.
//  - Port A / Port B both keep the same 2-cycle read shape used elsewhere.
//  - The RAM stores only the real pixel bytes; multimem reintroduces any
//    padded byte slots when it rebuilds QB.
//  - Each byte slot is stored in its own byte-wide memory. This keeps the
//    subpanel-word interface in multimem without synthesizing a BRAM-side
//    read-modify-write or a wide byte-select mux on DIA.
`default_nettype none (* keep_hierarchy = "yes" *)
module mem_subpanel #(
    parameter integer ADDR_BITS = 11,
    parameter integer WORD_W = 32,
    parameter integer BYTE_SEL_BITS = 2
) (
    input  wire                     clka,
    input  wire                     ena,
    input  wire                     wea,
    input  wire                     rsta,
    input  wire [ADDR_BITS-1:0]     addra,
    input  wire [BYTE_SEL_BITS-1:0] bytea,
    input  wire [7:0]               dia,
    output wire [WORD_W-1:0]        doa,

    input  wire                 clkb,
    input  wire                 enb,
    input  wire                 rstb,
    input  wire [ADDR_BITS-1:0] addrb,
    output wire [WORD_W-1:0]    dob
);
    localparam int DEPTH = (1 << ADDR_BITS);
    localparam integer unsigned PORT_A_LATENCY = 2;
    localparam integer unsigned PORT_B_LATENCY = 2;
    localparam integer unsigned WORD_BYTES = WORD_W / 8;

    genvar slot;
    generate
        for (slot = 0; slot < WORD_BYTES; slot = slot + 1) begin : g_byte
            localparam logic [BYTE_SEL_BITS-1:0] BYTE_SEL = BYTE_SEL_BITS'(slot);
            (* ram_style="block", no_rw_check *)
            reg [7:0] mem[DEPTH];
            reg [PORT_A_LATENCY-1:0][7:0] doa_pipe;
            reg [PORT_B_LATENCY-1:0][7:0] dob_pipe;

            // synthesis translate_off
            initial begin
                for (int i = 0; i < DEPTH; i++) mem[i] = '0;
            end
            // synthesis translate_on

            always @(posedge clka) begin
                if (rsta) begin
                    for (int stage = 0; stage < PORT_A_LATENCY; stage++) doa_pipe[stage] <= '0;
                end else if (ena) begin
                    if (wea && (bytea == BYTE_SEL)) mem[addra] <= dia;
                    doa_pipe[0] <= (wea && (bytea == BYTE_SEL)) ? dia : mem[addra];
                    for (int stage = 1; stage < PORT_A_LATENCY; stage++) doa_pipe[stage] <= doa_pipe[stage-1];
                end
            end

            always @(posedge clkb) begin
                if (rstb) begin
                    for (int stage = 0; stage < PORT_B_LATENCY; stage++) dob_pipe[stage] <= '0;
                end else begin
                    dob_pipe[0] <= mem[addrb];
                    for (int stage = 1; stage < PORT_B_LATENCY; stage++) dob_pipe[stage] <= dob_pipe[stage-1];
                end
            end

            assign doa[slot*8 +: 8] = doa_pipe[PORT_A_LATENCY-1];
            assign dob[slot*8 +: 8] = dob_pipe[PORT_B_LATENCY-1];
        end
    endgenerate

    // enb intentionally unused: keep Port B read unconditional like mem_lane.
    wire _unused_ok_enb = &{1'b0, enb, 1'b0};
endmodule
