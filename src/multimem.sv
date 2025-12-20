// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// multimem.sv
`default_nettype none
module multimem #(
    parameter PIXEL_WIDTH = 'd64,
    parameter PIXEL_HEIGHT = 'd32,
    parameter PIXEL_HALFHEIGHT = 'd16,
    parameter BYTES_PER_PIXEL = 'd2,
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire [_NUM_DATA_A_BITS-1:0] DataInA,
    input wire [15:0] DataInB,
    // 12 bits [11:0]      -5-                   -log( (64*2),2)=7-
    // input wire [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] AddressA,
    input wire [_NUM_ADDRESS_A_BITS-1:0] AddressA,
    // 11 bits [10:0] (-2, because this is 16bit, not 8bit), -3 because we're not pulling half panels anymore
    input wire [_NUM_ADDRESS_B_BITS-1:0] AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output wire [_NUM_DATA_A_BITS-1:0] QA,
    output wire [_NUM_DATA_B_BITS-1:0] QB
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

    localparam LANES = (1 << _NUM_STRUCTURE_BITS);
    wire [LANES*_NUM_DATA_A_BITS-1:0] qb_lanes_w;

    reg [_NUM_ADDRESS_A_BITS-1:0] AddressA_q;
    reg [_NUM_DATA_A_BITS-1:0]    DataInA_q;
    reg                           WrA_q;
    reg                           ClockEnA_q;

    always @(posedge ClockA) begin
        AddressA_q <= AddressA;
        DataInA_q  <= DataInA;
        WrA_q      <= WrA;
        ClockEnA_q <= ClockEnA;
    end
    // Info: Max frequency for clock '$glbnet$sd_clk$TRELLIS_IO_IN': 316.36 MHz (PASS at 12.00 MHz)
    // Info: Max frequency for clock           '$glbnet$clk_matrix': 88.67 MHz (PASS at 12.00 MHz)
    // Info: Max frequency for clock             '$glbnet$clk_root': 96.28 MHz (PASS at 90.00 MHz)
    genvar i;
    generate
    for (i = 0; i < LANES; i = i + 1) begin : G
        wire [_NUM_STRUCTURE_BITS-1:0] lane_idx_from_addr = { AddressA_q[_NUM_ADDRESS_A_BITS-1 -: _NUM_SUBPANELSELECT_BITS],
                                                              AddressA_q[_NUM_PIXELCOLORSELECT_BITS-1:0] };

        reg we_lane_q;
        reg [_NUM_ADDRESS_B_BITS-1:0] addra_q;
        reg [_NUM_DATA_A_BITS-1:0]    dia_q;

        always @(posedge ClockA) begin
            we_lane_q <= ClockEnA_q & WrA_q & (lane_idx_from_addr == i[_NUM_STRUCTURE_BITS-1:0]);
            addra_q   <= AddressA_q[(_NUM_ADDRESS_A_BITS-_NUM_SUBPANELSELECT_BITS)-1 -: _NUM_ADDRESS_B_BITS];
            dia_q     <= DataInA_q;
        end

        mem_lane #(
            .ADDR_BITS(_NUM_ADDRESS_B_BITS),
            .DW(_NUM_DATA_A_BITS)
        ) u_lane (
            .clka   (ClockA),
            .ena    (1'b1),
            .wea    (we_lane_q),
            .addra  (addra_q),
            .dia    (dia_q),

            .clkb   (ClockB),
            .enb    (ClockEnB),
            .addrb  (AddressB),
            .dob    (qb_lanes_w[i*_NUM_DATA_A_BITS +: _NUM_DATA_A_BITS])
        );
    end
    endgenerate

    assign QB = qb_lanes_w;

    assign QA = 0;
    wire _unused_ok = &{1'b0,
                        ResetA,
                        ResetB,
                        WrB,
                        DataInB,
                        1'b0};
endmodule
