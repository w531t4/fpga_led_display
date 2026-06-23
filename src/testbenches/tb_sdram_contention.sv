// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_sdram_contention: reproduces (and proves the fix for) the dropped-host-write
// failure that shows as PERSISTENT wrong pixels on hardware (write_client led[2]).
//
// The real sdram_write_client is driven by a FREE-RUNNING host (the ESP32 cannot be
// stalled mid-command -- it presents a byte every HOST_PERIOD cycles regardless of
// `ready`), while row_prefetch runs continuous fills through the real sdram_arbiter
// against a native-port slave that charges DRAM row-miss/refresh penalties. With reads
// at absolute priority the writes starve and the FIFO overflows -> a host byte is lost
// (`dropped`). The fix: the write client's hysteretic `wr_pressure` drives the arbiter's
// `boost_writes`, letting writes preempt the fill before the FIFO can overflow.
//
// Pass criterion: dropped WITHOUT boost, NOT dropped WITH boost. (Built with a small
// write FIFO via -DSDRAM_WRITE_FIFO_DEPTH=32 so overflow is reached quickly.)
module tb_sdram_contention;
    localparam int unsigned NUM_SIMPLE = 2;

    localparam int unsigned CAS_LAT       = 3;
    localparam int unsigned ROW_HIT_COST  = 1;
    localparam int unsigned ROW_MISS_COST = 9;
    localparam int unsigned REFRESH_EVERY = 600;
    localparam int unsigned REFRESH_COST  = 20;
    localparam int unsigned ROW_PERIOD    = 60;    // deadlines come fast -> fills nearly back-to-back
    localparam int unsigned HOST_PERIOD   = 6;     // host presents a write every 6 cycles, ready or not
    localparam int unsigned RUN_CYCLES    = 12000;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_en = 1'b0;
    logic use_boost = 1'b0;
    always #5 clk = ~clk;

    // ---------------- native port (arbiter <-> timing slave) ----------------
    wire        cmd_valid, cmd_we;
    wire [23:0] cmd_addr;
    logic       cmd_ready;
    wire        wdata_valid;
    wire  [1:0] wdata_we;
    wire [15:0] wdata_data;
    logic       wdata_ready;
    logic       rdata_valid;
    logic [15:0] rdata_data;
    wire        rdata_ready;

    // ---------------- row_prefetch (display read fill) ----------------
    types::row_subpanel_addr_t rp_row_addr = '0;
    types::brightness_level_t  rp_bmask    = '0;
    logic                      rp_row_latch = 1'b0;
    wire                       rp_req, rp_cmd_ready, rp_rvalid;
    wire types::sdram_word_addr_t rp_addr;
    wire types::sdram_word_data_t rp_rdata;
    wire                       rp_overrun, rp_overrun_recent;

    row_prefetch rp (
        .reset(reset), .clk_in(clk),
        .read_address('0), .read_clk_enable(1'b0), .read_data_out(),
        .row_address(rp_row_addr), .brightness_mask(rp_bmask), .row_latch(rp_row_latch),
        .frame_select(1'b0),
        .sdram_req(rp_req), .sdram_addr(rp_addr),
        .sdram_cmd_ready(rp_cmd_ready), .sdram_rvalid(rp_rvalid), .sdram_rdata(rp_rdata),
        .fill_overrun(rp_overrun), .fill_overrun_recent(rp_overrun_recent)
    );

    // ---------------- real write client driven by a free-running host ----------------
    types::mem_write_addr_t wc_src_addr = '0;
    types::mem_write_data_t wc_src_data = '0;
    logic                   wc_src_valid = 1'b0;
    wire  wc_ready, wc_drained, wc_dropped, wc_pressure;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wwe;
    wire types::sdram_word_data_t wc_wdat;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(1'b0),
        .source_addr(wc_src_addr), .source_data(wc_src_data), .source_write_valid(wc_src_valid),
        .ready(wc_ready), .drained(wc_drained), .dropped(wc_dropped), .wr_pressure(wc_pressure),
        .sdram_req(s_req[0]), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wwe), .sdram_wdata(wc_wdat)
    );

    // Free-running host: present a byte every HOST_PERIOD cycles regardless of wc_ready
    // (models the un-stallable ESP32 SPI master), marching column by column.
    int unsigned host_cnt_q;
    always_ff @(posedge clk) begin
        if (reset) begin
            host_cnt_q <= 0; wc_src_valid <= 1'b0; wc_src_addr <= '0; wc_src_data <= '0;
        end else if (run_en && host_cnt_q >= HOST_PERIOD - 1) begin
            host_cnt_q <= 0;
            wc_src_valid <= 1'b1;
            wc_src_addr.col <= wc_src_addr.col + types::col_addr_t'(1);
            wc_src_data <= wc_src_data + types::mem_write_data_t'(1);
        end else begin
            host_cnt_q <= host_cnt_q + 1;
            wc_src_valid <= 1'b0;
        end
    end

    // ---------------- arbiter (DUT) ----------------
    wire [NUM_SIMPLE-1:0] s_req;
    wire [NUM_SIMPLE-1:0] s_we    = {1'b0, 1'b1};                                // s1 unused, s0 write
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wwe};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdat};
    assign s_req[1] = 1'b0;                                                      // no copyframe here
    wire [NUM_SIMPLE-1:0] s_grant;
    wire types::sdram_word_data_t s_rdata;

    wire arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata;
    assign rp_cmd_ready = arb_rd_cmd_ready;
    assign rp_rvalid    = arb_rd_rvalid;
    assign rp_rdata     = arb_rd_rdata;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(1'b1),
        .boost_writes(use_boost & wc_pressure),
        .rd_req(rp_req), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    // ================= timing-accurate native-port slave =================
    function automatic int unsigned bank_of(input logic [23:0] a); bank_of = a[10:9]; endfunction
    function automatic int unsigned row_of (input logic [23:0] a); row_of  = a[23:11]; endfunction
    function automatic logic [15:0] def_data(input logic [23:0] a); def_data = a[15:0] ^ 16'h5a3c; endfunction

    logic [15:0] mem [logic [23:0]];
    int  open_row [4];
    int  busy_q, refresh_cnt, refresh_busy;
    int          rq_due  [$];
    logic [15:0] rq_data [$];
    longint      now_q;
    integer fi;

    wire ctrl_free = (busy_q == 0) && (refresh_busy == 0);
    always_comb begin cmd_ready = ctrl_free; wdata_ready = ctrl_free; end

    always_ff @(posedge clk) begin
        if (reset) begin
            busy_q <= 0; refresh_cnt <= 0; refresh_busy <= 0; now_q <= 0;
            rdata_valid <= 1'b0; rdata_data <= '0;
            for (fi = 0; fi < 4; fi++) open_row[fi] <= -1;
            rq_due.delete(); rq_data.delete();
        end else begin
            now_q <= now_q + 1;
            rdata_valid <= 1'b0;
            if (refresh_busy > 0) refresh_busy <= refresh_busy - 1;
            else if (refresh_cnt >= REFRESH_EVERY) begin
                refresh_cnt <= 0; refresh_busy <= REFRESH_COST;
                for (fi = 0; fi < 4; fi++) open_row[fi] <= -1;
            end else refresh_cnt <= refresh_cnt + 1;

            if (busy_q > 0) busy_q <= busy_q - 1;

            if (cmd_valid && cmd_ready) begin
                automatic int unsigned bk = bank_of(cmd_addr);
                automatic logic hit = (open_row[bk] == int'(row_of(cmd_addr)));
                busy_q <= (hit ? ROW_HIT_COST : ROW_MISS_COST) - 1;
                open_row[bk] <= int'(row_of(cmd_addr));
                if (cmd_we) begin
                    if (wdata_valid && wdata_ready) begin
                        automatic logic [15:0] cur = mem.exists(cmd_addr) ? mem[cmd_addr] : def_data(cmd_addr);
                        if (wdata_we[0]) cur[7:0]  = wdata_data[7:0];
                        if (wdata_we[1]) cur[15:8] = wdata_data[15:8];
                        mem[cmd_addr] = cur;
                    end
                end else begin
                    rq_due.push_back(int'(now_q) + CAS_LAT);
                    rq_data.push_back(mem.exists(cmd_addr) ? mem[cmd_addr] : def_data(cmd_addr));
                end
            end

            if (rq_due.size() > 0 && rq_due[0] <= int'(now_q)) begin
                rdata_valid <= 1'b1;
                rdata_data  <= rq_data[0];
                void'(rq_due.pop_front());
                void'(rq_data.pop_front());
            end
        end
    end

    // ================= display-row deadline cadence =================
    int unsigned dl_cnt_q;
    always_ff @(posedge clk) begin
        if (reset) begin dl_cnt_q <= 0; rp_row_latch <= 1'b0; rp_row_addr <= '0; rp_bmask <= '0; end
        else if (run_en && dl_cnt_q >= ROW_PERIOD - 1) begin
            dl_cnt_q <= 0;
            rp_row_latch <= 1'b1;
            rp_bmask <= types::brightness_level_t'(1);
            rp_row_addr <= rp_row_addr + types::row_subpanel_addr_t'(1);
        end else begin
            dl_cnt_q <= dl_cnt_q + 1;
            rp_row_latch <= 1'b0;
        end
    end

    // ================= read-integrity census =================
    // The pause/resume must not LOSE a read word: every read the model returns has to be
    // forwarded to row_prefetch (a dropped forward would corrupt/hang the fill). Count
    // model returns vs arbiter forwards; they must match after the fills drain.
    int reads_returned, reads_forwarded;
    always_ff @(posedge clk) begin
        if (reset) begin reads_returned <= 0; reads_forwarded <= 0; end
        else begin
            if (rdata_valid)    reads_returned  <= reads_returned + 1;
            if (arb_rd_rvalid)  reads_forwarded <= reads_forwarded + 1;
        end
    end

    // ================= the experiment =================
    logic dropped_noboost, dropped_boost;

    task automatic do_reset; run_en <= 1'b0; reset <= 1'b1; repeat (8) @(posedge clk); reset <= 1'b0; repeat (8) @(posedge clk); endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_contention);

        // Phase A: reads at absolute priority (boost off) -> writes should starve & drop.
        use_boost = 1'b0;
        do_reset();
        run_en <= 1'b1;
        repeat (RUN_CYCLES) @(posedge clk);
        dropped_noboost = wc_dropped;
        $display("tb_sdram_contention: NO-BOOST  dropped=%0b", dropped_noboost);

        // Phase B: boost_writes = wr_pressure -> writes preempt before overflow.
        use_boost = 1'b1;
        do_reset();
        run_en <= 1'b1;
        repeat (RUN_CYCLES) @(posedge clk);
        // Stop new deadlines/writes and let the in-flight fill drain.
        run_en <= 1'b0;
        repeat (3000) @(posedge clk);
        dropped_boost = wc_dropped;
        $display("tb_sdram_contention: BOOST     dropped=%0b  reads_returned=%0d reads_forwarded=%0d",
                 dropped_boost, reads_returned, reads_forwarded);

        if (!dropped_noboost)
            $fatal(1, "harness did not reproduce the overflow without boost (tune rates)");
        if (dropped_boost)
            $fatal(1, "FIX FAILED: writes still dropped WITH boost");
        if (reads_returned != reads_forwarded)
            $fatal(1, "READ WORD LOST across a pause: model returned %0d but only %0d forwarded",
                   reads_returned, reads_forwarded);
        $display("tb_sdram_contention: PASS (no-boost drops; boost: no drop AND no read word lost)");
        $finish;
    end

    initial begin #80_000_000; $fatal(1, "tb_sdram_contention: global timeout"); end

    wire _unused = &{1'b0, rp_overrun, rp_overrun_recent, wc_ready, wc_drained, s_grant, s_rdata, cmd_we, 1'b0};
endmodule
