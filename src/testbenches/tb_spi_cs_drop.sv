/*
 * SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
 * SPDX-License-Identifier: MIT
 */
`default_nettype none
`timescale 1ns/10ps
module tb_spi_cs_drop #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    reg rstb;
    reg ss;
    reg sck;
    reg sdin;
    reg mlb;
    reg ten;
    reg [7:0] tdata;
    wire sdout;
    wire done;
    wire [7:0] rdata;

    parameter PERIOD = 50;
    localparam integer HALF_PERIOD = PERIOD / 2;

    initial begin
        `ifdef DUMP_FILE_NAME
            $dumpfile(`DUMP_FILE_NAME);
        `endif
        $dumpvars(0, tb_spi_cs_drop);
    end

    // Verification goal:
    // - A full byte is received correctly.
    // - A CS deassert mid-byte resets the receive bit counter.
    // - The next full byte realigns and is received correctly.
    spi_slave SLV (
        .rstb(rstb),
        .ten(ten),
        .tdata(tdata),
        .mlb(mlb),
        .ss(ss),
        .sck(sck),
        .sdin(sdin),
        .sdout(sdout),
        .done(done),
        .rdata(rdata)
    );

    // Provide a few clocks around reset so the slave samples cleanly.
    task automatic pulse_sck(input integer cycles);
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                sck = 1'b0;
                #HALF_PERIOD;
                sck = 1'b1;
                #HALF_PERIOD;
            end
        end
    endtask

    // Shift a fixed number of bits using the configured bit order.
    task automatic send_bits(input [7:0] data, input integer bit_count);
        integer i;
        reg bitval;
        begin
            for (i = 0; i < bit_count; i = i + 1) begin
                bitval = mlb ? data[7 - i] : data[i];
                sck = 1'b0;
                sdin = bitval;
                #HALF_PERIOD;
                sck = 1'b1;
                #HALF_PERIOD;
            end
        end
    endtask

    // Send a complete byte with CS asserted.
    task automatic send_byte(input [7:0] data);
        begin
            ss = 1'b0;
            send_bits(data, 8);
            ss = 1'b1;
            #HALF_PERIOD;
        end
    endtask

    // Abort a transfer mid-byte by dropping CS early.
    task automatic send_partial(input [7:0] data, input integer bit_count);
        begin
            ss = 1'b0;
            send_bits(data, bit_count);
            ss = 1'b1;
            #HALF_PERIOD;
        end
    endtask

    // Validate the next completed byte; fail fast on mismatch.
    task automatic expect_byte(input [7:0] expected);
        begin
            @(posedge done);
            if (rdata !== expected) begin
                $display("FAIL: expected 0x%02x got 0x%02x at time %0t", expected, rdata, $time);
                $fatal(1);
            end else begin
                $display("PASS: got 0x%02x at time %0t", rdata, $time);
            end
        end
    endtask

    initial begin
        rstb = 1'b0;
        ss = 1'b1;
        sck = 1'b1;
        sdin = 1'b1;
        mlb = 1'b1;
        ten = 1'b0;
        tdata = 8'h00;

        pulse_sck(2);
        rstb = 1'b1;
        #100;

        // Baseline: full byte should pass.
        fork
            expect_byte(8'h9A);
            send_byte(8'h9A);
        join

        // Fault injection: truncate a byte mid-transfer.
        send_partial(8'h3C, 3);

        // Recovery: next byte should realign and pass.
        fork
            expect_byte(8'h5E);
            send_byte(8'h5E);
        join

        $display("SPI CS-drop recovery test complete");
        $finish;
    end
endmodule
