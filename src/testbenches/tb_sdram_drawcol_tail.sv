// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_sdram_drawcol_tail: investigates hardware fault "F2.b" -- the built-in test
// pattern's MAGENTA right-edge bar (48 drawColumn 'K' commands at host-x 720..767)
// loses its rightmost ~5-8 columns on the SDRAM build, while the YELLOW left bar
// (also 48 drawColumn commands, host-x 0..47) renders FINE. The asymmetry (high
// cols drop, low cols don't) is the mystery this TB tries to reproduce or rule out
// IN THE WRITE PATH.
//
// KEY STRUCTURAL FACT (why a column is row-miss-heavy, and why high vs low differ):
// drawColumn writes 32 pixels DOWN one column (display-y 0..31). Each y maps to a
// different scan_pos/subpanel and therefore a different SDRAM row -- one 'K' command
// is up to 32 row-MISSES, unlike the sequential row-hit bands. AND, at the real HW
// width (PIXEL_WIDTH=768), the column->address math (calc::sdram_word_addr) puts low
// cols 0..47 in SDRAM banks {0,2} and high cols 720..767 in banks {1,3} -- a genuine
// high/low asymmetry in which banks get hammered. (At the SIM-reduced W128 width of
// 384 that asymmetry vanishes and col 720 doesn't even exist, so this TB FORCES
// PIXEL_WIDTH=768 via its .args so the experiment matches hardware.)
//
// FIDELITY: the SDRAM model below is the timing-accurate native-port slave COPIED
// from tb_sdram_contention -- it charges per-command CAS latency, row-hit vs
// row-miss (precharge/activate) penalties via an open-row-per-bank tracker, and
// periodic refresh stalls. A flat "ready every cycle" model would defeat the whole
// point (the flat model has hidden real-DRAM write-path bugs on this project before).
//
// EXPERIMENT: run the SAME drawColumn host model at START_COL=720 (magenta) and
// START_COL=0 (yellow), sweeping the host inter-write spacing INTER_WRITE_CYC from a
// realistic SPI rate (~30 cyc/byte at 40MHz SPI vs 50MHz fabric) down to absurdly
// fast (8, 2). Report per-run: writes presented, writes dropped, and which columns
// lost a write. The host is UN-STALLABLE (presents the byte regardless of `ready`,
// like the real ESP32 SPI master); between columns it waits for wc.drained (the real
// host polls `busy` between commands).
module tb_sdram_drawcol_tail;
    localparam int unsigned NUM_SIMPLE = 2;

    // ---- DRAM timing knobs (identical model to tb_sdram_contention) ----
    localparam int unsigned CAS_LAT       = 3;
    localparam int unsigned ROW_HIT_COST  = 1;
    localparam int unsigned ROW_MISS_COST = 9;
    localparam int unsigned REFRESH_EVERY = 600;
    localparam int unsigned REFRESH_COST  = 20;
    localparam int unsigned ROW_PERIOD    = 60;    // display-row deadline cadence (fills nearly back-to-back)

    // ---- pattern geometry (matches the HW test pattern bars) ----
    localparam int unsigned BAR_COLS = 48;
    localparam int unsigned COL_MAGENTA = 720;     // right magenta bar host-x base
    localparam int unsigned COL_YELLOW  = 0;       // left yellow bar host-x base

    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES   = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_en = 1'b0;
    always #5 clk = ~clk;

    // ---- experiment control (set per run by the initial block) ----
    int unsigned inter_write_cyc = 30;   // host byte spacing for the current run
    int unsigned scored_col;             // the col the host model is presenting right now (for tagging drops)

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

    // ---------------- the REAL write client, driven by a drawColumn host model ----------------
    types::mem_write_addr_t wc_source_addr = '0;
    types::mem_write_data_t wc_source_data = '0;
    logic                   source_write_valid = 1'b0;
    wire  wc_ready, wc_drained, wc_dropped, wc_pressure;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wwe;
    wire types::sdram_word_data_t wc_wdat;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(1'b0),
        .source_addr(wc_source_addr), .source_data(wc_source_data), .source_write_valid(source_write_valid),
        .ready(wc_ready), .drained(wc_drained), .dropped(wc_dropped), .wr_pressure(wc_pressure),
        .sdram_req(s_req[0]), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wwe), .sdram_wdata(wc_wdat)
    );

    // ---------------- arbiter (real DUT) ----------------
    wire [NUM_SIMPLE-1:0] s_req;
    wire [NUM_SIMPLE-1:0] s_we    = {1'b0, 1'b1};                                // s1 unused, s0 write
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wwe};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdat};
    assign s_req[1] = 1'b0;                                                      // no copyframe-as-simple here
    wire [NUM_SIMPLE-1:0] s_grant;
    wire types::sdram_word_data_t s_rdata;

    wire arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata;
    assign rp_cmd_ready = arb_rd_cmd_ready;
    assign rp_rvalid    = arb_rd_rvalid;
    assign rp_rdata     = arb_rd_rdata;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(1'b1),
        // F2.b is a HW symptom on the shipped build (no write boost): reads keep
        // top priority, writes drain only between fills. Keep boost OFF here.
        .boost_writes(1'b0),
        .rd_req(rp_req), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        // NEW copyframe-port tie-offs (see tb_sdram_fb_e2e).
        .cp_req(1'b0), .cp_we(1'b0), .cp_addr('0), .cp_wdata_we('0), .cp_wdata('0),
        .cp_cmd_ready(), .cp_rvalid(), .cp_rdata(),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    // ================= timing-accurate native-port slave =================
    // (verbatim from tb_sdram_contention: open-row-per-bank, CAS latency, refresh.)
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
    // Continuous fills so host writes contend with reads exactly as on HW.
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

    // ================= scoreboard =================
    // A write is LOST iff it is presented while the FIFO is full (source_write_valid
    // && !ready). Count those, total presented writes, and tag which column was active.
    int unsigned presented_total;
    int unsigned dropped_total;
    int unsigned col_dropcount [int];   // per-col lost-write count (assoc array)
    bit          any_full_seen;

    always_ff @(posedge clk) begin
        if (!reset && run_en) begin
            if (source_write_valid) begin
                presented_total <= presented_total + 1;
                if (!wc_ready) begin
                    dropped_total <= dropped_total + 1;
                    // Assoc-array tally MUST be a blocking write (Verilator rejects an
                    // NBA to a dynamically-sized var); same convention the timing
                    // slave's `mem[...] =` uses. Only this TB process touches it.
                    col_dropcount[scored_col] = (col_dropcount.exists(scored_col) ? col_dropcount[scored_col] : 0) + 1;
                    any_full_seen <= 1'b1;
                end
            end
        end
    end

    // ================= drawColumn host model =================
    // Present the write sequence for ONE column: for display-y 0..PIXEL_HEIGHT-1 and
    // each pixel byte, drive wc_source_addr/data and pulse source_write_valid for one
    // cycle, spaced by inter_write_cyc. UN-STALLABLE: present regardless of wc_ready
    // (the real ESP32 SPI master has no per-byte off-chip backpressure).
    task automatic draw_column(input int unsigned col);
        scored_col = col;
        for (int y = 0; y < int'(params::PIXEL_HEIGHT); y++) begin
            for (int b = 0; b < int'(params::BYTES_PER_PIXEL); b++) begin
                @(negedge clk);
                wc_source_addr = '{
                    subpanel: types::subpanel_addr_t'((y >= int'(params::PIXEL_HALFHEIGHT)) ? 1 : 0),
                    row:      types::row_subpanel_addr_t'(y % int'(params::PIXEL_HALFHEIGHT)),
                    col:      types::col_addr_t'(col),
                    pixel:    types::pixel_addr_t'(b)
                };
                // Magenta = R+B (e.g. 0xFF on red/blue bytes); exact value is
                // irrelevant to the drop experiment, only that a byte is presented.
                wc_source_data = types::mem_write_data_t'(8'hF0 | b);
                source_write_valid = 1'b1;
                @(negedge clk);
                source_write_valid = 1'b0;
                // Inter-byte gap models the SPI byte rate.
                repeat (inter_write_cyc - 1) @(negedge clk);
            end
        end
    endtask

    // ================= one experiment run =================
    task automatic do_reset;
        run_en <= 1'b0; reset <= 1'b1; source_write_valid <= 1'b0;
        repeat (8) @(posedge clk); reset <= 1'b0; repeat (8) @(posedge clk);
    endtask

    // Result capture for the summary table.
    localparam int unsigned NRUNS = 6;
    int unsigned r_start [NRUNS];
    int unsigned r_iwc   [NRUNS];
    int unsigned r_pres  [NRUNS];
    int unsigned r_drop  [NRUNS];
    int unsigned r_ncols [NRUNS];   // # distinct columns that lost a write
    bit          r_stick [NRUNS];   // wc.dropped sticky latch at end of run
    int unsigned r_idx = 0;

    task automatic run_experiment(input int unsigned start_col, input int unsigned iwc, input string tag);
        int unsigned ncols;
        do_reset();
        presented_total = 0; dropped_total = 0; any_full_seen = 1'b0;
        col_dropcount.delete();
        inter_write_cyc = iwc;
        run_en <= 1'b1;
        @(posedge clk);
        // 48 drawColumn commands; between columns wait for the client to fully drain
        // (the real host polls `busy` -- drained -- between commands).
        for (int c = 0; c < int'(BAR_COLS); c++) begin
            draw_column(start_col + c);
            // Settle, then wait for drain so the next command starts clean.
            @(negedge clk);
            while (!wc_drained) @(posedge clk);
        end
        // Let any in-flight write finish.
        repeat (64) @(posedge clk);
        run_en <= 1'b0;

        ncols = col_dropcount.size();
        $display("[run %0s] START_COL=%0d INTER_WRITE_CYC=%0d : presented=%0d dropped=%0d cols_losing=%0d sticky=%0b",
                 tag, start_col, iwc, presented_total, dropped_total, ncols, wc_dropped);
        if (dropped_total != 0) begin
            int unsigned k;
            $write("           lost-write columns:");
            if (col_dropcount.first(k))
                do $write(" %0d(x%0d)", k, col_dropcount[k]); while (col_dropcount.next(k));
            $write("\n");
        end

        r_start[r_idx] = start_col; r_iwc[r_idx] = iwc;
        r_pres[r_idx]  = presented_total; r_drop[r_idx] = dropped_total;
        r_ncols[r_idx] = ncols; r_stick[r_idx] = wc_dropped;
        r_idx = r_idx + 1;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_drawcol_tail);

        $display("tb_sdram_drawcol_tail: PIXEL_WIDTH=%0d PIXEL_HEIGHT=%0d BYTES_PER_PIXEL=%0d FIFO_DEPTH=%0d",
                 params::PIXEL_WIDTH, params::PIXEL_HEIGHT, params::BYTES_PER_PIXEL, `SDRAM_WRITE_FIFO_DEPTH);
        if (params::PIXEL_WIDTH < COL_MAGENTA + BAR_COLS)
            $fatal(1, "PIXEL_WIDTH=%0d too small for COL_MAGENTA bar (need >=%0d). Build with -DPIXEL_WIDTH=768.",
                   params::PIXEL_WIDTH, COL_MAGENTA + BAR_COLS);

        // Realistic SPI rate first (the only rate that matters for the F2.b verdict),
        // then progressively faster to find the threshold (if any).
        run_experiment(COL_MAGENTA, 30, "MAG@30");
        run_experiment(COL_YELLOW , 30, "YEL@30");
        run_experiment(COL_MAGENTA,  8, "MAG@8 ");
        run_experiment(COL_YELLOW ,  8, "YEL@8 ");
        run_experiment(COL_MAGENTA,  2, "MAG@2 ");
        run_experiment(COL_YELLOW ,  2, "YEL@2 ");

        // ---- summary table ----
        $display("");
        $display("==================== F2.b WRITE-PATH SUMMARY ====================");
        $display(" bar      START_COL  INTER_WRITE_CYC  presented  dropped  cols_lost  sticky");
        for (int i = 0; i < int'(r_idx); i++)
            $display(" %-7s  %9d  %15d  %9d  %7d  %9d  %6b",
                     (r_start[i] == COL_MAGENTA) ? "MAGENTA" : "YELLOW",
                     r_start[i], r_iwc[i], r_pres[i], r_drop[i], r_ncols[i], r_stick[i]);
        $display("================================================================");

        // Verdict: did the realistic-rate (iwc=30) magenta run drop where yellow didn't?
        begin
            bit mag30_drop = 1'b0, yel30_drop = 1'b0;
            for (int i = 0; i < int'(r_idx); i++) begin
                if (r_iwc[i] == 30 && r_start[i] == COL_MAGENTA && r_drop[i] != 0) mag30_drop = 1'b1;
                if (r_iwc[i] == 30 && r_start[i] == COL_YELLOW  && r_drop[i] != 0) yel30_drop = 1'b1;
            end
            if (mag30_drop && !yel30_drop)
                $display("VERDICT: F2.b REPRODUCED in the write path at realistic SPI rate (magenta tail drops, yellow does not).");
            else if (mag30_drop && yel30_drop)
                $display("VERDICT: writes drop at realistic rate for BOTH bars -> a generic write-bandwidth limit, NOT the high-vs-low F2.b asymmetry.");
            else begin
                $display("VERDICT: NO drops at realistic SPI rate (iwc=30) for either bar -> F2.b is NOT in the SDRAM write path");
                $display("         (the deep write FIFO absorbs each 96-byte drawColumn burst). The dropped magenta tail must originate");
                $display("         elsewhere: the readcol 'K' FSM / command-boundary `busy` handling, or the host side. (Faster-rate rows");
                $display("         show how far the write path is from dropping.)");
            end
        end

        $finish;
    end

    // Generous: six 48-column runs at the realistic (slow) iwc=30 spacing cost ~1.4ms
    // of sim time each, so the whole sweep needs hundreds of ms. Sized with margin.
    initial begin #900_000_000; $fatal(1, "tb_sdram_drawcol_tail: global timeout"); end

    wire _unused = &{1'b0, rp_overrun, rp_overrun_recent, wc_drained, wc_pressure, s_grant, s_rdata, cmd_we, 1'b0};
endmodule
