// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
(* keep_hierarchy = "yes" *)
module mem_lane #(
    parameter integer ADDR_BITS = 11,
    parameter integer DW        = 8
)(
    input  wire                  clka,
    input  wire                  ena,
    input  wire                  wea,
    input  wire [ADDR_BITS-1:0]  addra,
    input  wire [DW-1:0]         dia,

    input  wire                  clkb,
    input  wire                  enb,
    input  wire                  rstb,
    input  wire [ADDR_BITS-1:0]  addrb,
    output reg  [DW-1:0]         dob
);
    // Force BRAM, avoid hazard glue
    (* ram_style="block", no_rw_check *)
    reg [DW-1:0] mem [0:(1<<ADDR_BITS)-1];

    // synthesis translate_off
    initial begin
        for (int i = 0; i < (1<<ADDR_BITS); i++)
            mem[i] = '0;
    end
    // synthesis translate_on

    // Write port
    always @(posedge clka) begin
        if (ena && wea)
            mem[addra] <= dia;
    end

    // Read: 2-cycle latency (addr reg + BRAM outreg)
    reg [ADDR_BITS-1:0] addrb_q;
    always @(posedge clkb) addrb_q <= addrb;
    always @(posedge clkb) begin
        if (rstb)
            dob <= '0;
        else if (enb)
            dob <= mem[addrb_q];
    end
endmodule
