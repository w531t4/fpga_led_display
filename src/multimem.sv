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
    output reg [_NUM_DATA_A_BITS-1:0] QA,
    output reg [_NUM_DATA_B_BITS-1:0] QB
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
    wire [LANES*_NUM_DATA_A_BITS-1:0] qb_lanes;

    reg [_NUM_ADDRESS_B_BITS-1:0] AddressB_q;
    always @(posedge ClockB) AddressB_q <= AddressB;

    genvar i;
    generate
    for (i = 0; i < LANES; i = i + 1) begin : G
        wire [_NUM_STRUCTURE_BITS-1:0] lane_idx_from_addr = { AddressA[_NUM_ADDRESS_A_BITS-1 -: _NUM_SUBPANELSELECT_BITS],
                                                              AddressA[_NUM_PIXELCOLORSELECT_BITS-1:0] };

        wire lane_sel = (lane_idx_from_addr == i[_NUM_STRUCTURE_BITS-1:0]);
        wire we_lane_c = ClockEnA & WrA & (lane_idx_from_addr == i[_NUM_STRUCTURE_BITS-1:0]);
        // NEW: register the write triplet locally (1-cycle latency on writes)
        (* keep = "true" *) reg we_lane_q;
        (* keep = "true" *) reg [_NUM_ADDRESS_B_BITS-1:0] addra_q;
        (* keep = "true" *) reg [_NUM_DATA_A_BITS-1:0]    dia_q;

        always @(posedge ClockA) begin
            we_lane_q <= we_lane_c;
            addra_q   <= AddressA[(_NUM_ADDRESS_A_BITS-_NUM_SUBPANELSELECT_BITS)-1 -: _NUM_ADDRESS_B_BITS];
            dia_q     <= DataInA;
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
            .addrb  (AddressB_q),
            .dob    (qb_lanes[i*_NUM_DATA_A_BITS +: _NUM_DATA_A_BITS])
        );
    end
    endgenerate

    // keep CE on the publish only
    always @(posedge ClockB) begin
        if (ResetA || ResetB) begin
            QB <= {_NUM_DATA_B_BITS{1'b0}};
        end else if (ClockEnB) begin
            QB <= qb_lanes; // or one extra pipeline if needed
        end
    end
    assign QA = 0;
    wire _unused_ok = &{1'b0,
                        WrB,
                        DataInB,
                        QA,
                        1'b0};
endmodule





    // localparam MEM_RAWBYTES_NEEDED = PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL;
    // localparam MEM_RAWBITS_NEEDED = $clog2(MEM_RAWBYTES_NEEDED);

    // localparam MEM_NON_ADDRESSABLE_BITS_NEEDED = $clog2(_NUM_SUBPANELS) + $clog2(BYTES_PER_PIXEL);
    // localparam MEM_ADDRESSABLE_BITS_NEEDED = $clog2();
