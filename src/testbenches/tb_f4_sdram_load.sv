// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// =============================================================================
// tb_f4_sdram_load -- verifies row_prefetch KEEPS UP (no genuine fill underrun)
// under the live-mode SDRAM load (copyframe + writes + per-frame swaps) on the
// TIMING-REAL SDRAM model (per-bank row-hit/miss cost + periodic refresh = real
// native-port backpressure the optimistic core can't produce). Real scan cadence
// comes from instantiating the actual matrix_scan on clk_matrix; the read port is
// tied off (the fill/deadline mechanism is driven by row_latch/row_address).
//
// NOTE on the check: row_prefetch's own `fill_overrun` flag FALSE-FIRES, because
// matrix_scan's row_latch is a clk_matrix pulse = 2 clk_root cycles, so on the 2nd
// cycle of the deadline the bank has already swapped and fill_done is legitimately
// 0. (That same 2-cycle crossing exists in main.sv, so led[2] is unreliable on the
// board too -- a separate bug.) This test therefore samples fill_done at the
// deadline's RISING edge only, which is the genuine "did the next row fill in time"
// condition. Requires the timing model (tb_f4_sdram_load.args: -DSDRAM_SIM_TIMING_MODEL).
// =============================================================================
module tb_f4_sdram_load;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES   = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned BUFFER_WORDS =
        calc::num_sdram_buffer_words(params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                     PIXEL_BYTES, params::SDRAM_WORD_BYTES);

    logic clk = 1'b0;            // clk_root
    logic reset = 1'b1;
    always #5 clk = ~clk;

    wire clk_matrix;
    clock_divider #(.CLK_DIV_COUNT(params::DIVIDE_CLK_BY_X_FOR_MATRIX))
        clkdiv (.reset(reset), .clk_in(clk), .clk_out(clk_matrix));

    logic frame_select = 1'b0;  // toggles per "frame" (mimics the live swap)

    // ---- SDRAM core: timing-real model ----
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

    // ---- real scan engine (drives the fill-deadline cadence) ----
    wire types::col_addr_t          column_address;
    wire types::row_subpanel_addr_t row_address, row_address_active;
    wire                            clk_pixel_load, clk_pixel, row_latch, output_enable;
    wire types::brightness_level_t  brightness_mask;

    matrix_scan ms (
        .reset(reset), .clk_in(clk_matrix),
        .column_address(column_address), .row_address(row_address), .row_address_active(row_address_active),
        .clk_pixel_load(clk_pixel_load), .clk_pixel(clk_pixel), .row_latch(row_latch),
        .output_enable(output_enable), .brightness_mask(brightness_mask)
    );

    // ---- row_prefetch (display fill), arbiter rd client ----
    wire  rp_req, rp_fill_overrun, rp_fill_overrun_recent;
    wire types::sdram_word_addr_t rp_addr;
    wire  arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata, rp_read_data;

    row_prefetch rp (
        .reset(reset), .clk_in(clk),
        .read_address('0), .read_clk_enable(1'b0), .read_data_out(rp_read_data),
        .row_address(row_address), .brightness_mask(brightness_mask), .row_latch(row_latch),
        .frame_select(frame_select),
        .sdram_req(rp_req), .sdram_addr(rp_addr),
        .sdram_cmd_ready(arb_rd_cmd_ready), .sdram_rvalid(arb_rd_rvalid), .sdram_rdata(arb_rd_rdata),
        .fill_overrun(rp_fill_overrun), .fill_overrun_recent(rp_fill_overrun_recent)
    );

    // ---- copyframe (carry-forward), arbiter cp client ----
    logic cf_enable = 1'b0;
    wire  cf_req, cf_we, cf_cmd_ready, cf_rvalid, cf_done;
    wire types::sdram_word_addr_t cf_addr;
    wire types::sdram_byte_en_t   cf_wdata_we;
    wire types::sdram_word_data_t cf_wdata, cf_rdata;

    control_cmd_copyframe cf (
        .reset(reset), .enable(cf_enable), .clk(clk), .frame_select(frame_select),
        .sdram_req(cf_req), .sdram_we(cf_we), .sdram_addr(cf_addr),
        .sdram_wdata_we(cf_wdata_we), .sdram_wdata(cf_wdata),
        .sdram_cmd_ready(cf_cmd_ready), .sdram_rvalid(cf_rvalid), .sdram_rdata(cf_rdata),
        .done(cf_done)
    );

    // ---- write client (READRECT-style host writes), arbiter simple client 0 ----
    types::mem_write_addr_t wc_source_addr = '0;
    types::mem_write_data_t wc_source_data = '0;
    logic wc_source_valid = 1'b0;
    wire  wc_ready, wc_req, wc_drained;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wdata_we;
    wire types::sdram_word_data_t wc_wdata;

    localparam int unsigned NUM_SIMPLE = 2;
    wire [NUM_SIMPLE-1:0] s_req  = {1'b0, wc_req};
    wire [NUM_SIMPLE-1:0] s_we   = {1'b0, 1'b1};
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wdata_we};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdata};
    wire [NUM_SIMPLE-1:0] s_grant, s_done;
    wire types::sdram_word_data_t s_rdata;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(frame_select),
        .source_addr(wc_source_addr), .source_data(wc_source_data), .source_write_valid(wc_source_valid),
        .ready(wc_ready), .drained(wc_drained), .sdram_req(wc_req), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wdata_we), .sdram_wdata(wc_wdata)
    );

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(init_done), .boost_writes(1'b0),
        .rd_req(rp_req), .rd_addr(rp_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cp_req(cf_req), .cp_we(cf_we), .cp_addr(cf_addr), .cp_wdata_we(cf_wdata_we), .cp_wdata(cf_wdata),
        .cp_cmd_ready(cf_cmd_ready), .cp_rvalid(cf_rvalid), .cp_rdata(cf_rdata),
        .cmd_valid(lcmd_valid), .cmd_ready(lcmd_ready), .cmd_we(lcmd_we), .cmd_addr(lcmd_addr),
        .wdata_valid(lwdata_valid), .wdata_ready(lwdata_ready), .wdata_we(lwdata_we), .wdata_data(lwdata_data),
        .rdata_valid(lrdata_valid), .rdata_ready(lrdata_ready), .rdata_data(lrdata_data)
    );

    // ---- LOAD: copyframe re-triggered continuously (worst-case live SDRAM load) ----
    initial begin : cf_loader
        @(negedge reset);
        while (!init_done) @(posedge clk);
        forever begin
            cf_enable = 1'b1;
            @(posedge clk);
            while (!cf_req) @(posedge clk);
            cf_enable = 1'b0;
            while (!cf_done) @(posedge clk);
        end
    end

    // ---- LOAD: write client streams a chunk of the back buffer repeatedly ----
    initial begin : wc_loader
        @(negedge reset);
        while (!init_done) @(posedge clk);
        forever begin
            for (int unsigned c = 0; c < 16; c++)
                for (int sp = 0; sp < NUM_SUBPANELS; sp++)
                    for (int px = 0; px < PIXEL_BYTES; px++) begin
                        @(negedge clk);
                        while (!wc_ready) @(negedge clk);
                        wc_source_addr = '{subpanel: types::subpanel_addr_t'(sp), row: types::row_subpanel_addr_t'(3),
                                           col: types::col_addr_t'(c), pixel: types::pixel_addr_t'(px)};
                        wc_source_data = types::mem_write_data_t'(8'hC3 ^ c);
                        wc_source_valid = 1'b1;
                        @(negedge clk);
                        wc_source_valid = 1'b0;
                    end
            repeat (200) @(negedge clk);
        end
    end

    // ---- LOAD: frame_select toggle (~ per frame) ----
    initial begin : fsel_toggler
        @(negedge reset);
        while (!init_done) @(posedge clk);
        forever begin
            repeat (60000) @(posedge clk);
            @(negedge clk);
            frame_select = ~frame_select;
        end
    end

    // ---- the check: at each fill-deadline RISING edge, the next row must be filled ----
    wire deadline = row_latch && (brightness_mask == types::brightness_level_t'(1));
    logic prev_deadline = 1'b0;
    logic seen_fill = 1'b0;          // skip startup (before the first fill completes)
    int unsigned deadlines = 0;
    int unsigned underruns = 0;
    always @(posedge clk) begin
        if (rp.fill_done_q) seen_fill <= 1'b1;
        if (deadline && !prev_deadline && seen_fill) begin
            deadlines <= deadlines + 1;
            if (!rp.fill_done_q) underruns <= underruns + 1;   // genuine underrun
        end
        prev_deadline <= deadline;
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_f4_sdram_load);
        repeat (8) @(posedge clk);
        reset = 1'b0;
        while (!init_done) @(posedge clk);
        // sustained live load over many fill deadlines (~21k cyc/deadline)
        repeat (1_000_000) @(posedge clk);

        if (deadlines == 0)
            $error("tb_f4_sdram_load: inconclusive -- no fill deadlines observed");
        else if (underruns == 0)
            $display("tb_f4_sdram_load: PASS -- row_prefetch kept up under live load (%0d deadlines, 0 underruns)", deadlines);
        else
            $error("tb_f4_sdram_load: FAIL -- prefetch underran on %0d/%0d fill deadlines under live load", underruns, deadlines);
        $finish;
    end

    initial begin
        #40_000_000;
        $fatal(1, "tb_f4_sdram_load: global timeout");
    end

    wire _unused = &{1'b0, init_error, user_clk, user_rst, sdram_clk, sdram_a, sdram_ba, sdram_casn,
                     sdram_cke, sdram_csn, sdram_dqm, sdram_rasn, sdram_wen, s_grant, s_rdata,
                     column_address, row_address_active, clk_pixel_load, clk_pixel, output_enable,
                     rp_read_data, arb_rd_rdata, wc_drained, rp_fill_overrun, rp_fill_overrun_recent, 1'b0};
endmodule
