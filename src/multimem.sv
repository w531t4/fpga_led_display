// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

// multimem: A banked framebuffer RAM
//      - on ClockA, one byte written to single lane (subpanel + pixel‑color select) selected by AddressA
//      - on ClockB:
//          - AddressB reads that address from all lanes in parallel [2‑cycle read]
//          - Concatenates the data read from lanes into QB (via mem_lane)

`default_nettype none
module multimem #(
    parameter integer unsigned BYTES_PER_PIXEL = params_pkg::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params_pkg::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params_pkg::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params_pkg::PIXEL_HALFHEIGHT,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire [calc_pkg::num_data_a_bits()-1:0] DataInA,
    input wire [15:0] DataInB,
    // 12 bits [11:0]      -5-                   -log( (64*2),2)=7-
    // input wire [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] AddressA,
    input wire [calc_pkg::num_address_a_bits(
PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
)-1:0] AddressA,
    // 11 bits [10:0] (-2, because this is 16bit, not 8bit), -3 because we're not pulling half panels anymore
    input wire [calc_pkg::num_address_b_bits(PIXEL_WIDTH, PIXEL_HALFHEIGHT)-1:0] AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output wire [calc_pkg::num_data_a_bits()-1:0] QA,
    output wire [calc_pkg::num_data_b_bits(PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT)-1:0] QB
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

    localparam integer unsigned LANES = (1 << calc_pkg::num_structure_bits(
        PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
    ));
    wire [LANES*calc_pkg::num_data_a_bits()-1:0] qb_lanes_w;

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_lane
            wire [calc_pkg::num_structure_bits(
PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
)-1:0] lane_idx_from_addr = {
                AddressA[calc_pkg::num_address_a_bits(
                    PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
                )-1-:calc_pkg::num_subpanelselect_bits(
                    PIXEL_HEIGHT, PIXEL_HALFHEIGHT
                )],
                AddressA[calc_pkg::num_pixelcolorselect_bits(BYTES_PER_PIXEL)-1:0]
            };

            wire we_lane_c = ClockEnA & WrA & (lane_idx_from_addr == i[calc_pkg::num_structure_bits(
                PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
            )-1:0]);
            (* keep = "true" *) reg we_lane_q;
            (* keep = "true" *) reg [calc_pkg::num_address_b_bits(PIXEL_WIDTH, PIXEL_HALFHEIGHT)-1:0] addra_q;
            (* keep = "true" *) reg [calc_pkg::num_data_a_bits()-1:0] dia_q;

            always @(posedge ClockA) begin
                we_lane_q <= we_lane_c;
                addra_q <= AddressA[(calc_pkg::num_address_a_bits(
                    PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
                )-calc_pkg::num_subpanelselect_bits(
                    PIXEL_HEIGHT, PIXEL_HALFHEIGHT
                ))-1-:calc_pkg::num_address_b_bits(
                    PIXEL_WIDTH, PIXEL_HALFHEIGHT
                )];
                dia_q <= DataInA;
            end

            mem_lane #(
                .ADDR_BITS(calc_pkg::num_address_b_bits(PIXEL_WIDTH, PIXEL_HALFHEIGHT)),
                .DW(calc_pkg::num_data_a_bits())
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
                .dob  (qb_lanes_w[i*calc_pkg::num_data_a_bits()+:calc_pkg::num_data_a_bits()])
            );
        end
    endgenerate

    assign QB = qb_lanes_w;

    assign QA = 0;
    wire _unused_ok = &{1'b0, WrB, DataInB, 1'b0};
endmodule
