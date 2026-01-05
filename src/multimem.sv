// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

// multimem: A banked framebuffer RAM
//      - on ClockA, one byte written to single lane (subpanel + pixel‑color select) selected by AddressA
//      - on ClockB:
//          - AddressB reads that address from all lanes in parallel [2‑cycle read]
//          - Concatenates the data read from lanes into QB (via mem_lane)

`default_nettype none
module multimem #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire types::mem_write_data_t DataInA,
    input wire [15:0] DataInB,
    input wire types::mem_write_addr_t AddressA,
    input wire types::mem_read_addr_t AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output wire types::mem_write_data_t QA,
    output wire types::mem_read_data_t QB
);
    // consider
    // 8 bits addr a, 2 bits colorselect, 2 bits display
    //      addrA = 8
    //      colorselect = 2
    //      display = 2

    //      7 display          = (addrA - 1)
    //      6 display          = (addrA - display)
    //      5 body             = (addrA - display) -1           // aka addrb
    //      4 body             =                                // aka addrb
    //      3 body             =                                // aka addrb
    //      2 body             = (colorselect - 1) + 1          // aka addrb
    //      1 pixelcolorselect = colorselect - 1
    //      0 pixelcolorselect = 0
    //  [7:0] mem [displaybits,colorselectbits] [addr_b bits]

    localparam integer unsigned LANES = (1 << $bits(types::mem_structure_t));
    wire types::mem_read_data_t qb_lanes_w;

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_lane
            wire types::mem_structure_t lane_idx_from_addr = types::mem_structure(AddressA);

            wire we_lane_c = ClockEnA & WrA & (lane_idx_from_addr == types::mem_structure_t'(i));
            // TODO: Are these keeps still necessary?
            (* keep = "true" *) reg we_lane_q;
            // TODO - is it necessary to use a reg for types::mem_read_addr_t here
            (* keep = "true" *) types::mem_read_addr_t addra_q;
            (* keep = "true" *) types::mem_write_data_t dia_q;

            always @(posedge ClockA) begin
                we_lane_q <= we_lane_c;
                addra_q <= {AddressA.row, AddressA.col};
                dia_q <= DataInA;
            end

            mem_lane #(
                .ADDR_BITS($bits(types::mem_read_addr_t)),
                .DW($bits(types::mem_write_data_t))
            ) u_lane (
                .clka (ClockA),
                .ena  (1'b1),
                .wea  (we_lane_q),
                .addra(addra_q),
                .dia  (dia_q),
                .clkb (ClockB),
                .enb  (ClockEnB),
                .rstb (ResetA || ResetB),
                .addrb(AddressB),
                .dob  (qb_lanes_w.lane[i])
            );
        end
    endgenerate

    assign QB = qb_lanes_w;

    assign QA = 0;
    wire _unused_ok = &{1'b0, WrB, DataInB, 1'b0};
endmodule
