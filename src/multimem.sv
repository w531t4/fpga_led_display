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
    // Underlying memory: 4K x 8-bit
    //  [7:0] mem [0:4095]
    //  [7:0] mem [structure bits] [addr_b/index bits]
    reg [_NUM_DATA_A_BITS-1:0] mem [0:(1 << _NUM_STRUCTURE_BITS)-1][0:(1 << _NUM_ADDRESS_B_BITS) - 1];  // 2^12 = 4096 entries
    `ifdef SIM
        // Used to initialize memory during simulation
        //  [7:0] mem [mems] [index]
        reg [_NUM_ADDRESS_B_BITS-1:0] init_index;
        reg [_NUM_STRUCTURE_BITS-1:0] init_mems;
        reg init_done;
    `endif
    reg [_NUM_DATA_B_BITS-1:0] QB_pre;
    // Write Port A: 8-bit writes
    always @(posedge ClockA) begin
        if (ClockEnA) begin
            if (WrA)
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
                mem[{
                        AddressA[_NUM_ADDRESS_A_BITS-1
                                 :_NUM_ADDRESS_A_BITS-_NUM_SUBPANELSELECT_BITS
                                 ],
                        AddressA[_NUM_PIXELCOLORSELECT_BITS - 1
                                 :0]
                    }]
                   [{
                        AddressA[(_NUM_ADDRESS_A_BITS-_NUM_SUBPANELSELECT_BITS)-1
                                 :(_NUM_PIXELCOLORSELECT_BITS - 1) + 1]
                   }] <= DataInA;
                // mem[AddressA[$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-2:1]]
                //    [{AddressA[$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1],
                //      AddressA[0]}] <= DataInA;
        end
    end

    // Read Port B: 16-bit reads from two consecutive 8-bit locations

    always @(posedge ClockB) begin
        if (ResetA || ResetB) begin
            `ifdef SIM
                init_index <= {_NUM_ADDRESS_B_BITS{1'b0}};
                init_mems <= {_NUM_STRUCTURE_BITS{1'b0}};
                init_done <= 1'b0;
                QB_pre <= {_NUM_DATA_B_BITS{1'b0}};
            `endif
            QB <= {_NUM_DATA_B_BITS{1'b0}};
        end
        else begin
            `ifdef SIM
                if (!init_done) begin
                    mem[init_mems][init_index] <= {_NUM_DATA_A_BITS{1'b0}};
                    init_index <= init_index + 1;
                    if (init_index == ((1 << _NUM_ADDRESS_B_BITS) - 1)) begin
                        if (init_mems == ((1 << _NUM_STRUCTURE_BITS) - 1)) init_done <= 1;
                        else begin
                            init_mems <= init_mems + 1;
                            init_index <= 0;
                        end
                    end
                end
                else begin
            `endif
                if (ClockEnB) begin
                    for (int i = 0; i < (1 << _NUM_STRUCTURE_BITS); i++) begin
                         QB_pre[i*_NUM_DATA_A_BITS +: _NUM_DATA_A_BITS] <= mem[i][AddressB];
                    end
                    QB <= QB_pre;
                end
            `ifdef SIM
                end
            `endif
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
