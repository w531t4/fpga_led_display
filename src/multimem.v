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
    output wire [7:0] QA;
    output wire [15:0] QB;

    wire [1:0] M0_portb_out;
    wire [1:0] M1_portb_out;
    wire [1:0] M2_portb_out;
    wire [1:0] M3_portb_out;
    wire [1:0] M4_portb_out;
    wire [1:0] M5_portb_out;
    wire [1:0] M6_portb_out;
    wire [1:0] M7_portb_out;

    newram4 M0 (
    .QB(M0_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[1:0]),
    .WrA(WrA & ~AddressA[0])
    );

    newram4 M1 (
    .QB(M1_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[3:2]),
    .WrA(WrA & ~AddressA[0])
    );

    newram4 M2 (
    .QB(M2_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[5:4]),
    .WrA(WrA & ~AddressA[0])
    );

    newram4 M3 (
    .QB(M3_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[7:6]),
    .WrA(WrA & ~AddressA[0])
    );

    newram4 M4 (
    .QB(M4_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[1:0]),
    .WrA(WrA & AddressA[0])
    );

    newram4 M5 (
    .QB(M5_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[3:2]),
    .WrA(WrA & AddressA[0])
    );

    newram4 M6 (
    .QB(M6_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[5:4]),
    .WrA(WrA & AddressA[0])
    );

    newram4 M7 (
    .QB(M7_portb_out),
    .AddressB(AddressB),
    .ClockB(ClockB),
    .ClockEnB(ClockEnB),
    .AddressA(AddressA[11:1]),
    .ClockA(ClockA),
    .ClockEnA(ClockEnA),
    .DataInA(DataInA[7:6]),
    .WrA(WrA & AddressA[0])
    );

    assign QA = 8'b0;
    assign QB = { M7_portb_out[1:0], M6_portb_out[1:0],
                  M5_portb_out[1:0], M4_portb_out[1:0],
                  M3_portb_out[1:0], M2_portb_out[1:0],
                  M1_portb_out[1:0], M0_portb_out[1:0] };
endmodule