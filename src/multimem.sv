`default_nettype none
module multimem #(
    parameter PIXEL_WIDTH = 'd64,
    parameter PIXEL_HEIGHT = 'd32,
    parameter BYTES_PER_PIXEL = 'd2
    ) (
    input wire [7:0] DataInA,
    input wire [15:0] DataInB,
    // 12 bits [11:0]
    input wire [$clog2(PIXEL_HEIGHT)+$clog2((PIXEL_WIDTH * BYTES_PER_PIXEL) - 1)-1:0] AddressA,
    // 11 bits [10:0] (-2, because this is 16bit, not 8bit)
    input wire [$clog2(PIXEL_HEIGHT)+$clog2((PIXEL_WIDTH * BYTES_PER_PIXEL) - 1)-2:0] AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output reg [7:0] QA,
    output reg [15:0] QB
    );
    // Underlying memory: 4K x 8-bit
    //  [7:0] mem [0:4095]
    reg [7:0] mem [0:(PIXEL_HEIGHT*PIXEL_WIDTH*BYTES_PER_PIXEL)-1];  // 2^12 = 4096 entries
    `ifdef SIM
    reg [11:0] init_index;
    reg        init_done;
    `endif
    // Write Port A: 8-bit writes
    always @(posedge ClockA) begin
        if (ClockEnA) begin
            if (WrA)
                mem[AddressA] <= DataInA;
        end
    end

    // Read Port B: 16-bit reads from two consecutive 8-bit locations
    always @(posedge ClockB) begin
        if (ResetA || ResetB) begin
            `ifdef SIM
            init_index <= 12'b0;
            init_done <= 1'b0;
            `endif
            QB <= 16'b0;
        end
        else begin
            `ifdef SIM
            if (!init_done) begin
                mem[init_index] <= 8'h00;
                init_index <= init_index + 1;
                if (init_index == ((PIXEL_HEIGHT*PIXEL_WIDTH*BYTES_PER_PIXEL)-1)) begin
                    init_done <= 1;
                end
            end
            else begin
            `endif
                if (ClockEnB) begin
                    QB <= {mem[{AddressB, 1'b1}], mem[{AddressB, 1'b0}]};
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
