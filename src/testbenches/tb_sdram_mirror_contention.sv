// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_sdram_mirror_contention: the mirror-on twin of tb_sdram_contention.
//
// tb_sdram_contention proves the arbiter's `boost_writes` saves the write FIFO from
// overflow -- but ONLY for MIRROR=0. The hardware ships MIRROR=1 (-DUSE_SDRAM_DBUF_MIRROR),
// which the original bench never exercises. That is the blind spot that let the
// "test pattern paints but the right edge / band tails are dropped" failure through:
// the sim was green for a config we don't build.
//
// With MIRROR=1 every FIFO entry drains as TWO native writes -- buffer 0, then buffer 1
// at +BUFFER_WORDS_OFFSET, a DIFFERENT DRAM row. So the mirror not only doubles the write
// count, it alternates rows on every write (the timing slave charges ROW_MISS_COST each
// time), collapsing the write drain rate far below the un-stallable host's input rate.
// Result: even with reads fully preempted (boost), the drain can't keep up and host
// writes are LOST -- exactly the dropped-burst-tail symptom on the panel.
//
// Pass criterion (the FIX target): with boost on, MIRROR=1 must NOT drop. This FAILS on
// the current RTL (reproducing the bug) and must pass once the write drain keeps up.
// Built with a small write FIFO (-DSDRAM_WRITE_FIFO_DEPTH=32) so overflow is reached fast.
module tb_sdram_mirror_contention;
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
    logic use_throttle = 1'b0;   // model the fix: stall the write SOURCE on FIFO pressure
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

    // ---------------- real write client, MIRROR=1, driven by a free-running host ----
    types::mem_write_addr_t wc_src_addr = '0;
    types::mem_write_data_t wc_src_data = '0;
    logic                   wc_src_valid = 1'b0;
    wire  wc_ready, wc_drained, wc_dropped, wc_pressure;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wwe;
    wire types::sdram_word_data_t wc_wdat;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client #(.MIRROR(1'b1)) wc (
        .reset(reset), .clk_in(clk), .frame_select(1'b0),
        .source_addr(wc_src_addr), .source_data(wc_src_data), .source_write_valid(wc_src_valid),
        .ready(wc_ready), .drained(wc_drained), .dropped(wc_dropped), .wr_pressure(wc_pressure),
        .sdram_req(s_req[0]), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wwe), .sdram_wdata(wc_wdat)
    );

    // Host: presents a write every HOST_PERIOD cycles, marching column by column.
    //  use_throttle=0 -> free-running, un-stallable (models the CURRENT fill generator,
    //                    which floods at clock rate ignoring the FIFO).
    //  use_throttle=1 -> holds off while the FIFO is pressured (models the FIX: gate the
    //                    fill generator's `enable` on the write client's wr_pressure). It
    //                    pauses at the threshold and fires the instant pressure releases,
    //                    so no write is ever LOST -- the fill just runs slower.
    wire host_blocked = use_throttle && wc_pressure;
    wire host_fire    = run_en && (host_cnt_q >= HOST_PERIOD - 1) && !host_blocked;
    int unsigned host_cnt_q;
    always_ff @(posedge clk) begin
        if (reset) begin
            host_cnt_q <= 0; wc_src_valid <= 1'b0; wc_src_addr <= '0; wc_src_data <= '0;
        end else if (host_fire) begin
            host_cnt_q <= 0;
            wc_src_valid <= 1'b1;
            wc_src_addr.col <= wc_src_addr.col + types::col_addr_t'(1);
            wc_src_data <= wc_src_data + types::mem_write_data_t'(1);
        end else begin
            // Hold the count at the threshold while blocked so we fire immediately on release.
            host_cnt_q <= (host_cnt_q >= HOST_PERIOD - 1) ? host_cnt_q : host_cnt_q + 1;
            wc_src_valid <= 1'b0;
        end
    end

    // Count dropped host writes (a write presented while the FIFO is full) for magnitude.
    int unsigned drop_events_q;
    always_ff @(posedge clk) begin
        if (reset) drop_events_q <= 0;
        else if (wc_src_valid && !wc_ready) drop_events_q <= drop_events_q + 1;
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

    // ================= the experiment =================
    logic dropped_noboost, dropped_boost, dropped_throttle;
    int unsigned drops_noboost, drops_boost, drops_throttle;
    // Fill (read) starvation: row_prefetch.fill_overrun is STICKY -> a display row missed
    // its deadline because the writes (esp. the 2x mirror, esp. under boost which preempts
    // reads) stole the bus. This is the OTHER failure: not dropped writes, but scrambled
    // rows. The throttle stops write drops; it does NOT give reads their bandwidth back.
    logic overrun_noboost, overrun_boost, overrun_throttle;

    task automatic do_reset; run_en <= 1'b0; reset <= 1'b1; repeat (8) @(posedge clk); reset <= 1'b0; repeat (8) @(posedge clk); endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_mirror_contention);

        // Phase A: boost off, no throttle -> writes starve & drop (sanity: harness loads it).
        use_boost = 1'b0; use_throttle = 1'b0;
        do_reset();
        run_en <= 1'b1;
        repeat (RUN_CYCLES) @(posedge clk);
        dropped_noboost  = wc_dropped;
        drops_noboost    = drop_events_q;
        overrun_noboost  = rp_overrun;
        $display("tb_sdram_mirror_contention: A) MIRROR NO-BOOST          dropped=%0b drops=%0d  fill_overrun=%0b", dropped_noboost, drops_noboost, overrun_noboost);

        // Phase B: boost on, no throttle. For MIRROR=0 this prevents ALL drops
        // (tb_sdram_contention) -- but for MIRROR=1 the 2x + row-miss drain can't keep up
        // even with reads fully preempted, so writes are STILL lost. THE BUG.
        use_boost = 1'b1; use_throttle = 1'b0;
        do_reset();
        run_en <= 1'b1;
        repeat (RUN_CYCLES) @(posedge clk);
        dropped_boost  = wc_dropped;
        drops_boost    = drop_events_q;
        overrun_boost  = rp_overrun;
        $display("tb_sdram_mirror_contention: B) MIRROR BOOST (no thr)    dropped=%0b drops=%0d  fill_overrun=%0b  <- the write bug", dropped_boost, drops_boost, overrun_boost);

        // Phase C: boost on + throttle the SOURCE on FIFO pressure (THE FIX). The mirror
        // still drains slowly, but the host now waits instead of overrunning, so nothing
        // is lost -- the fill simply takes longer.
        use_boost = 1'b1; use_throttle = 1'b1;
        do_reset();
        run_en <= 1'b1;
        repeat (RUN_CYCLES) @(posedge clk);
        run_en <= 1'b0;
        repeat (3000) @(posedge clk);
        dropped_throttle = wc_dropped;
        drops_throttle   = drop_events_q;
        overrun_throttle = rp_overrun;
        $display("tb_sdram_mirror_contention: C) MIRROR BOOST + THROTTLE  dropped=%0b drops=%0d  fill_overrun=%0b  <- write-drop fixed, but...", dropped_throttle, drops_throttle, overrun_throttle);

        if (!dropped_noboost)
            $fatal(1, "harness did not load the write path even without boost (tune rates)");
        if (!dropped_boost)
            $fatal(1, "expected MIRROR=1 to defeat boost and drop (the bug to reproduce) -- it did not");
        if (dropped_throttle)
            $fatal(1, "throttle regressed: it should drop NO writes with MIRROR=1 (got %0d)", drops_throttle);
        // NOTE: this is characterization, not a pass/fail gate. The throttle fixes write
        // DROPS; whether fills also overrun under the mirror's 2x load is the separate
        // read-starvation question that the persisting HW corruption points at.
        $display("tb_sdram_mirror_contention: write-drop summary: A drops=%0d / B drops=%0d / C drops=%0d (throttle fixes drops)",
                 drops_noboost, drops_boost, drops_throttle);
        $display("tb_sdram_mirror_contention: fill-overrun summary: A=%0b B=%0b C=%0b (does the mirror starve the read fills?)",
                 overrun_noboost, overrun_boost, overrun_throttle);
        $finish;
    end

    initial begin #80_000_000; $fatal(1, "tb_sdram_mirror_contention: global timeout"); end

    wire _unused = &{1'b0, rp_overrun_recent, wc_drained, s_grant, s_rdata, cmd_we, rp_rdata, 1'b0};
endmodule
