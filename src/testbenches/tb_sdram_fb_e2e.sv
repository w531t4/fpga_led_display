// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_sdram_fb_e2e: end-to-end framebuffer data-correctness check that NO other
// test covers. Drives the REAL sdram_write_client -> ulx3s_litedram_wrapper (sim
// core) -> sdram_arbiter -> row_prefetch chain: writes a known pattern to a row
// via the write client (the ESP32 write path), lets row_prefetch fill that row
// from SDRAM, and verifies the display read port returns exactly what was
// written. Catches any write<->read address/data swizzle disagreement (the
// thing that would show as persistent wrong pixels), independent of PHY timing.
module tb_sdram_fb_e2e;
    localparam int unsigned NUM_SIMPLE = 2;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    localparam types::col_addr_t MID_COL = types::col_addr_t'(params::PIXEL_WIDTH / 2);
    // The reset-primed fill targets row 1; write that row so the fill reads it.
    localparam int unsigned TEST_ROW = 1;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic rp_reset = 1'b1;   // hold row_prefetch off while we pre-load SDRAM
    logic rp_enable = 1'b0;  // gate row_prefetch's arbiter access during writes

    // --- wrapper (sim core) native port ---
    wire        init_done, init_error, user_clk, user_rst;
    wire        sdram_clk, sdram_casn, sdram_cke, sdram_csn, sdram_rasn, sdram_wen;
    wire [12:0] sdram_a;
    wire  [1:0] sdram_ba, sdram_dqm;
    logic [15:0] sdram_d = '0;
    wire        lcmd_valid, lcmd_we, lwdata_valid, lrdata_valid;
    wire        lcmd_ready, lwdata_ready, lrdata_ready;
    wire [23:0] lcmd_addr;
    wire  [1:0] lwdata_we;
    wire [15:0] lwdata_data, lrdata_data;

    ulx3s_litedram_wrapper litedram (
        .clk(clk), .clk_shifted(clk), .reset(reset),
        .init_done(init_done), .init_error(init_error),
        .sdram_clk(sdram_clk), .sdram_a(sdram_a), .sdram_ba(sdram_ba), .sdram_casn(sdram_casn),
        .sdram_cke(sdram_cke), .sdram_csn(sdram_csn), .sdram_dqm(sdram_dqm), .sdram_d(sdram_d),
        .sdram_rasn(sdram_rasn), .sdram_wen(sdram_wen), .user_clk(user_clk), .user_rst(user_rst),
        .cmd_valid(lcmd_valid), .cmd_ready(lcmd_ready), .cmd_we(lcmd_we), .cmd_addr(lcmd_addr),
        .wdata_valid(lwdata_valid), .wdata_ready(lwdata_ready), .wdata_we(lwdata_we), .wdata_data(lwdata_data),
        .rdata_valid(lrdata_valid), .rdata_ready(lrdata_ready), .rdata_data(lrdata_data)
    );

    // --- write client (ESP32 write path, client s[0]) ---
    types::mem_write_addr_t wc_source_addr = '0;
    types::mem_write_data_t wc_source_data = '0;
    logic wc_source_valid = 1'b0;
    wire  wc_ready, wc_req, wc_drained;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wdata_we;
    wire types::sdram_word_data_t wc_wdata;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(1'b1),  // ~1 => writes frame 0
        .source_addr(wc_source_addr), .source_data(wc_source_data), .source_write_valid(wc_source_valid),
        .ready(wc_ready), .drained(wc_drained), .sdram_req(wc_req), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wdata_we), .sdram_wdata(wc_wdata)
    );

    // --- row_prefetch (display read path, pipelined rd port) ---
    types::mem_read_addr_t rp_read_addr = '0;
    logic rp_read_en = 1'b0;
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
        .sdram_cmd_ready(rp_cmd_ready), .sdram_rvalid(rp_rvalid), .sdram_rdata(rp_rdata)
    );
    // Gate row_prefetch's arbiter access so it doesn't fill from blank SDRAM
    // before we've written the pattern.
    wire rp_req_g = rp_req & rp_enable;
    assign rp_cmd_ready = arb_rd_cmd_ready & rp_enable;
    assign rp_rvalid    = arb_rd_rvalid & rp_enable;
    assign rp_rdata     = arb_rd_rdata;

    // --- arbiter ---
    wire arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata;
    wire [NUM_SIMPLE-1:0] s_req   = {1'b0, wc_req};
    wire [NUM_SIMPLE-1:0] s_we    = {1'b0, 1'b1};
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wdata_we};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdata};
    wire [NUM_SIMPLE-1:0] s_grant;
    wire types::sdram_word_data_t s_rdata;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(init_done),
        .rd_req(rp_req_g), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cmd_valid(lcmd_valid), .cmd_ready(lcmd_ready), .cmd_we(lcmd_we), .cmd_addr(lcmd_addr),
        .wdata_valid(lwdata_valid), .wdata_ready(lwdata_ready), .wdata_we(lwdata_we), .wdata_data(lwdata_data),
        .rdata_valid(lrdata_valid), .rdata_ready(lrdata_ready), .rdata_data(lrdata_data)
    );

    always #5 clk = ~clk;

    // Distinct byte per (subpanel,col,pixel) so any swizzle disagreement shows.
    function automatic logic [7:0] patt(input int unsigned sp, input int unsigned col, input int unsigned px);
        patt = 8'((col * 8 + sp * 4 + px) & 8'hFF) ^ 8'hA5;
    endfunction

    // Expected assembled column word built the same way the display union reads it:
    // raw byte index = sp*PIXEL_BYTES + px.
    function automatic types::mem_read_data_t exp_col(input int unsigned col);
        types::mem_read_data_t v;
        v = '0;
        for (int sp = 0; sp < NUM_SUBPANELS; sp++)
            for (int px = 0; px < PIXEL_BYTES; px++)
                v.raw[(sp*PIXEL_BYTES + px)*8 +: 8] = patt(sp, col, px);
        exp_col = v;
    endfunction

    task automatic do_write(input int unsigned sp, input int unsigned col, input int unsigned px);
        @(negedge clk);
        while (!wc_ready) @(negedge clk);
        wc_source_addr = '{subpanel: types::subpanel_addr_t'(sp), row: types::row_subpanel_addr_t'(TEST_ROW),
                           col: types::col_addr_t'(col), pixel: types::pixel_addr_t'(px)};
        wc_source_data = types::mem_write_data_t'(patt(sp, col, px));
        wc_source_valid = 1'b1;
        @(negedge clk);
        wc_source_valid = 1'b0;
    endtask

    task automatic check_col(input int unsigned col);
        @(negedge clk);
        rp_read_addr = '{row: '1, col: types::col_addr_t'(col)};
        rp_read_en = 1'b1;
        @(posedge clk);
        #1;
        if (rp_read_data !== exp_col(col))
            $fatal(1, "E2E mismatch col=%0d: got %h exp %h", col, rp_read_data, exp_col(col));
        @(negedge clk);
        rp_read_en = 1'b0;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_fb_e2e);
        repeat (8) @(posedge clk);
        reset = 1'b0;
        // Wait for the LiteDRAM sim core to finish init.
        while (!init_done) @(posedge clk);
        repeat (8) @(posedge clk);

        // Pre-load the SDRAM: write every byte of TEST_ROW via the write client.
        for (int col = 0; col < params::PIXEL_WIDTH; col++)
            for (int sp = 0; sp < NUM_SUBPANELS; sp++)
                for (int px = 0; px < PIXEL_BYTES; px++)
                    do_write(sp, col, px);
        // Let the writes fully commit (wait for the write client to drain, not a
        // fixed count -- robust to the FIFO depth).
        while (!wc_drained) @(posedge clk);
        repeat (8) @(posedge clk);

        // Release row_prefetch -> it fills TEST_ROW (1) into bank1 from SDRAM.
        rp_reset = 1'b0;
        rp_enable = 1'b1;
        // Give the pipelined fill time to complete (WORDS + latency, generous).
        repeat (params::PIXEL_WIDTH * 8 + 512) @(posedge clk);

        // Swap so bank1 (TEST_ROW data) becomes the active display bank.
        @(negedge clk);
        rp_row_addr = types::row_subpanel_addr_t'(TEST_ROW - 1);
        rp_bmask = types::brightness_level_t'(1);
        rp_row_latch = 1'b1;
        @(posedge clk);
        @(negedge clk);
        rp_row_latch = 1'b0;

        check_col(0);
        check_col(MID_COL);
        check_col(LAST_COL);

        $display("tb_sdram_fb_e2e: PASS (write client -> SDRAM -> row_prefetch round-trip correct)");
        $finish;
    end

    // Global timeout.
    initial begin
        #20_000_000;
        $fatal(1, "tb_sdram_fb_e2e: global timeout");
    end

    wire _unused = &{1'b0, init_error, user_clk, user_rst, sdram_clk, sdram_a, sdram_ba, sdram_casn,
                     sdram_cke, sdram_csn, sdram_dqm, sdram_rasn, sdram_wen, s_grant, s_rdata, 1'b0};
endmodule
