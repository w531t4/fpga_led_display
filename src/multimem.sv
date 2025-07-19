`default_nettype none
module multimem #(
    parameter PIXEL_WIDTH = 'd64,
    parameter PIXEL_HEIGHT = 'd32,
    parameter PIXEL_HALFHEIGHT = 'd16,
    parameter BYTES_PER_PIXEL = 'd2,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire [7:0] DataInA,
    input wire [15:0] DataInB,
    // 12 bits [11:0]      -5-                   -log( (64*2),2)=7-
    input wire [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] AddressA,
    // 11 bits [10:0] (-2, because this is 16bit, not 8bit), -3 because we're not pulling half panels anymore
    input wire [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-3:0] AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output reg [7:0] QA,
    output reg [((PIXEL_HEIGHT / PIXEL_HALFHEIGHT) * BYTES_PER_PIXEL * 8)-1:0] QB
);
    // PARALLEL_MEMS represents how many memories we'll break things down into (based on the bits that are hardcoded (and not included in AddressB))
    //                 2 choices for half
    //                 2 choices for pixel-byte
    localparam PARALLEL_MEMS = ((PIXEL_HEIGHT / PIXEL_HALFHEIGHT)) * BYTES_PER_PIXEL;
    localparam DEPTH_AFTER_PARALLEL = $rtoi((PIXEL_HEIGHT*PIXEL_WIDTH*BYTES_PER_PIXEL) / (((PIXEL_HEIGHT / PIXEL_HALFHEIGHT)) * BYTES_PER_PIXEL)*1.0);

    // Underlying memory: 4K x 8-bit
    //  [7:0] mem [0:4095]
    reg [7:0] mem [0:DEPTH_AFTER_PARALLEL-1][0:PARALLEL_MEMS-1];  // 2^12 = 4096 entries
    `ifdef SIM
        reg [$clog2(DEPTH_AFTER_PARALLEL)-1:0] init_index;
        reg [$clog2(PARALLEL_MEMS)-1:0] init_mems;
        reg        init_done;
    `endif
    reg [((PIXEL_HEIGHT / PIXEL_HALFHEIGHT) * BYTES_PER_PIXEL * 8)-1:0] QB_pre;
    // Write Port A: 8-bit writes
    always @(posedge ClockA) begin
        if (ClockEnA) begin
            if (WrA)
                mem[AddressA[$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-2:1]]
                   [{AddressA[$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1],
                     AddressA[0]}] <= DataInA;
        end
    end

    // Read Port B: 16-bit reads from two consecutive 8-bit locations
    always @(posedge ClockB) begin
        if (ResetA || ResetB) begin
            `ifdef SIM
                init_index <= {$clog2(DEPTH_AFTER_PARALLEL){1'b0}};
                init_mems <= {$clog2(PARALLEL_MEMS){1'b0}};
                init_done <= 1'b0;
                QB_pre <= {((PIXEL_HEIGHT / PIXEL_HALFHEIGHT) * BYTES_PER_PIXEL * 8){1'b0}};
            `endif
            QB <= {((PIXEL_HEIGHT / PIXEL_HALFHEIGHT) * BYTES_PER_PIXEL * 8){1'b0}};
        end
        else begin
            `ifdef SIM
                if (!init_done) begin
                    mem[init_index][init_mems] <= {$clog2(DEPTH_AFTER_PARALLEL){1'b0}};
                    init_index <= init_index + 1;
                    if (init_index == (DEPTH_AFTER_PARALLEL-1)) begin
                        if (init_mems == (PARALLEL_MEMS-1)) init_done <= 1;
                        else begin
                            init_mems <= init_mems + 1;
                            init_index <= 0;
                        end
                    end
                end
                else begin
            `endif
                if (ClockEnB) begin
                    for (int i = 0; i < PARALLEL_MEMS; i++) begin
                         QB_pre[i*8 +: 8] <= mem[AddressB][i];
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
