// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
//
// Bring-up check for the `litedram_gen --sim` core behind ulx3s_litedram_wrapper
// (SIM build). Proves the existing litedram_init FSM drives the behavioral
// SDRAMPHYModel up to init_done, and that a native-port write then read
// round-trips through the model. If this passes, main is simulatable under
// USE_LITEDRAM (via the sim core) instead of failing Verilator with MODMISSING.

module tb_litedram_wrapper_sim #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int unsigned MAX_INIT_CYCLES = 60000;
    localparam int unsigned MAX_OP_CYCLES   = 4000;
    localparam logic [23:0] TEST_ADDR = 24'h00_0042;
    localparam logic [15:0] TEST_DATA = 16'hBEEF;

    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        init_done;
    logic        init_error;

    // Board-level SDRAM pads: unused in the sim core (behavioral PHY inside).
    wire         sdram_clk;
    wire [12:0]  sdram_a;
    wire  [1:0]  sdram_ba;
    wire         sdram_casn;
    wire         sdram_cke;
    wire         sdram_csn;
    wire  [1:0]  sdram_dqm;
    logic [15:0] sdram_d = 16'h0000;
    wire         sdram_rasn;
    wire         sdram_wen;

    wire         user_clk;
    wire         user_rst;

    logic        cmd_valid = 1'b0;
    wire         cmd_ready;
    logic        cmd_we = 1'b0;
    logic [23:0] cmd_addr = 24'd0;

    logic        wdata_valid = 1'b0;
    wire         wdata_ready;
    logic  [1:0] wdata_we = 2'b00;
    logic [15:0] wdata_data = 16'd0;

    wire         rdata_valid;
    logic        rdata_ready = 1'b0;
    wire [15:0]  rdata_data;

    ulx3s_litedram_wrapper dut (
        .clk(clk),
        .reset(reset),
        .init_done(init_done),
        .init_error(init_error),
        .sdram_clk(sdram_clk),
        .sdram_a(sdram_a),
        .sdram_ba(sdram_ba),
        .sdram_casn(sdram_casn),
        .sdram_cke(sdram_cke),
        .sdram_csn(sdram_csn),
        .sdram_dqm(sdram_dqm),
        .sdram_d(sdram_d),
        .sdram_rasn(sdram_rasn),
        .sdram_wen(sdram_wen),
        .user_clk(user_clk),
        .user_rst(user_rst),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_we(cmd_we),
        .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid),
        .wdata_ready(wdata_ready),
        .wdata_we(wdata_we),
        .wdata_data(wdata_data),
        .rdata_valid(rdata_valid),
        .rdata_ready(rdata_ready),
        .rdata_data(rdata_data)
    );

    always #5 clk = ~clk;

    int unsigned i;
    logic        cmd_done;
    logic        wdata_done;
    logic [15:0] captured;

    initial begin
        reset = 1'b1;
        repeat (10) @(posedge clk);
        reset <= 1'b0;

        // --- wait for controller bring-up ---
        i = 0;
        while (!init_done && i < MAX_INIT_CYCLES) begin
            @(posedge clk);
            i = i + 1;
        end
        if (!init_done) $fatal(1, "init_done never asserted after %0d cycles", i);
        if (init_error) $fatal(1, "init_error asserted during bring-up");
        $display("[tb_litedram_wrapper_sim] init_done after %0d cycles", i);

        // --- native-port WRITE ---
        @(posedge clk);
        cmd_valid   <= 1'b1; cmd_we <= 1'b1; cmd_addr <= TEST_ADDR;
        wdata_valid <= 1'b1; wdata_we <= 2'b11; wdata_data <= TEST_DATA;
        cmd_done = 1'b0; wdata_done = 1'b0; i = 0;
        while ((!cmd_done || !wdata_done) && i < MAX_OP_CYCLES) begin
            @(posedge clk);
            if (cmd_ready)   begin cmd_done   = 1'b1; cmd_valid   <= 1'b0; end
            if (wdata_ready) begin wdata_done = 1'b1; wdata_valid <= 1'b0; end
            i = i + 1;
        end
        if (!cmd_done || !wdata_done)
            $fatal(1, "write handshake timeout (cmd_done=%0d wdata_done=%0d)", cmd_done, wdata_done);
        cmd_valid <= 1'b0; wdata_valid <= 1'b0;
        $display("[tb_litedram_wrapper_sim] write accepted at addr 0x%06x", TEST_ADDR);

        repeat (20) @(posedge clk);

        // --- native-port READ ---
        cmd_valid <= 1'b1; cmd_we <= 1'b0; cmd_addr <= TEST_ADDR;
        rdata_ready <= 1'b1;
        cmd_done = 1'b0; i = 0;
        while (!cmd_done && i < MAX_OP_CYCLES) begin
            @(posedge clk);
            if (cmd_ready) begin cmd_done = 1'b1; cmd_valid <= 1'b0; end
            i = i + 1;
        end
        if (!cmd_done) $fatal(1, "read cmd handshake timeout");
        cmd_valid <= 1'b0;

        i = 0;
        while (!rdata_valid && i < MAX_OP_CYCLES) begin
            @(posedge clk);
            i = i + 1;
        end
        if (!rdata_valid) $fatal(1, "rdata_valid never asserted");
        captured = rdata_data;
        @(posedge clk);
        rdata_ready <= 1'b0;

        $display("[tb_litedram_wrapper_sim] read back 0x%04x (expected 0x%04x)", captured, TEST_DATA);
        if (captured !== TEST_DATA)
            $fatal(1, "DATA MISMATCH: got 0x%04x expected 0x%04x", captured, TEST_DATA);

        $display("[tb_litedram_wrapper_sim] PASS");
        $finish;
    end

    // Hard global timeout so a hang fails instead of running forever.
    initial begin
        #6_000_000;
        $fatal(1, "global timeout (no PASS)");
    end
endmodule
