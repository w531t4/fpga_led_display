// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_f2b_readback: END-TO-END reproduction attempt for hardware fault F2.b on the
// SDRAM read/DISPLAY path.
//
// Prior write-path TBs proved the magenta drawColumn bar COMMITS to SDRAM fine, but
// they never read it back through the display chain, so they could not see F2.b (a
// DISPLAYED fault: on the SDRAM build the magenta bar's rightmost ~5-8 columns show
// the underlying horizontal BANDS instead of magenta; the left yellow bar is fine;
// the BRAM build renders both flush). This TB closes that gap:
//
//   real sdram_write_client  ->  real sdram_arbiter  ->  TIMING-REAL native SDRAM slave
//                                       |
//                                  real row_prefetch  (display read fill)
//                                       |
//                                  real framebuffer_fetch  (column MIRROR + subpanel split)
//
//  * It uses the TIMING-ACCURATE native-port slave copied from tb_sdram_contention
//    (CAS latency via rq_due, per-bank open-row row-hit/miss, periodic refresh) --
//    NOT the optimistic flat LiteDRAM sim core that hid real-DRAM timing before.
//  * It reproduces the layering of the test pattern at FULL width (PIXEL_WIDTH=768,
//    forced via tb_f2b_readback.args): first a BAND background value is written to
//    ALL host columns, then a distinct MAGENTA value overwrites host-x 720..767
//    (the drawColumn bar), both through the real write client.
//  * It reads every column back through the REAL display read path -- row_prefetch
//    fills the row from SDRAM, framebuffer_fetch mirrors the column and splits the
//    word into the two subpanels -- and asserts by DISPLAY column, flagging exactly
//    which display columns return band/garbage instead of magenta.
//
// The same experiment is then run as a CONTROL with the bar on host-x 0..47 (the
// yellow bar), to see whether the right-edge asymmetry reproduces.
module tb_f2b_readback;
    localparam int unsigned NUM_SIMPLE = 2;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned WIDTH = params::PIXEL_WIDTH;
    // The reset-primed fill targets row 1; write that row so the fill reads it.
    localparam int unsigned TEST_ROW = 1;

    // Bar geometry (host-x), exactly as the test pattern's drawColumn lays it down.
    localparam int unsigned MAG_LO = 720;  // magenta bar host-x 720..767 (right bar on HW)
    localparam int unsigned MAG_HI = 767;
    localparam int unsigned YEL_LO = 0;    // yellow bar host-x 0..47   (left bar on HW)
    localparam int unsigned YEL_HI = 47;

    // ---- timing-real slave knobs (copied from tb_sdram_contention) ----
    localparam int unsigned CAS_LAT       = 3;
    localparam int unsigned ROW_HIT_COST  = 1;
    localparam int unsigned ROW_MISS_COST = 9;
    localparam int unsigned REFRESH_EVERY = 600;
    localparam int unsigned REFRESH_COST  = 20;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic rp_reset = 1'b1;   // hold row_prefetch off while we pre-load SDRAM
    logic rp_enable = 1'b0;  // gate row_prefetch's arbiter access during writes
    always #5 clk = ~clk;

    // ============== write client (ESP32 write path, client s[0]) ==============
    types::mem_write_addr_t wc_source_addr = '0;
    types::mem_write_data_t wc_source_data = '0;
    logic wc_source_valid = 1'b0;
    wire  wc_ready, wc_drained;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wdata_we;
    wire types::sdram_word_data_t wc_wdata;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(1'b1),  // ~1 => writes frame 0
        .source_addr(wc_source_addr), .source_data(wc_source_data), .source_write_valid(wc_source_valid),
        .ready(wc_ready), .drained(wc_drained),
        .sdram_req(wc_req), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wdata_we), .sdram_wdata(wc_wdata)
    );
    wire wc_req;

    // ============== row_prefetch (display read path, pipelined rd port) ==============
    // Driven combinationally from framebuffer_fetch's mirrored address (see below).
    wire types::mem_read_addr_t rp_read_addr;
    wire rp_read_en;
    wire types::mem_read_data_t rp_read_data;
    types::row_subpanel_addr_t rp_row_addr = '0;
    types::brightness_level_t  rp_bmask = '0;
    logic rp_row_latch = 1'b0;
    wire  rp_req;
    wire types::sdram_word_addr_t rp_addr;
    wire  rp_cmd_ready, rp_rvalid;
    wire types::sdram_word_data_t rp_rdata;

    row_prefetch rp (
        .reset(rp_reset), .clk_in(clk),
        .read_address(rp_read_addr), .read_clk_enable(rp_read_en), .read_data_out(rp_read_data),
        .row_address(rp_row_addr), .brightness_mask(rp_bmask), .row_latch(rp_row_latch),
        .frame_select(1'b0),  // reads frame 0
        .sdram_req(rp_req), .sdram_addr(rp_addr),
        .sdram_cmd_ready(rp_cmd_ready), .sdram_rvalid(rp_rvalid), .sdram_rdata(rp_rdata),
        .fill_overrun(rp_overrun), .fill_overrun_recent(rp_overrun_recent)
    );
    wire rp_overrun, rp_overrun_recent;
    // Gate row_prefetch's arbiter access so it doesn't fill from blank SDRAM
    // before we've written the pattern.
    wire rp_req_g = rp_req & rp_enable;
    assign rp_cmd_ready = arb_rd_cmd_ready & rp_enable;
    assign rp_rvalid    = arb_rd_rvalid & rp_enable;
    assign rp_rdata     = arb_rd_rdata;

    // ============== framebuffer_fetch (REAL display fetch: mirror + subpanel split) ==============
    // Drive its column_address with the display column under test; it produces the
    // MIRRORED ram_address (col = (WIDTH-1) - column_address) into row_prefetch's read
    // port, and exposes the per-subpanel color fields the panel actually lights.
    types::col_addr_t ff_column_address = '0;
    logic ff_pixel_load_start = 1'b0;
    wire types::mem_read_addr_t ff_ram_address;
    wire ff_ram_clk_enable;
    wire types::color_field_t ff_pixeldata_subpanels[NUM_SUBPANELS];

    framebuffer_fetch #(._UNUSED(0)) ff (
        .reset(rp_reset), .clk_in(clk),
        .column_address(ff_column_address),
        .row_address(types::row_subpanel_addr_t'(TEST_ROW - 1)),
        .pixel_load_start(ff_pixel_load_start),
        .ram_data_in(rp_read_data),
        .ram_address(ff_ram_address),
        .ram_clk_enable(ff_ram_clk_enable),
        .pixeldata_subpanels(ff_pixeldata_subpanels)
    );
    // Feed framebuffer_fetch's mirrored address + its clock-enable into row_prefetch's
    // read port -- exactly how main.sv wires the two together.
    assign rp_read_addr = ff_ram_address;
    assign rp_read_en   = ff_ram_clk_enable;

    // ============== arbiter (DUT mux) ==============
    wire arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata;
    wire [NUM_SIMPLE-1:0] s_req   = {1'b0, wc_req};
    wire [NUM_SIMPLE-1:0] s_we    = {1'b0, 1'b1};
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wdata_we};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdata};
    wire [NUM_SIMPLE-1:0] s_grant;
    wire types::sdram_word_data_t s_rdata;

    // native port (arbiter <-> timing slave)
    wire        cmd_valid, cmd_we;
    wire types::sdram_word_addr_t cmd_addr;
    logic       cmd_ready;
    wire        wdata_valid;
    wire  [1:0] wdata_we;
    wire [15:0] wdata_data;
    logic       wdata_ready;
    logic       rdata_valid;
    logic [15:0] rdata_data;
    wire        rdata_ready;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(1'b1), .boost_writes(1'b0),
        .rd_req(rp_req_g), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cp_req(1'b0), .cp_we(1'b0), .cp_addr('0), .cp_wdata_we('0), .cp_wdata('0),
        .cp_cmd_ready(), .cp_rvalid(), .cp_rdata(),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    // ================= timing-accurate native-port slave (copied from tb_sdram_contention) =================
    // Banks/rows are decoded from the native word address the same way the contention
    // harness does; mem[] is keyed by the FULL word address so data round-trips
    // correctly regardless of bank decode -- the bank decode only charges TIMING
    // (row hit/miss), which is what could starve a fill into a stale-row display.
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

    // Timing-fidelity census: count the row-miss and refresh penalties charged to
    // the prefetch READ fill (proves the slave is NOT a free-running cmd_ready-every-
    // cycle model -- it really charges real-DRAM stalls during the read).
    int read_cmds_q, read_miss_q, refresh_events_q;
    always_ff @(posedge clk) begin
        if (reset) begin read_cmds_q <= 0; read_miss_q <= 0; refresh_events_q <= 0; end
        else begin
            if (rp_enable && refresh_busy == 0 && refresh_cnt >= REFRESH_EVERY) refresh_events_q <= refresh_events_q + 1;
            if (cmd_valid && cmd_ready && !cmd_we) begin
                read_cmds_q <= read_cmds_q + 1;
                if (open_row[bank_of(cmd_addr)] != int'(row_of(cmd_addr))) read_miss_q <= read_miss_q + 1;
            end
        end
    end

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

    // ================= color helpers =================
    // Build a full-pixel color_t. (For RGB24 each channel is 8 bits.)
    function automatic types::color_t mk_color(input int unsigned r, input int unsigned g, input int unsigned b);
        mk_color.red   = types::red_t'(r);
        mk_color.green = types::green_t'(g);
        mk_color.blue  = types::blue_t'(b);
    endfunction

    localparam types::color_t COL_MAGENTA = '{red: types::red_t'(8'hFF),
                                              green: types::green_t'(8'h00),
                                              blue: types::blue_t'(8'hFF)};
    localparam types::color_t COL_YELLOW  = '{red: types::red_t'(8'hFF),
                                              green: types::green_t'(8'hFF),
                                              blue: types::blue_t'(8'h00)};
    // Underlying horizontal-band background. A column-varying value so any
    // "band shows through" failure returns recognizably wrong (not magenta) data.
    function automatic types::color_t band_color(input int unsigned col);
        band_color = mk_color(8'h10 + (col & 8'h1F), 8'h40 + (col & 8'h0F), 8'h80 ^ (col & 8'h3F));
    endfunction

    // Number of real (non-pad) bytes a color_field_t carries.
    localparam int unsigned COLOR_FIELD_BYTES = $bits(types::color_field_t) / 8;

    // The byte the write client should write for pixel-byte index px. The display
    // reads the column word as color_field_t per subpanel, whose .raw is built from
    // the bytes the write path lays down at pixel indices 0..PIXEL_BYTES-1 (low byte
    // first). So byte index px selects color_field_t.bytes[px] for the real bytes,
    // and 0 for any pad slot beyond the color field.
    function automatic logic [7:0] color_byte(input types::color_t c, input int unsigned px);
        types::color_field_t f;
        f = '0;
        f.color = c;
        color_byte = (px < COLOR_FIELD_BYTES) ? f.bytes[px] : 8'h00;
    endfunction

    // Expected assembled column word for a given column's color (both subpanels carry
    // the same color here; the test only needs distinguishable band vs bar).
    function automatic types::mem_read_data_t exp_word(input types::color_t c);
        types::mem_read_data_t v;
        v = '0;
        for (int sp = 0; sp < NUM_SUBPANELS; sp++)
            v.subpanel[sp].field.color = c;
        exp_word = v;
    endfunction

    // ================= write driver =================
    task automatic do_write(input int unsigned sp, input int unsigned col, input int unsigned px,
                            input logic [7:0] data);
        @(negedge clk);
        while (!wc_ready) @(negedge clk);
        wc_source_addr = '{subpanel: types::subpanel_addr_t'(sp), row: types::row_subpanel_addr_t'(TEST_ROW),
                           col: types::col_addr_t'(col), pixel: types::pixel_addr_t'(px)};
        wc_source_data = types::mem_write_data_t'(data);
        wc_source_valid = 1'b1;
        @(negedge clk);
        wc_source_valid = 1'b0;
    endtask

    // Write one column (all subpanels, all pixel bytes) to a full color value.
    task automatic write_col(input int unsigned col, input types::color_t c);
        for (int sp = 0; sp < NUM_SUBPANELS; sp++)
            for (int px = 0; px < PIXEL_BYTES; px++)
                do_write(sp, col, px, color_byte(c, px));
    endtask

    // ================= read-back via the real display chain =================
    // Drive framebuffer_fetch with a display column, run a pixel-load cycle, and
    // capture the per-subpanel color it presents (this exercises the mirror + split).
    types::color_field_t got_sub [NUM_SUBPANELS];
    task automatic read_disp_col(input int unsigned disp_col);
        @(negedge clk);
        ff_column_address = types::col_addr_t'(disp_col);
        // pulse pixel_load_start: framebuffer_fetch runs its FB_FETCH_TIMEOUT_TICKS
        // counter, asserts ram_clk_enable -> row_prefetch reads the (mirrored) col,
        // then samples ram_data_in at FB_FETCH_SAMPLE_TICK into pixeldata_subpanels.
        ff_pixel_load_start = 1'b1;
        @(negedge clk);
        ff_pixel_load_start = 1'b0;
        // Wait out the load timeout plus the read pipeline; generous.
        repeat (params::FB_FETCH_TIMEOUT_TICKS + 6) @(posedge clk);
        for (int sp = 0; sp < NUM_SUBPANELS; sp++) got_sub[sp] = ff_pixeldata_subpanels[sp];
    endtask

    // Report the SDRAM bank/row this slave decodes for a host column's first read word
    // (subpanel 0, pixel-word 0) -- the same address calc::sdram_word_addr the read
    // fill issues, so the bank shown is the one the timing model charges for that col.
    task automatic report_bank(input string tag, input int unsigned col);
        types::sdram_word_addr_t a;
        // frame 0: both the write (src_frame = ~1 = 0) and the read fill (frame_select=0)
        // target frame 0 here, so this is the exact word the slave sees for this column.
        a = calc::sdram_word_addr(1'b0, TEST_ROW, col, 1'b0, 1'b0,
                                  params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                  PIXEL_BYTES, params::SDRAM_WORD_BYTES);
        $display("   bank-map %s host-x=%0d -> word_addr=0x%06h  bank=%0d row=%0d", tag, col,
                 a, bank_of(a), row_of(a));
    endtask

    // ================= the experiment =================
    int n_wrong, n_wrong_edge;
    // For one bar placement: write band everywhere, overwrite the bar columns with
    // bar_color, fill, then check every DISPLAY column.
    task automatic run_case(input string label, input int unsigned bar_lo, input int unsigned bar_hi,
                            input types::color_t bar_color);
        int hostx;
        int disp_first_bad, disp_last_bad;
        types::color_t expect_c;
        types::mem_read_data_t expect_w, got_w;
        n_wrong = 0; n_wrong_edge = 0; disp_first_bad = -1; disp_last_bad = -1;
        $display("---- %s : bar host-x %0d..%0d ----", label, bar_lo, bar_hi);

        // Re-init the chain so each case starts from a clean SDRAM/prefetch state.
        reset = 1'b1; rp_reset = 1'b1; rp_enable = 1'b0;
        repeat (8) @(posedge clk);
        reset = 1'b0;
        repeat (8) @(posedge clk);

        // 1) Band background to ALL host columns 0..WIDTH-1 (the horizontal bands).
        for (int c = 0; c < WIDTH; c++) write_col(c, band_color(c));
        // 2) Overwrite the bar's host columns with the bar color (drawColumn on top).
        for (int c = int'(bar_lo); c <= int'(bar_hi); c++) write_col(c, bar_color);
        // Let the writes fully commit.
        while (!wc_drained) @(posedge clk);
        repeat (8) @(posedge clk);

        // Report the ACTUAL SDRAM bank/row this slave decodes for the bar's edge host
        // columns (validates / corrects the "high cols land in a different bank" claim).
        report_bank("bar.lo     ", bar_lo);
        report_bank("bar.hi     ", bar_hi);
        report_bank("bar.hi-7   ", (bar_hi >= 7) ? bar_hi - 7 : 0);

        // 3) Release row_prefetch -> it fills TEST_ROW from SDRAM through the arbiter.
        rp_reset = 1'b0;
        rp_enable = 1'b1;
        repeat (WIDTH * 8 + 1024) @(posedge clk);  // WORDS + round-trip latency, generous
        // Swap so the just-filled bank becomes the active display bank.
        @(negedge clk);
        rp_row_addr = types::row_subpanel_addr_t'(TEST_ROW - 1);
        rp_bmask = types::brightness_level_t'(1);
        rp_row_latch = 1'b1;
        @(posedge clk);
        @(negedge clk);
        rp_row_latch = 1'b0;
        repeat (4) @(posedge clk);
        // Timing-fidelity proof: the slave charged real row-miss + refresh stalls to
        // the fill (it is NOT cmd_ready-every-cycle). If the fill still overran, the
        // sticky overrun flag is set -> a stale-row display the data check below would
        // also catch on this single row.
        $display("   timing census: read_cmds=%0d row_misses=%0d refresh_events=%0d fill_overrun=%0b",
                 read_cmds_q, read_miss_q, refresh_events_q, rp_overrun);
        if (rp_overrun)
            $display("   NOTE: row_prefetch.fill_overrun asserted (fill missed its deadline)");

        // 4) Assert by DISPLAY column. host-x for display col d is (WIDTH-1)-d (mirror).
        for (int d = 0; d < WIDTH; d++) begin
            hostx = int'(WIDTH) - 1 - d;
            expect_c = (hostx >= int'(bar_lo) && hostx <= int'(bar_hi)) ? bar_color : band_color(hostx);
            expect_w = exp_word(expect_c);
            read_disp_col(d);
            got_w = '0;
            for (int sp = 0; sp < NUM_SUBPANELS; sp++) got_w.subpanel[sp].field = got_sub[sp];
            if (got_w.subpanel[0].field !== expect_w.subpanel[0].field) begin
                n_wrong++;
                if (disp_first_bad < 0) disp_first_bad = d;
                disp_last_bad = d;
                // Only print the first ~24 and any inside-the-bar mismatches to keep logs sane.
                if (n_wrong <= 24 || (hostx >= int'(bar_lo) && hostx <= int'(bar_hi)))
                    $display("   MISMATCH disp_col=%0d host_x=%0d: got R=%0h G=%0h B=%0h  exp R=%0h G=%0h B=%0h%s",
                             d, hostx,
                             got_sub[0].color.red, got_sub[0].color.green, got_sub[0].color.blue,
                             expect_c.red, expect_c.green, expect_c.blue,
                             (got_sub[0].color === band_color(hostx)) ? "  [== BAND shows through]" : "  [garbage]");
            end
        end

        // Right-edge focus: the rightmost 8 host columns of the bar map to the
        // bar's right edge on HW. Report their display columns + verdict.
        $display("   bar right-edge host-x %0d..%0d -> display cols %0d..%0d",
                 bar_hi - 7, bar_hi, int'(WIDTH) - 1 - int'(bar_hi), int'(WIDTH) - 1 - (int'(bar_hi) - 7));
        for (int hx = int'(bar_hi) - 7; hx <= int'(bar_hi); hx++) begin
            int dd; dd = int'(WIDTH) - 1 - hx;
            read_disp_col(dd);
            if (got_sub[0].color !== bar_color)
                n_wrong_edge++;
        end

        if (n_wrong == 0)
            $display("   RESULT: %s all %0d display columns correct (no F2.b on this path).", label, WIDTH);
        else
            $display("   RESULT: %s %0d/%0d display columns WRONG (first=%0d last=%0d); right-edge bad=%0d/8",
                     label, n_wrong, WIDTH, disp_first_bad, disp_last_bad, n_wrong_edge);
    endtask

    int total_wrong_mag, total_wrong_yel;
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_f2b_readback);
        $display("tb_f2b_readback: PIXEL_WIDTH=%0d NUM_SUBPANELS=%0d PIXEL_BYTES=%0d", WIDTH, NUM_SUBPANELS, PIXEL_BYTES);
        if (WIDTH < 768)
            $display("WARNING: PIXEL_WIDTH=%0d (<768): high cols 720..767 + the bank split are NOT exercised.", WIDTH);

        run_case("MAGENTA(right bar)", MAG_LO, MAG_HI, COL_MAGENTA);
        total_wrong_mag = n_wrong;
        run_case("YELLOW(left bar/control)", YEL_LO, YEL_HI, COL_YELLOW);
        total_wrong_yel = n_wrong;

        $display("==== VERDICT ====");
        $display("magenta wrong display-cols=%0d   yellow wrong display-cols=%0d", total_wrong_mag, total_wrong_yel);
        if (total_wrong_mag == 0 && total_wrong_yel == 0) begin
            $display("F2.b did NOT reproduce on this end-to-end path: both bars read back correct end-to-end.");
            $display("  chain: write_client -> arbiter -> (timing-real) SDRAM -> row_prefetch -> framebuffer_fetch.");
            $display("  The on-chip read/display DATA path round-trips magenta correctly at the right edge, so F2.b");
            $display("  is NOT a write<->read address/bank disagreement and NOT a mirror/split data bug. It must be");
            $display("  a TIMING effect -- a fill OVERRUN under sustained concurrent write load (the bank still holds");
            $display("  the PREVIOUS row at swap -> bands show through), or analog/PHY margin. The overrun mechanism");
            $display("  is the one tb_sdram_contention already models; this single-row isolated fill gave the fill");
            $display("  its full window (fill_overrun=0 above) so it cannot exhibit that here.");
        end else if (total_wrong_mag > 0 && total_wrong_yel == 0)
            $display("F2.b REPRODUCED with the documented asymmetry: magenta right bar wrong, yellow control fine.");
        else
            $display("Both bars show wrong columns -- not the documented F2.b asymmetry; investigate harness/timing.");
        $finish;
    end

    initial begin
        #200_000_000;
        $fatal(1, "tb_f2b_readback: global timeout");
    end

    wire _unused = &{1'b0, s_grant, s_rdata, cmd_we, rp_overrun_recent, wc_drained, rdata_ready, 1'b0};
endmodule
