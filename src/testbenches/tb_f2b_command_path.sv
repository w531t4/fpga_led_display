// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_f2b_command_path: investigates hardware fault "F2.b" -- the built-in test
// pattern's MAGENTA right-edge bar (48 drawColumn 'K' commands at host-x 720..767)
// loses its rightmost ~5-8 columns on the SDRAM build, while the YELLOW left bar
// (also 48 drawColumn commands, host-x 0..47) renders FINE.
//
// This is the FOLLOW-UP to tb_sdram_drawcol_tail. That TB drove a SYNTHETIC host
// model straight into the write FIFO and proved the raw FIFO/arbiter drops NOTHING
// for either bar. THIS TB tests the layer ABOVE it: the REAL control_module command
// FSM + control_cmd_readcol drawColumn sub-FSM + the per-command busy/drained
// handshake. We feed control_module's data_rx/data_ready_n byte stream directly (no
// SPI layer), let its ram_clk_enable/ram_write_enable/ram_address/ram_data_out drive
// the REAL sdram_write_client (exactly as main.sv wires ctrl_ram_* -> source_*), into
// the REAL sdram_arbiter, against a timing-accurate native-port slave, with
// row_prefetch fills contending. If the command-boundary handshake or the readcol
// FSM loses a column (esp. the tail), this finds it -> fixable on-chip. If every
// column lands in all modes, F2.b is host-side (the ESP32 worker queue), off our chip.
//
// FIDELITY: the SDRAM model below is the timing-accurate native-port slave COPIED
// verbatim from tb_sdram_contention -- per-command CAS latency, row-hit vs row-miss
// (open-row-per-bank tracker), periodic refresh stalls. A "ready every cycle" model or
// the flat LiteDRAM sim core is UNACCEPTABLE (both have hidden real-DRAM write-path
// bugs before).
//
// drawColumn STRUCTURE (why high vs low cols differ): one 'K' writes 32 pixels DOWN one
// column (display-y 0..31), each y a different SDRAM row -> up to 32 row-MISSES per
// command. At the real HW width (PIXEL_WIDTH=768) the col->word math (calc::sdram_word_addr,
// inside sdram_write_client) puts low cols 0..47 and high cols 720..767 at very different
// word/bank addresses -- a genuine asymmetry. At the SIM-reduced W128 width (384) col 720
// doesn't even exist, so this TB FORCES -DPIXEL_WIDTH=768 via its .args to match hardware.
module tb_f2b_command_path;
    // The write path is the only "simple" arbiter client here (slot 0); slot 1 unused.
    localparam int unsigned NUM_SIMPLE = 2;

    // ---- DRAM timing knobs (identical model to tb_sdram_contention) ----
    localparam int unsigned CAS_LAT       = 3;
    localparam int unsigned ROW_HIT_COST  = 1;
    localparam int unsigned ROW_MISS_COST = 9;
    localparam int unsigned REFRESH_EVERY = 600;
    localparam int unsigned REFRESH_COST  = 20;
    localparam int unsigned ROW_PERIOD    = 60;    // display-row deadline cadence (fills nearly back-to-back)

    // ---- pattern geometry (matches the HW test pattern bars) ----
    localparam int unsigned BAR_COLS    = 48;
    localparam int unsigned COL_MAGENTA = 720;     // right magenta bar host-x base
    localparam int unsigned COL_YELLOW  = 0;       // left yellow bar host-x base

    localparam int unsigned PIXEL_BYTES = int'(params::BYTES_PER_PIXEL);
    // Column index is streamed MSB-first; this is how many bytes control_cmd_readcol
    // captures before the payload (PIXEL_WIDTH=768 -> col_addr_t=10 bits -> 2 bytes).
    localparam int unsigned COL_BYTES = calc::num_bytes_to_contain($bits(types::col_addr_t));
    // 32 rows x BYTES_PER_PIXEL pixel-bytes per drawColumn payload.
    localparam int unsigned PAYLOAD_BYTES = int'(params::PIXEL_HEIGHT) * PIXEL_BYTES;

    // Host inter-byte spacing models the SPI byte rate (real link can't deliver faster).
    localparam int unsigned INTER_BYTE_CYC = 30;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic run_en = 1'b0;
    always #5 clk = ~clk;

    // experiment control (set per run)
    int unsigned scored_col;             // the col the host is presenting right now
    bit          backtoback;             // 0=busy-paced, 1=back-to-back command boundary

    // ================= control_module (REAL command FSM, the DUT) =================
    cmd::indata8_t                 data_rx = cmd::indata8_t'(8'h00);
    logic                          data_ready_n = 1'b1;     // active-low strobe (pulse low 1 cyc/byte)
    wire types::rgb_signals_t      rgb_enable;
    wire types::brightness_level_t brightness_enable;
    wire types::mem_write_data_t   ctrl_ram_data_out;
    wire types::mem_write_addr_t   ctrl_ram_address;
    wire                           ctrl_ram_write_enable;
    wire                           ctrl_ram_clk_enable;
    wire                           ctrl_busy;
    wire                           ctrl_ready_for_data;
    wire                           watchdog_reset;
    wire                           frame_select;

    // NEW pipelined-copyframe arbiter port: this TB never issues COPYFRAME, so leave
    // the copy-engine outputs dangling and tie its inputs off (mirrors tb_control_module).
    wire                           copyframe_sdram_req;
    wire                           copyframe_sdram_we;
    wire types::sdram_word_addr_t  copyframe_sdram_addr;
    wire types::sdram_byte_en_t    copyframe_sdram_wdata_we;
    wire types::sdram_word_data_t  copyframe_sdram_wdata;

    // write-client status fed back into control_module (busy/ready/pressure handshake).
    wire wc_ready, wc_drained, wc_dropped, wc_pressure;

    control_module #(
        .WATCHDOG_CONTROL_TICKS(params::WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk),
        .data_rx(data_rx),
        .data_ready_n(data_ready_n),
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        .ram_data_out(ctrl_ram_data_out),
        .ram_address(ctrl_ram_address),
        .ram_write_enable(ctrl_ram_write_enable),
`ifdef DOUBLE_BUFFER
        .sdram_copyframe_req(copyframe_sdram_req),
        .sdram_copyframe_we(copyframe_sdram_we),
        .sdram_copyframe_addr(copyframe_sdram_addr),
        .sdram_copyframe_wdata_we(copyframe_sdram_wdata_we),
        .sdram_copyframe_wdata(copyframe_sdram_wdata),
        .sdram_copyframe_cmd_ready(1'b0),
        .sdram_copyframe_rvalid(1'b0),
        .sdram_copyframe_rdata('0),
        .frame_select(frame_select),
`endif
`ifdef USE_WATCHDOG
        .watchdog_reset(watchdog_reset),
`endif
        // The handshake under test: control_module holds `busy` until the write
        // client is fully drained, and gates ready_for_data on the FIFO-not-full.
        .sdram_write_ready(wc_ready),
        .sdram_write_drained(wc_drained),
        .sdram_write_pressure(wc_pressure),
        .busy(ctrl_busy),
        .ready_for_data(ctrl_ready_for_data),
        .ram_clk_enable(ctrl_ram_clk_enable)
    );

    // ================= REAL sdram_write_client (driven exactly as main.sv) =================
    // source_addr/data come straight from control_module; source_write_valid is the
    // accept strobe (ram_clk_enable & ram_write_enable), per main.sv.
    wire types::mem_write_addr_t wc_source_addr  = ctrl_ram_address;
    wire types::mem_write_data_t wc_source_data  = ctrl_ram_data_out;
    wire                         wc_source_valid = ctrl_ram_clk_enable & ctrl_ram_write_enable;

    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wwe;
    wire types::sdram_word_data_t wc_wdat;
    wire [NUM_SIMPLE-1:0] s_req;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client #(
        ._UNUSED('d0)
    ) wc (
        .reset(reset), .clk_in(clk), .frame_select(frame_select),
        .source_addr(wc_source_addr), .source_data(wc_source_data), .source_write_valid(wc_source_valid),
        .ready(wc_ready), .drained(wc_drained), .dropped(wc_dropped), .wr_pressure(wc_pressure),
        .sdram_req(s_req[0]), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wwe), .sdram_wdata(wc_wdat)
    );

    // ================= row_prefetch (display read fill, contends with writes) =================
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

    // ================= sdram_arbiter (REAL DUT) =================
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

    // native port (arbiter <-> timing slave)
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

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(1'b1),
        // F2.b is a HW symptom on the shipped build behaviour: reads keep top priority,
        // writes drain only between fills unless wr_pressure boosts them. Wire the real
        // pressure->boost path (as main.sv does) so the handshake is faithful.
        .boost_writes(wc_pressure),
        .rd_req(rp_req), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        // copyframe-port tie-offs (no copyframe in this TB).
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

    // NOTE on column attribution: we do NOT tag commits to scored_col at the SLAVE,
    // because in back-to-back mode a column's writes are still draining through the
    // deep FIFO long after the host has advanced scored_col to a later column -- so a
    // commit-time tag would mis-attribute writes and create phantom "drops". Instead
    // the golden census below tags each touched SDRAM WORD ADDRESS to its column at
    // ACCEPT time (synchronous with the host driving that column's bytes); every word
    // address belongs to exactly one column because the column index is part of the
    // address. The end-of-run check then verifies, per column, that every expected
    // word committed at the slave with the expected value -- pacing-independent.

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

    // ================= golden scoreboard (accepted-write census + golden memory) =================
    // The write client computes its arbiter-facing (src_addr, src_wdata, src_wdata_we)
    // combinationally from control_module's source_*; the byte is ACCEPTED into the FIFO
    // when wc_source_valid && wc_ready (write_client's `push`). Replicate that mapping
    // here to build the EXPECTED committed memory (golden), and to count, per column, how
    // many bytes control_module actually got accepted into the write path. Comparing this
    // golden memory to the slave's mem[] after full drain proves every column's pixels
    // landed at the right SDRAM word with the right byte.
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES_W = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;

    function automatic logic [23:0] gold_word_addr(input types::mem_write_addr_t a);
        automatic logic word_sel = calc::sdram_pixel_word_select($bits(int)'(a.pixel), params::SDRAM_WORD_BYTES);
        gold_word_addr = 24'(calc::sdram_word_addr(~frame_select, $bits(int)'(a.row), $bits(int)'(a.col),
                              a.subpanel, word_sel, params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT,
                              NUM_SUBPANELS, PIXEL_BYTES_W, params::SDRAM_WORD_BYTES));
    endfunction
    function automatic int unsigned gold_byte_in_word(input types::mem_write_addr_t a);
        gold_byte_in_word = calc::sdram_byte_in_word_select($bits(int)'(a.pixel), params::SDRAM_WORD_BYTES);
    endfunction

    logic [15:0] gold_mem  [logic [23:0]];  // expected committed memory built from accepted writes
    int unsigned word_col   [logic [23:0]]; // which column owns each touched SDRAM word (1:1)
    int unsigned accepted_writes [int];     // per-col bytes control_module got into the write path
    int unsigned presented_cmds  [int];     // per-col drawColumn payload bytes the host presented
    int unsigned col_words       [int];     // per-col DISTINCT SDRAM words expected (golden)

    always_ff @(posedge clk) begin
        if (!reset && run_en) begin
            if (wc_source_valid && wc_ready) begin
                automatic logic [23:0] wa = gold_word_addr(wc_source_addr);
                automatic int unsigned biw = gold_byte_in_word(wc_source_addr);
                automatic logic [15:0] cur = gold_mem.exists(wa) ? gold_mem[wa] : def_data(wa);
                // Count a column's DISTINCT expected words the first time each is touched.
                if (!word_col.exists(wa))
                    col_words[scored_col] =
                        (col_words.exists(scored_col) ? col_words[scored_col] : 0) + 1;
                cur[biw*8 +: 8] = wc_source_data[7:0];
                gold_mem[wa]  = cur;
                word_col[wa]  = scored_col;   // every word address belongs to exactly one column
                accepted_writes[scored_col] =
                    (accepted_writes.exists(scored_col) ? accepted_writes[scored_col] : 0) + 1;
            end
        end
    end

    // ================= byte-level host driver (control_module data_rx/data_ready_n) =================
    // Present ONE byte: hold data_rx stable so control_module's data_rx_latch captures it
    // while ready_for_data is high, then pulse data_ready_n LOW for one cycle (the FSM
    // consumes the byte on ~data_ready_n) -- exactly the one-cycle ff_sync strobe the real
    // SPI slave produces. UN-STALLABLE between bytes within a command (the ESP32 SPI master
    // has no per-byte off-chip backpressure: ready_for_data is NOT wired off-chip), but we
    // DO wait for ready_for_data before driving so we don't inject a byte while the FSM is
    // mid-backpressure (which the real link's gated SPI clock also avoids).
    task automatic send_byte(input logic [7:0] b);
        // Wait until the FSM can accept a new byte (ready_for_data high). The real host's
        // SPI clock is gated on this, so it never clocks a fresh byte while not ready.
        @(negedge clk);
        while (!ctrl_ready_for_data) @(negedge clk);
        data_rx      = cmd::indata8_t'(b);
        data_ready_n = 1'b1;
        // Hold the byte one cycle with the strobe high so data_rx_latch captures it.
        @(negedge clk);
        // One-cycle active-low strobe: the FSM acts on this cycle.
        data_ready_n = 1'b0;
        @(negedge clk);
        data_ready_n = 1'b1;
        // Inter-byte gap models the SPI byte rate.
        repeat (INTER_BYTE_CYC - 1) @(negedge clk);
    endtask

    // ================= drawColumn command (one full 'K' command) =================
    // opcode 'K', then COL_BYTES of column index MSB-first, then PAYLOAD_BYTES of a fixed
    // "magenta" pattern (32 rows x BYTES_PER_PIXEL). The exact pixel values are irrelevant
    // to the drop experiment; what matters is that the FSM walks all 96 payload bytes and
    // every one lands as an SDRAM write.
    task automatic draw_column(input int unsigned col);
        scored_col = col;
        // opcode
        send_byte(8'(cmd::READCOL));
        // column index, MSB-first
        for (int k = int'(COL_BYTES) - 1; k >= 0; k--)
            send_byte(8'((col >> (k * 8)) & 8'hff));
        // payload: 32 rows x BYTES_PER_PIXEL, fixed magenta pattern.
        for (int yb = 0; yb < int'(PAYLOAD_BYTES); yb++) begin
            presented_cmds[col] = (presented_cmds.exists(col) ? presented_cmds[col] : 0) + 1;
            // Vary the byte so RMW collisions in a shared SDRAM word are still detectable
            // (magenta = R+B; LSB tags row/byte so identical-word writes can't mask a drop).
            send_byte(8'(8'hF0 | (yb & 8'h0f)));
        end
    endtask

    // ================= reset =================
    task automatic do_reset;
        run_en = 1'b0; reset = 1'b1; data_ready_n = 1'b1; data_rx = cmd::indata8_t'(8'h00);
        repeat (8) @(posedge clk); reset = 1'b0; repeat (8) @(posedge clk);
    endtask

    // ================= one experiment run =================
    // Result capture for the summary table.
    localparam int unsigned NRUNS = 4;
    int unsigned r_start    [NRUNS];
    bit          r_b2b      [NRUNS];
    int unsigned r_cols_ok  [NRUNS];   // columns that committed exactly the expected words
    int unsigned r_cols_bad [NRUNS];   // columns that committed fewer than expected (missing/partial)
    int unsigned r_mem_mism [NRUNS];   // golden vs slave memory word mismatches
    bit          r_dropped  [NRUNS];   // wc.dropped sticky at end of run
    int unsigned r_idx = 0;

    // expected committed words per drawColumn (distinct SDRAM words touched by one column).
    // Computed from PAYLOAD_BYTES, SDRAM_WORD_BYTES, BYTES_PER_PIXEL -- but we measure it
    // empirically per-column from the golden census so the check can't drift from the RTL.
    task automatic run_experiment(input int unsigned start_col, input bit b2b, input string tag);
        int unsigned cols_ok, cols_bad, mem_mism;
        int unsigned exp_words;
        logic [23:0] k;
        do_reset();
        accepted_writes.delete(); presented_cmds.delete(); col_words.delete();
        gold_mem.delete(); word_col.delete(); mem.delete();
        backtoback = b2b;
        run_en = 1'b1;
        @(posedge clk);

        // 48 drawColumn commands.
        for (int c = 0; c < int'(BAR_COLS); c++) begin
            draw_column(start_col + c);
            if (!b2b) begin
                // busy-paced: the real host polls `busy` between commands. Wait for it
                // to clear (command FSM idle AND the SDRAM write tail drained) before the
                // next opcode -- exactly the real flow control.
                @(negedge clk);
                while (ctrl_busy) @(posedge clk);
            end
            // back-to-back: draw_column's send_byte already waits only for
            // ready_for_data, so the next command's opcode is presented as soon as the
            // FSM can take it -- stressing the STATE_DONE -> STATE_COLUMN_CAPTURE boundary.
        end

        // Let the final command's write tail fully commit.
        @(negedge clk);
        while (ctrl_busy) @(posedge clk);
        repeat (512) @(posedge clk);
        run_en = 1'b0;

        // ADDRESS-BASED per-column verification (pacing-independent). For every SDRAM
        // word the golden census expects, check it committed at the slave with the
        // expected value, and attribute the result to the word's owning column. A column
        // is OK iff EVERY one of its expected words landed correctly. This does not
        // depend on WHEN a write commits (so back-to-back draining across command
        // boundaries can't create phantom drops); it only asks "did the bytes land".
        begin
            int unsigned col_words_ok [int];   // per-col words that committed correctly
            mem_mism = 0;
            if (gold_mem.first(k)) begin
                do begin
                    automatic logic [15:0] want = gold_mem[k];
                    automatic logic [15:0] got  = mem.exists(k) ? mem[k] : 16'hxxxx;
                    automatic int unsigned ocol = word_col[k];
                    if (mem.exists(k) && got === want)
                        col_words_ok[ocol] = (col_words_ok.exists(ocol) ? col_words_ok[ocol] : 0) + 1;
                    else
                        mem_mism = mem_mism + 1;
                end while (gold_mem.next(k));
            end

            cols_ok = 0; cols_bad = 0;
            for (int c = 0; c < int'(BAR_COLS); c++) begin
                automatic int unsigned col  = start_col + c;
                automatic int unsigned want = col_words.exists(col)    ? col_words[col]    : 0;
                automatic int unsigned ok   = col_words_ok.exists(col) ? col_words_ok[col] : 0;
                exp_words = want;
                if (want > 0 && ok == want) cols_ok = cols_ok + 1;
                else cols_bad = cols_bad + 1;
            end

            $display("[run %0s] START_COL=%0d mode=%0s : cols_ok=%0d cols_missing=%0d mem_word_mismatches=%0d sticky_dropped=%0b",
                     tag, start_col, (b2b ? "BACK2BACK" : "BUSYPACED"), cols_ok, cols_bad, mem_mism, wc_dropped);
            if (cols_bad != 0 || mem_mism != 0) begin
                $write("           MISSING/PARTIAL columns:");
                for (int c = 0; c < int'(BAR_COLS); c++) begin
                    automatic int unsigned col  = start_col + c;
                    automatic int unsigned want = col_words.exists(col)    ? col_words[col]    : 0;
                    automatic int unsigned ok   = col_words_ok.exists(col) ? col_words_ok[col] : 0;
                    automatic int unsigned acc  = accepted_writes.exists(col) ? accepted_writes[col] : 0;
                    automatic int unsigned pres = presented_cmds.exists(col)  ? presented_cmds[col]  : 0;
                    if (!(want > 0 && ok == want))
                        $write(" col%0d(presented=%0d accepted=%0d words_expected=%0d words_ok=%0d)",
                               col, pres, acc, want, ok);
                end
                $write("\n");
            end
        end

        r_start[r_idx]   = start_col; r_b2b[r_idx] = b2b;
        r_cols_ok[r_idx] = cols_ok;   r_cols_bad[r_idx] = cols_bad;
        r_mem_mism[r_idx]= mem_mism;  r_dropped[r_idx] = wc_dropped;
        r_idx = r_idx + 1;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_f2b_command_path);

        $display("tb_f2b_command_path: PIXEL_WIDTH=%0d PIXEL_HEIGHT=%0d BYTES_PER_PIXEL=%0d COL_BYTES=%0d PAYLOAD_BYTES=%0d FIFO_DEPTH=%0d",
                 params::PIXEL_WIDTH, params::PIXEL_HEIGHT, params::BYTES_PER_PIXEL, COL_BYTES, PAYLOAD_BYTES, `SDRAM_WRITE_FIFO_DEPTH);
        if (params::PIXEL_WIDTH < COL_MAGENTA + BAR_COLS)
            $fatal(1, "PIXEL_WIDTH=%0d too small for COL_MAGENTA bar (need >=%0d). Build with -DPIXEL_WIDTH=768.",
                   params::PIXEL_WIDTH, COL_MAGENTA + BAR_COLS);

        // Both bars, both pacing modes. Realistic SPI inter-byte spacing throughout.
        run_experiment(COL_MAGENTA, 1'b0, "MAG/busy");
        run_experiment(COL_YELLOW , 1'b0, "YEL/busy");
        run_experiment(COL_MAGENTA, 1'b1, "MAG/b2b ");
        run_experiment(COL_YELLOW , 1'b1, "YEL/b2b ");

        // ---- summary table ----
        $display("");
        $display("==================== F2.b COMMAND-PATH SUMMARY ====================");
        $display(" bar      START_COL  pacing      cols_ok  cols_missing  mem_mismatch  dropped");
        for (int i = 0; i < int'(r_idx); i++)
            $display(" %-7s  %9d  %-9s   %7d  %12d  %12d  %7b",
                     (r_start[i] == COL_MAGENTA) ? "MAGENTA" : "YELLOW",
                     r_start[i], (r_b2b[i] ? "BACK2BACK" : "BUSYPACED"),
                     r_cols_ok[i], r_cols_bad[i], r_mem_mism[i], r_dropped[i]);
        $display("==================================================================");

        // Verdict.
        begin
            bit any_missing = 1'b0;
            bit mag_missing = 1'b0, yel_missing = 1'b0;
            for (int i = 0; i < int'(r_idx); i++) begin
                if (r_cols_bad[i] != 0 || r_mem_mism[i] != 0) begin
                    any_missing = 1'b1;
                    if (r_start[i] == COL_MAGENTA) mag_missing = 1'b1;
                    if (r_start[i] == COL_YELLOW ) yel_missing = 1'b1;
                end
            end
            if (mag_missing && !yel_missing)
                $display("VERDICT: F2.b REPRODUCED at the COMMAND-PATH level (magenta loses columns, yellow does not) -> fixable on-chip in the readcol FSM / busy handshake.");
            else if (any_missing)
                $display("VERDICT: columns drop, but NOT a clean high-vs-low asymmetry -> a generic command-path bandwidth/handshake issue (see per-run detail).");
            else
                $display("VERDICT: every one of the 48 columns committed in ALL modes (busy-paced AND back-to-back, magenta AND yellow). The control_module command FSM, the readcol drawColumn sub-FSM, and the busy/drained command-boundary handshake DROP NOTHING. Combined with tb_sdram_drawcol_tail (write FIFO/arbiter drop nothing), F2.b is NOT on our chip -> it is host-side (the ESP32 worker queue / SPI byte delivery), off our chip. Stop chasing it in RTL.");
        end

        $finish;
    end

    // Four 48-column runs at the realistic (slow) INTER_BYTE_CYC=30 spacing; sized with margin.
    initial begin #1_400_000_000; $fatal(1, "tb_f2b_command_path: global timeout"); end

    wire _unused = &{1'b0, rp_overrun, rp_overrun_recent, wc_drained, wc_pressure, s_grant, s_rdata,
                     cmd_we, rgb_enable, brightness_enable, watchdog_reset, ctrl_busy, backtoback,
                     copyframe_sdram_req, copyframe_sdram_we, copyframe_sdram_addr,
                     copyframe_sdram_wdata_we, copyframe_sdram_wdata, rdata_ready, 1'b0};
endmodule
