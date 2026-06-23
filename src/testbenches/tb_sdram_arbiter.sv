// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none

// tb_sdram_arbiter:
// - Confirms the prefetch read port is PIPELINED: many read commands are
//   accepted before the first word returns, and returned words match the
//   issued addresses in order.
// - Confirms a simple write (client 0) reaches the native port and pulses
//   s_done once cmd+wdata are accepted; a simple read (client 1) returns on
//   s_rdata.
// - Confirms a pending write is INTERLEAVED into an active prefetch read burst
//   without disturbing the in-order read returns.
module tb_sdram_arbiter;
    localparam int unsigned NUM_SIMPLE = 2;
    localparam int unsigned READ_LATENCY = 6;
    localparam int unsigned MAX_WAIT = 512;
    localparam int unsigned BURST = 24;

    logic clk;
    logic reset;
    logic init_done;

    // Prefetch (pipelined read) port -- driven by a synchronous counter issuer.
    logic                    burst_en;
    types::sdram_word_addr_t burst_base;
    int unsigned             issue_idx;
    wire                     rd_req  = burst_en && (issue_idx < BURST);
    wire types::sdram_word_addr_t rd_addr = burst_base + types::sdram_word_addr_t'(issue_idx);
    wire                     rd_cmd_ready;
    wire                     rd_rvalid;
    wire types::sdram_word_data_t rd_rdata;

    // Simple clients (0 = write, 1 = copyframe).
    logic [NUM_SIMPLE-1:0]                  s_req;
    logic [NUM_SIMPLE-1:0]                  s_we;
    types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr;
    types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wdata_we;
    types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdata;
    wire [NUM_SIMPLE-1:0]                    s_grant;
    wire [NUM_SIMPLE-1:0]                    s_done;
    wire types::sdram_word_data_t           s_rdata;

    // Native port.
    wire                     cmd_valid;
    logic                    cmd_ready;
    wire                     cmd_we;
    wire types::sdram_word_addr_t cmd_addr;
    wire                     wdata_valid;
    logic                    wdata_ready;
    wire types::sdram_byte_en_t wdata_we;
    wire types::sdram_word_data_t wdata_data;
    logic                    rdata_valid;
    wire                     rdata_ready;
    types::sdram_word_data_t rdata_data;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) dut (
        .clk(clk), .reset(reset), .init_done(init_done),
        .rd_req(rd_req), .rd_addr(rd_addr), .rd_cmd_ready(rd_cmd_ready),
        .rd_rvalid(rd_rvalid), .rd_rdata(rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wdata_we), .s_wdata(s_wdata),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    always #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    initial begin #5_000_000; $fatal(1, "tb_sdram_arbiter: global timeout"); end

    // Synchronous read-command issuer: advance exactly when a command is accepted.
    always_ff @(posedge clk) begin
        if (reset || !burst_en) issue_idx <= 0;
        else if (rd_req && rd_cmd_ready) issue_idx <= issue_idx + 1;
    end

    // ----- Behavioral pipelined native port: a memory + a read latency line. -----
    types::sdram_word_data_t nmem[types::sdram_word_addr_t];
    assign cmd_ready   = !reset && init_done;
    assign wdata_ready = !reset && init_done;

    logic                    rpipe_valid[READ_LATENCY];
    types::sdram_word_addr_t rpipe_addr [READ_LATENCY];
    int unsigned reads_outstanding;
    int unsigned max_outstanding;

    wire rd_cmd_acc = cmd_valid && cmd_ready && !cmd_we;

    always_ff @(posedge clk) begin
        if (reset) begin
            rdata_valid <= 1'b0;
            rdata_data <= '0;
            reads_outstanding <= 0;
            max_outstanding <= 0;
            for (int i = 0; i < READ_LATENCY; i++) begin
                rpipe_valid[i] <= 1'b0;
                rpipe_addr[i] <= '0;
            end
        end else begin
            if (!rdata_ready) $fatal(1, "arbiter deasserted rdata_ready");
            if (cmd_valid && cmd_ready && cmd_we) nmem[cmd_addr] = wdata_data;  // blocking: assoc array
            for (int i = READ_LATENCY - 1; i > 0; i--) begin
                rpipe_valid[i] <= rpipe_valid[i-1];
                rpipe_addr[i]  <= rpipe_addr[i-1];
            end
            rpipe_valid[0] <= rd_cmd_acc;
            if (rd_cmd_acc) rpipe_addr[0] <= cmd_addr;
            rdata_valid <= rpipe_valid[READ_LATENCY-1];
            rdata_data  <= nmem[rpipe_addr[READ_LATENCY-1]];

            if (rd_cmd_acc && !rpipe_valid[READ_LATENCY-1]) reads_outstanding <= reads_outstanding + 1;
            else if (!rd_cmd_acc && rpipe_valid[READ_LATENCY-1]) reads_outstanding <= reads_outstanding - 1;
            if (reads_outstanding > max_outstanding) max_outstanding <= reads_outstanding;
        end
    end

    function automatic types::sdram_word_data_t patt(input int unsigned i);
        patt = types::sdram_word_data_t'(16'hA000 + i);
    endfunction

    // Receive + check a full read burst from base (assumes nmem[base+i]=patt(i)).
    task automatic recv_burst();
        int unsigned recv;
        recv = 0;
        while (recv < BURST) begin
            @(posedge clk);
            if (rd_rvalid) begin
                if (rd_rdata !== patt(recv))
                    $fatal(1, "prefetch read %0d mismatch got %0h exp %0h", recv, rd_rdata, patt(recv));
                recv = recv + 1;
            end
        end
    endtask

    task automatic simple_op(input int unsigned idx, input logic we,
                             input types::sdram_word_addr_t a, input types::sdram_word_data_t d);
        int unsigned i;
        logic done;
        s_addr[idx] = a; s_we[idx] = we;
        s_wdata_we[idx] = types::sdram_byte_en_t'(2'b11); s_wdata[idx] = d;
        s_req[idx] = 1'b1;
        done = 1'b0;
        for (i = 0; i < MAX_WAIT && !done; i++) begin
            @(posedge clk);
            if (s_done[idx]) begin
                if (!we && s_rdata !== d) $fatal(1, "simple read %0d data wrong %0h exp %0h", idx, s_rdata, d);
                done = 1'b1;
            end
        end
        if (!done) $fatal(1, "simple op on client %0d never completed", idx);
        s_req[idx] = 1'b0;
        @(posedge clk);
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_arbiter);
        clk = 1'b0; reset = 1'b1; init_done = 1'b0;
        burst_en = 1'b0; burst_base = '0;
        s_req = '0; s_we = '0; s_addr = '0; s_wdata_we = '0; s_wdata = '0;
        rdata_data = '0;
        for (int i = 0; i < BURST; i++) begin
            nmem[types::sdram_word_addr_t'(24'h10_0000 + i)] = patt(i);
            nmem[types::sdram_word_addr_t'(24'h40_0000 + i)] = patt(i);
        end

        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);
        init_done = 1'b1;

        // ---- 1) Pipelined prefetch read burst ----
        burst_base = types::sdram_word_addr_t'(24'h10_0000);
        burst_en = 1'b1;
        recv_burst();
        burst_en = 1'b0;
        if (max_outstanding < 3)
            $fatal(1, "prefetch reads not pipelined: max_outstanding=%0d", max_outstanding);
        $display("tb_sdram_arbiter: pipelined read burst OK (max_outstanding=%0d)", max_outstanding);
        repeat (8) @(posedge clk);

        // ---- 2) Simple write, then read it back ----
        simple_op(0, 1'b1, types::sdram_word_addr_t'(24'h20_0000), types::sdram_word_data_t'(16'hBEEF));
        if (nmem[types::sdram_word_addr_t'(24'h20_0000)] !== 16'hBEEF) $fatal(1, "simple write data wrong");
        simple_op(1, 1'b0, types::sdram_word_addr_t'(24'h20_0000), types::sdram_word_data_t'(16'hBEEF));
        $display("tb_sdram_arbiter: simple write+read OK");

        // ---- 3) Write interleaved into a prefetch read burst ----
        burst_base = types::sdram_word_addr_t'(24'h40_0000);
        burst_en = 1'b1;
        fork
            recv_burst();
            begin : interleaved_write
                repeat (4) @(posedge clk);
                simple_op(0, 1'b1, types::sdram_word_addr_t'(24'h50_0000), types::sdram_word_data_t'(16'hCAFE));
            end
        join
        burst_en = 1'b0;
        if (nmem[types::sdram_word_addr_t'(24'h50_0000)] !== 16'hCAFE) $fatal(1, "interleaved write data wrong");
        $display("tb_sdram_arbiter: write interleave OK");
        repeat (8) @(posedge clk);

        // ---- 4) A prefetch read burst must NOT be starved by a CONTINUOUS write
        // stream. This reproduces the dynamic-content pixelation: the row_prefetch
        // fill is deadline-critical (must fill a display row before it's scanned),
        // but the arbiter served interleaved writes with priority, so a sustained
        // write stream (ESP32 updating a changing region: scrolling text / seconds)
        // starves the fill -> it overruns -> stale/partial rows = pixelation, ONLY
        // where there's heavy write traffic. Hold client-0 write requests high and
        // run a read burst; the reads must still drain within a bounded window.
        begin : starve_test
            int unsigned recv, cyc;
            localparam int unsigned STARVE_DEADLINE = BURST * 8;
            s_addr[0] = types::sdram_word_addr_t'(24'h60_0000); s_we[0] = 1'b1;
            s_wdata_we[0] = types::sdram_byte_en_t'(2'b11); s_wdata[0] = types::sdram_word_data_t'(16'hD00D);
            s_req[0] = 1'b1;                       // held high -> back-to-back writes
            burst_base = types::sdram_word_addr_t'(24'h10_0000);  // nmem preloaded with patt()
            burst_en = 1'b1;
            recv = 0; cyc = 0;
            while (recv < BURST) begin
                @(posedge clk);
                cyc = cyc + 1;
                if (cyc > STARVE_DEADLINE)
                    $fatal(1, "FILL STARVED: read burst got only %0d/%0d words in %0d cycles under a continuous write stream -> prefetch fill overruns -> dynamic-region pixelation",
                           recv, BURST, cyc);
                if (rd_rvalid) begin
                    if (rd_rdata !== patt(recv)) $fatal(1, "starve-test read %0d mismatch got %0h exp %0h", recv, rd_rdata, patt(recv));
                    recv = recv + 1;
                end
            end
            s_req[0] = 1'b0;
            burst_en = 1'b0;
            $display("tb_sdram_arbiter: read-not-starved-by-continuous-writes OK (%0d cycles)", cyc);
        end

        $display("tb_sdram_arbiter: PASS");
        $finish;
    end
endmodule
