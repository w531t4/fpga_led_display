// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none

// tb_sdram_arbiter:
// - Confirms fixed-priority ordering (client 0 highest) when multiple clients
//   request at once.
// - Confirms a write client's cmd/wdata reach the native port and that
//   client_done only pulses once both channels are accepted.
// - Confirms a read client's address reaches the native port and that
//   client_rdata/client_done reflect the (mocked) native-port response.
// - Confirms a lower-priority client gets served once a higher-priority
//   client's single-word request is withdrawn, demonstrating the
//   word-granular interleaving the arbiter provides for free.
// - Confirms no client is granted while init_done is low, and that a
//   pending request is served as soon as init_done goes high.
module tb_sdram_arbiter;
    localparam int unsigned NUM_CLIENTS = 3;
    localparam int unsigned MAX_WAIT_CYCLES = 64;
    localparam int unsigned READ_LATENCY = 3;

    logic clk;
    logic reset;
    logic init_done;

    logic [NUM_CLIENTS-1:0] client_req;
    logic [NUM_CLIENTS-1:0] client_we;
    types::sdram_word_addr_t [NUM_CLIENTS-1:0] client_addr;
    types::sdram_byte_en_t [NUM_CLIENTS-1:0] client_wdata_we;
    types::sdram_word_data_t [NUM_CLIENTS-1:0] client_wdata;
    wire [NUM_CLIENTS-1:0] client_grant;
    wire [NUM_CLIENTS-1:0] client_done;
    wire types::sdram_word_data_t client_rdata;

    wire cmd_valid;
    logic cmd_ready;
    wire cmd_we;
    wire types::sdram_word_addr_t cmd_addr;
    wire wdata_valid;
    logic wdata_ready;
    wire types::sdram_byte_en_t wdata_we;
    wire types::sdram_word_data_t wdata_data;
    logic rdata_valid;
    wire rdata_ready;
    types::sdram_word_data_t rdata_data;

    logic [7:0] cycle_count;
    logic [NUM_CLIENTS-1:0] done_seen_q;
    types::sdram_word_data_t rdata_seen_q;

    logic read_pending_q;
    logic [$clog2(READ_LATENCY + 1)-1:0] read_wait_q;
    types::sdram_word_addr_t read_addr_q;

    // Folds every address bit into the result (instead of just truncating)
    // so the mock exercises the full address width without lint warnings.
    function automatic types::sdram_word_data_t mock_read_data(input types::sdram_word_addr_t addr);
        mock_read_data = types::sdram_word_data_t'(addr) ^ types::sdram_word_data_t'(addr >> $bits(types::sdram_word_data_t));
    endfunction

    sdram_arbiter #(
        .NUM_CLIENTS(NUM_CLIENTS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .init_done(init_done),
        .client_req(client_req),
        .client_we(client_we),
        .client_addr(client_addr),
        .client_wdata_we(client_wdata_we),
        .client_wdata(client_wdata),
        .client_grant(client_grant),
        .client_done(client_done),
        .client_rdata(client_rdata),
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

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    // Native port mock: cmd/wdata ready toggle every other cycle so the
    // arbiter's cmd_done_q/data_done_q latches get exercised, and reads
    // come back automatically after READ_LATENCY cycles.
    always_comb begin
        cmd_ready = !reset && cycle_count[0] == 1'b1;
        wdata_ready = !reset && cycle_count[0] == 1'b1;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            cycle_count <= '0;
            done_seen_q <= '0;
            rdata_seen_q <= '0;
            read_pending_q <= 1'b0;
            read_wait_q <= '0;
            rdata_valid <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            done_seen_q <= client_done;
            rdata_seen_q <= client_rdata;

            if (!rdata_ready) $fatal(1, "arbiter deasserted rdata_ready, which it should never do");
            if (wdata_valid && client_grant == '0) $fatal(1, "wdata_valid asserted without a granted client");

            rdata_valid <= 1'b0;
            if (cmd_valid && cmd_ready && !cmd_we) begin
                read_pending_q <= 1'b1;
                read_wait_q <= ($bits(read_wait_q))'(READ_LATENCY);
                read_addr_q <= cmd_addr;
            end else if (read_pending_q) begin
                if (read_wait_q == 0) begin
                    read_pending_q <= 1'b0;
                    rdata_valid <= 1'b1;
                    rdata_data <= mock_read_data(read_addr_q);
                end else begin
                    read_wait_q <= read_wait_q - 1'b1;
                end
            end
        end
    end

    task automatic wait_grant(input int unsigned client, input int unsigned max_cycles);
        int unsigned waited;
        waited = 0;
        while (!client_grant[client] && waited < max_cycles) begin
            @(posedge clk);
            waited++;
        end
        if (!client_grant[client]) $fatal(1, "client %0d never granted", client);
    endtask

    task automatic wait_done(input int unsigned client, input int unsigned max_cycles);
        int unsigned waited;
        waited = 0;
        while (!done_seen_q[client] && waited < max_cycles) begin
            @(posedge clk);
            waited++;
        end
        if (!done_seen_q[client]) $fatal(1, "client %0d never completed", client);
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_arbiter);
        clk = 1'b0;
        reset = 1'b1;
        init_done = 1'b0;
        client_req = '0;
        client_we = '0;
        client_addr = '0;
        client_wdata_we = '0;
        client_wdata = '0;
        rdata_data = '0;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        // A pending request must not be granted before init_done -- the
        // native port's behavior is undefined until LiteDRAM finishes
        // init/calibration.
        client_addr[0] = types::sdram_word_addr_t'(24'h00_0005);
        client_req[0] = 1'b1;
        repeat (MAX_WAIT_CYCLES) begin
            @(posedge clk);
            if (client_grant != '0) $fatal(1, "client granted before init_done");
        end
        init_done = 1'b1;
        wait_grant(0, MAX_WAIT_CYCLES);
        wait_done(0, MAX_WAIT_CYCLES);
        client_req[0] = 1'b0;
        @(posedge clk);

        // All three request at once: confirm strict priority order 0 > 1 > 2,
        // and that each client's own fields reach the native port while
        // granted.
        client_addr[0] = types::sdram_word_addr_t'(24'h00_0001);
        client_we[0] = 1'b0;
        client_addr[1] = types::sdram_word_addr_t'(24'h00_0002);
        client_we[1] = 1'b1;
        client_wdata_we[1] = types::sdram_byte_en_t'(2'b01);
        client_wdata[1] = types::sdram_word_data_t'(16'h00a5);
        client_addr[2] = types::sdram_word_addr_t'(24'h00_0003);
        client_we[2] = 1'b0;
        client_req = 3'b111;

        wait_grant(0, MAX_WAIT_CYCLES);
        if (cmd_we !== 1'b0 || cmd_addr !== client_addr[0])
            $fatal(1, "client 0 cmd mismatch we=%0b addr=%0h", cmd_we, cmd_addr);
        wait_done(0, MAX_WAIT_CYCLES);
        if (rdata_seen_q !== mock_read_data(client_addr[0]))
            $fatal(1, "client 0 rdata mismatch %0h", rdata_seen_q);
        client_req[0] = 1'b0;
        @(posedge clk);
        if (client_grant[0]) $fatal(1, "client 0 grant did not release");

        wait_grant(1, MAX_WAIT_CYCLES);
        if (cmd_we !== 1'b1 || cmd_addr !== client_addr[1] || wdata_we !== client_wdata_we[1] ||
            wdata_data !== client_wdata[1])
            $fatal(1, "client 1 cmd/wdata mismatch we=%0b addr=%0h wwe=%0b wdata=%0h", cmd_we, cmd_addr, wdata_we,
                   wdata_data);
        wait_done(1, MAX_WAIT_CYCLES);
        client_req[1] = 1'b0;
        @(posedge clk);
        if (client_grant[1]) $fatal(1, "client 1 grant did not release");

        wait_grant(2, MAX_WAIT_CYCLES);
        if (cmd_we !== 1'b0 || cmd_addr !== client_addr[2])
            $fatal(1, "client 2 cmd mismatch we=%0b addr=%0h", cmd_we, cmd_addr);
        wait_done(2, MAX_WAIT_CYCLES);
        if (rdata_seen_q !== mock_read_data(client_addr[2]))
            $fatal(1, "client 2 rdata mismatch %0h", rdata_seen_q);
        client_req[2] = 1'b0;
        @(posedge clk);

        // Client 0 holds a standing request (simulating a multi-word row
        // fill re-requesting word after word) while client 1 has a single
        // pending write. Confirm client 1 gets served as soon as client 0
        // withdraws its request for the current word, rather than being
        // starved for an entire burst.
        client_addr[1] = types::sdram_word_addr_t'(24'h00_0004);
        client_wdata[1] = types::sdram_word_data_t'(16'h0042);
        client_req[1] = 1'b1;
        client_req[0] = 1'b1;
        wait_grant(0, MAX_WAIT_CYCLES);
        wait_done(0, MAX_WAIT_CYCLES);
        client_req[0] = 1'b0;
        wait_grant(1, MAX_WAIT_CYCLES);
        if (cmd_we !== 1'b1 || cmd_addr !== client_addr[1])
            $fatal(1, "interleave scenario: client 1 cmd mismatch we=%0b addr=%0h", cmd_we, cmd_addr);
        wait_done(1, MAX_WAIT_CYCLES);
        client_req[1] = 1'b0;

        $display("tb_sdram_arbiter: PASS");
        $finish;
    end
endmodule
