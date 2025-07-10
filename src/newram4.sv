`default_nettype none
module newram4 (DataInA, AddressA, AddressB, ClockA, ClockB,
    ClockEnA, ClockEnB, WrA, ResetA, ResetB, QB);
    input wire [1:0] DataInA;
    input wire [10:0] AddressA;
    input wire [10:0] AddressB;
    input wire ClockA;
    input wire ClockB;
    input wire ClockEnA;
    input wire ClockEnB;
    input wire WrA;
    input wire ResetA;
    input wire ResetB;
    output wire [1:0] QB;
//
    wire [15:0] TransformedDataA;
    wire [15:0] TransformedDataB;
    assign TransformedDataA = {4'b0, DataInA[1], 7'b0, DataInA[0], 3'b0};
    SB_RAM40_4K #(
        .READ_MODE(3),  // 0 = 16 x 256 PINS USED 11, 3
        .WRITE_MODE(3), // 3 = 2048 x 2 PINS USED 11, 3
        .INIT_0(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_1(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_2(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_3(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_4(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_5(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_6(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_7(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_8(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_9(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_A(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_B(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_C(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_D(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_E(256'h0000000000000000000000000000000000000000000000000000000000000000),
        .INIT_F(256'h0000000000000000000000000000000000000000000000000000000000000000)
    ) module_2x2048 (
    .RDATA(TransformedDataB),
    //.RADDR(AddressB[10:0]),
    .RADDR(AddressB),
    .RCLK(ClockB),
    .RCLKE(ClockEnB),
    .RE(1'b1),      // active high
    //.WADDR(AddressA[11:1]),
    .WADDR(AddressA),
    .WCLK(ClockA),
    .WCLKE(ClockEnA), // active high
    .WDATA(TransformedDataA),
    //.WE(WrA & AddressA[0]) // active high
    .WE(WrA) // active high
    // WR   Address A | Q
    //  0   0         | 0
    //  0   1         | 0
    //  1   0         | 0
    //  1   1         | 1
    );
    assign QB = {TransformedDataB[11], TransformedDataB[3]};
    // mode 0, data width 16, pins used 15:0
    // mode 1, data width 8, pins used 14, 12, 10, 8, 6, 4, 2, 0
    // mode 2, data width 4, pins used 13, 9, 5, 1
    // mode 3, data width 2, pins used 11, 3
    wire _unused_ok = &{1'b0,
                        ResetA,
                        ResetB,
                        TransformedDataB[15:12],
                        TransformedDataB[10:4],
                        TransformedDataB[2:0]};
endmodule
