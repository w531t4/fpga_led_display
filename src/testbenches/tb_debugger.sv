// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_debugger #(
    parameter integer unsigned DIVIDER_TICKS = 1023,
    parameter integer unsigned CLK_DIV_COUNT = 600,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    logic reset;
    wire tx_out;
    logic clk_out;
    // TODO: move command into .svh
    logic [1071:0] mystring = "01112233445566778811223344556677881122334455667788112233445566778811223344556677881122334455667788112233445566778811223344556677-L Rrb";
    wire tb_clk_baudrate;
    logic rx_line2;
    logic [3:0] i;
    logic [10:0] j;
    wire [22:0] _unused_ok_main;
    debugger_if debug_if (clk);
    clock_divider #(
        .CLK_DIV_COUNT(CLK_DIV_COUNT)
    ) clkdiv_baudrate (
        .reset  (reset),
        .clk_in (clk),
        .clk_out(tb_clk_baudrate)
    );

    debugger #(
        .DIVIDER_TICKS(DIVIDER_TICKS)
    ) debug_instance (
        .clk_in(clk),
        .reset(reset),
        .debug_if(debug_if),
        .tx_out(tx_out),
        .debug_uart_rx_in(rx_line2),
        .currentState(_unused_ok_main[4:0]),
        .debug_command(_unused_ok_main[19:12])
    );

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_debugger);
        i = 'd0;
        j = 'd0;
        clk = 0;
        reset = 0;
        rx_line2 = 0;
        clk_out = 0;
        debug_if.ddata = 'b0;

    end

    always @(posedge tb_clk_baudrate) begin
        if (i == 'd10) begin
            rx_line2 <= 1'b0;
            if (j >= $bits(j)'($bits(mystring) - 8)) begin
                j <= 'd0;
            end else begin
                j <= j + 'd8;
            end
            i <= 'd0;
        end else if (i == 'd9) begin
            rx_line2 <= 1'b1;
            i <= i + 1;
        end else if (i == 'd8) begin
            rx_line2 <= 1'b1;
            i <= i + 1;
        end else begin
            rx_line2 <= mystring[$bits(j)'(i)+j];
            i <= i + 1;
        end
    end
    initial begin
        #2 reset = !reset;
    end
    initial begin
        #3 reset = !reset;
    end

    initial #1000000 $finish;

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;  // 2 of these make a period
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        tx_out,
                        clk_out,
                        1'b0};
    // verilog_format: on
endmodule
