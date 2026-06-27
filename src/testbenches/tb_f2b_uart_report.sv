// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none
// =============================================================================
// tb_f2b_uart_report -- proves the F2.b plain-text reporter actually serializes
// the right ASCII before we ever flash. It decodes the DUT's tx line bit-by-bit
// (real 8N1 UART framing at TICKS_PER_BIT) and checks the emitted line spells
// "RC=0x30\n" for rc_count=48, and "RC=0xFF\n" at the 8-bit max.
// =============================================================================
module tb_f2b_uart_report #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam integer unsigned TPB    = 16;  // UART ticks (clk cycles) per bit
    localparam int unsigned     MSGLEN = 8;   // "RC=0xHH\n"

    logic       clk;
    logic       reset = 1'b1;
    logic [7:0] rc_count = 8'd48;
    wire        tx;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    f2b_uart_report #(
        .UART_TICKS_PER_BIT(TPB),
        .GAP_TICKS(32'd40)        // short gap so the line repeats quickly in sim
    ) dut (
        .clk     (clk),
        .reset   (reset),
        .rc_count(rc_count),
        .tx      (tx)
    );

    // ---- 8N1 UART receive: wait for start bit, sample 8 data bits LSB-first ----
    task automatic get_byte(output logic [7:0] b);
        int i;
        begin
            @(negedge tx);                              // falling edge = start bit
            repeat (TPB + TPB/2) @(posedge clk);        // step to middle of bit0
            for (i = 0; i < 8; i++) begin
                b[i] = tx;
                repeat (TPB) @(posedge clk);            // advance one bit period
            end
        end
    endtask

    task automatic get_line(output logic [7:0] buf9 [0:MSGLEN-1]);
        int k;
        begin
            for (k = 0; k < MSGLEN; k++) get_byte(buf9[k]);
        end
    endtask

    task automatic expect_line(input logic [7:0] got [0:MSGLEN-1],
                               input logic [7:0] exp [0:MSGLEN-1], input string tag);
        int k;
        logic ok;
        begin
            ok = 1'b1;
            for (k = 0; k < MSGLEN; k++) if (got[k] !== exp[k]) ok = 1'b0;
            $write("  %s got: \"", tag);
            for (k = 0; k < 7; k++) $write("%c", got[k]);  // printable part only
            $write("\"  (bytes");
            for (k = 0; k < MSGLEN; k++) $write(" %02x", got[k]);
            $display(")");
            if (!ok) begin
                $write("  expected:");
                for (k = 0; k < MSGLEN; k++) $write(" %02x", exp[k]);
                $display("");
                $error("tb_f2b_uart_report: %s line mismatch", tag);
            end
        end
    endtask

    logic [7:0] line   [0:MSGLEN-1];
    logic [7:0] exp48  [0:MSGLEN-1];
    logic [7:0] exp255 [0:MSGLEN-1];

    initial begin
        // "RC=0x30\n"  (0x30 = 48)
        exp48  = '{"R", "C", "=", "0", "x", "3", "0", 8'h0A};
        // "RC=0xFF\n"  (0xFF = 255, the 8-bit max)
        exp255 = '{"R", "C", "=", "0", "x", "F", "F", 8'h0A};

        repeat (4) @(posedge clk);
        reset = 1'b0;

        rc_count = 8'd48;
        get_line(line);
        expect_line(line, exp48, "count=48");

        rc_count = 8'd255;
        get_line(line);                // skip a line so the new value is snapshotted
        get_line(line);
        expect_line(line, exp255, "count=255");

        $display("tb_f2b_uart_report: PASS");
        $finish;
    end

    // safety net
    initial begin
        #2_000_000;
        $error("tb_f2b_uart_report: TIMEOUT");
        $finish;
    end
endmodule
