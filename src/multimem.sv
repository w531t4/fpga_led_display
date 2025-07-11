`default_nettype none
module multimem (DataInA, DataInB, AddressA, AddressB, ClockA, ClockB,
    ClockEnA, ClockEnB, WrA, WrB, ResetA, ResetB, QA, QB);
    input wire [7:0] DataInA;
    input wire [15:0] DataInB;
    input wire [11:0] AddressA;
    input wire [10:0] AddressB;
    input wire ClockA;
    input wire ClockB;
    input wire ClockEnA;
    input wire ClockEnB;
    input wire WrA;
    input wire WrB;
    input wire ResetA;
    input wire ResetB;
    output reg [7:0] QA;
    output reg [15:0] QB;

    // Underlying memory: 4K x 8-bit
    reg [7:0] mem [0:4095];  // 2^12 = 4096 entries
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
                if (init_index == 4095) begin
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
