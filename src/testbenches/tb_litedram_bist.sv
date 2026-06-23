// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none

// Drives the (now sustained) litedram_bist against a correct behavioral native
// port (a per-address memory that returns exactly what was written). With a clean
// memory the bist must complete a full address pass and report NO error -- i.e.
// the bist's own logic doesn't produce false positives; on hardware `error` then
// reflects only real PHY write/read corruption.
module tb_litedram_bist #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam logic [23:0] TEST_ADDR = 24'h000123;
    localparam logic [15:0] TEST_DATA = 16'hcafe;
    localparam logic [23:0] ADDR_SPAN = 24'd8;        // small range so a full pass sims quickly
    localparam int unsigned MAX_TEST_CYCLES = 4000;

    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        init_done = 1'b0;
    logic        init_error = 1'b0;
    wire         busy, done, error;
    wire         cmd_valid, cmd_we;
    wire [23:0]  cmd_addr;
    wire         wdata_valid;
    wire  [1:0]  wdata_we;
    wire [15:0]  wdata_data;
    wire         rdata_ready;
    logic        cmd_ready, wdata_ready;
    logic        rdata_valid = 1'b0;
    logic [15:0] rdata_data = '0;

    litedram_bist #(
        .TEST_ADDR(TEST_ADDR), .TEST_DATA(TEST_DATA), .ADDR_SPAN(ADDR_SPAN), .MAX_WAIT_TICKS(16)
    ) dut (
        .clk(clk), .reset(reset), .init_done(init_done), .init_error(init_error),
        .busy(busy), .done(done), .error(error),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    always #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;

    // --- behavioral native port: store writes, return reads after a small latency. ---
    logic [15:0] nmem [logic [23:0]];
    logic [23:0] rd_addr_q;
    logic [1:0]  rd_lat_q;

    assign cmd_ready   = !reset && init_done;
    assign wdata_ready = !reset && init_done;

    always_ff @(posedge clk) begin
        if (reset) begin
            rdata_valid <= 1'b0;
            rd_lat_q <= '0;
        end else begin
            rdata_valid <= 1'b0;
            if (wdata_valid && wdata_ready && cmd_we) nmem[cmd_addr] = wdata_data;  // blocking: assoc array
            if (cmd_valid && cmd_ready && !cmd_we) begin
                rd_addr_q <= cmd_addr;
                rd_lat_q  <= 2'd2;
            end else if (rd_lat_q != 2'd0) begin
                rd_lat_q <= rd_lat_q - 1'b1;
                if (rd_lat_q == 2'd1) begin
                    rdata_valid <= 1'b1;
                    rdata_data  <= nmem.exists(rd_addr_q) ? nmem[rd_addr_q] : 16'hdead;
                end
            end
        end
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_litedram_bist);
        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (3) @(posedge clk);
        init_done = 1'b1;

        for (int unsigned c = 0; c < MAX_TEST_CYCLES && !done; c++) @(posedge clk);

        if (!done)  $fatal(1, "bist did not complete a pass within %0d cycles", MAX_TEST_CYCLES);
        if (error)  $fatal(1, "bist reported error against a CORRECT mock memory (false positive)");
        if (busy)   $fatal(1, "bist still busy after a completed pass");
        $display("tb_litedram_bist: PASS (sustained sweep over %0d addrs, no false error)", ADDR_SPAN);
        $finish;
    end

    // Global timeout.
    initial begin
        #5_000_000;
        $fatal(1, "tb_litedram_bist: global timeout");
    end
endmodule
