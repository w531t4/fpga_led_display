// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// tb_sdram_dbuf_mirror: reproduces the persistent moving-text TRAIL and proves the
// double-buffer write-mirror fix.
//
// The host (ESPHome display_layout) is a delta-only persistent-canvas renderer: each
// frame it writes ONLY the changed regions to the back buffer and relies on the ESP32
// driver's copyFrame to keep both SDRAM buffers identical. On real DRAM copyframe is too
// slow and gets raced/dropped, so the buffers desync and stale pixels survive where
// content moved. This bench replays exactly that -- delta writes to the back buffer,
// frame_select toggle, NO copyframe -- through the real sdram_write_client + sdram_arbiter,
// recording every committed SDRAM write, then checks the displayed (front) buffer.
//
//   without -DUSE_SDRAM_DBUF_MIRROR: an old glyph position survives in the buffer that
//     was never redrawn there -> TRAIL reproduced (asserted present).
//   with    -DUSE_SDRAM_DBUF_MIRROR: every write lands in BOTH buffers -> no desync,
//     no trail (asserted absent).
module tb_sdram_dbuf_mirror;
    localparam int unsigned NUM_SIMPLE = 2;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam logic [7:0] GLYPH = 8'hAB;
    localparam int unsigned ROW = 1, OLD_COL = 10, MID_COL = 20, NEW_COL = 30;

    logic clk = 1'b0;
    logic reset = 1'b1;
    logic frame_select = 1'b0;
    always #5 clk = ~clk;

    // --- write client (host write path) ---
    types::mem_write_addr_t wc_src_addr = '0;
    types::mem_write_data_t wc_src_data = '0;
    logic wc_src_valid = 1'b0;
    wire wc_ready, wc_drained, wc_dropped, wc_pressure;
    wire types::sdram_word_addr_t wc_addr;
    wire types::sdram_byte_en_t   wc_wwe;
    wire types::sdram_word_data_t wc_wdat;
    wire [NUM_SIMPLE-1:0] s_done;

    sdram_write_client wc (
        .reset(reset), .clk_in(clk), .frame_select(frame_select),
        .source_addr(wc_src_addr), .source_data(wc_src_data), .source_write_valid(wc_src_valid),
        .ready(wc_ready), .drained(wc_drained), .dropped(wc_dropped), .wr_pressure(wc_pressure),
        .sdram_req(s_req[0]), .sdram_done(s_done[0]),
        .sdram_addr(wc_addr), .sdram_wdata_we(wc_wwe), .sdram_wdata(wc_wdat)
    );

    // --- arbiter (only the write client is active) ---
    wire [NUM_SIMPLE-1:0] s_req;
    assign s_req[1] = 1'b0;
    wire [NUM_SIMPLE-1:0] s_we = {1'b0, 1'b1};
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = {types::sdram_word_addr_t'(0), wc_addr};
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = {types::sdram_byte_en_t'(0), wc_wwe};
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = {types::sdram_word_data_t'(0), wc_wdat};
    wire [NUM_SIMPLE-1:0] s_grant;
    wire types::sdram_word_data_t s_rdata;

    wire        cmd_valid, cmd_we;
    wire [23:0] cmd_addr;
    wire        wdata_valid;
    wire  [1:0] wdata_we;
    wire [15:0] wdata_data;
    logic       cmd_ready = 1'b1, wdata_ready = 1'b1, rdata_valid = 1'b0;
    logic [15:0] rdata_data = '0;
    wire        rdata_ready;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(1'b1), .boost_writes(1'b0),
        .rd_req(1'b0), .rd_addr('0), .rd_cmd_ready(), .rd_rvalid(), .rd_rdata(),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_we(cmd_we), .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid), .wdata_ready(wdata_ready), .wdata_we(wdata_we), .wdata_data(wdata_data),
        .rdata_valid(rdata_valid), .rdata_ready(rdata_ready), .rdata_data(rdata_data)
    );

    // --- recording SDRAM: accept every write, apply byte enables. (No reads here.) ---
    logic [15:0] model [logic [23:0]];
    always @(posedge clk) begin
        if (cmd_valid && cmd_ready && cmd_we && wdata_valid && wdata_ready) begin
            automatic logic [15:0] cur = model.exists(cmd_addr) ? model[cmd_addr] : 16'h0;
            if (wdata_we[0]) cur[7:0]  = wdata_data[7:0];
            if (wdata_we[1]) cur[15:8] = wdata_data[15:8];
            model[cmd_addr] = cur;
        end
    end

    // SDRAM word address of (frame, subpanel, row, col) at pixel 0, exactly as the write
    // client computes it.
    function automatic types::sdram_word_addr_t waddr(input bit frame, input int sp, input int row, input int col);
        waddr = calc::sdram_word_addr(frame, row, col, types::subpanel_addr_t'(sp),
                    calc::sdram_pixel_word_select(0, params::SDRAM_WORD_BYTES),
                    params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                    params::SDRAM_WORD_BYTES);
    endfunction
    function automatic logic [15:0] rd_model(input types::sdram_word_addr_t a);
        rd_model = model.exists(a) ? model[a] : 16'h0;
    endfunction

    task automatic write_pixel(input int sp, input int col, input logic [7:0] val);
        @(negedge clk);
        while (!wc_ready) @(negedge clk);
        wc_src_addr = '{subpanel: types::subpanel_addr_t'(sp), row: types::row_subpanel_addr_t'(ROW),
                        col: types::col_addr_t'(col), pixel: types::pixel_addr_t'(0)};
        wc_src_data = types::mem_write_data_t'(val);
        wc_src_valid = 1'b1;
        @(negedge clk);
        wc_src_valid = 1'b0;
    endtask

    task automatic settle;
        @(negedge clk);
        while (!wc_drained) @(posedge clk);
        repeat (6) @(posedge clk);
    endtask

    task automatic toggle; @(negedge clk); frame_select = ~frame_select; repeat (2) @(posedge clk); endtask

    logic [15:0] trail, cur;
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_dbuf_mirror);
        repeat (8) @(posedge clk);
        reset = 1'b0;
        repeat (8) @(posedge clk);

        // Frame 1: glyph appears at OLD_COL. (back = ~frame_select)
        write_pixel(0, OLD_COL, GLYPH);
        settle(); toggle();
        // Frame 2: glyph moves OLD->MID (erase OLD, draw MID). NO copyframe.
        write_pixel(0, OLD_COL, 8'h00);
        write_pixel(0, MID_COL, GLYPH);
        settle(); toggle();
        // Frame 3: glyph moves MID->NEW (erase MID, draw NEW). NO copyframe.
        write_pixel(0, MID_COL, 8'h00);
        write_pixel(0, NEW_COL, GLYPH);
        settle(); toggle();

        // Displayed buffer is now frame_select=1. Old position (OLD_COL) must be blank.
        trail = rd_model(waddr(1'b1, 0, ROW, OLD_COL));
        cur   = rd_model(waddr(1'b1, 0, ROW, NEW_COL));
        $display("tb_sdram_dbuf_mirror: front(buf1) OLD_COL=%h NEW_COL=%h", trail, cur);

`ifdef USE_SDRAM_DBUF_MIRROR
        if (trail != 16'h0)
            $fatal(1, "MIRROR FAILED: stale glyph (trail) left at old position: %h", trail);
        if (cur == 16'h0)
            $fatal(1, "MIRROR FAILED: current glyph missing at new position");
        $display("tb_sdram_dbuf_mirror: PASS (write mirror -> no trail; both buffers in sync)");
`else
        if (trail == 16'h0)
            $fatal(1, "expected to REPRODUCE the trail without mirror, but old position was clean");
        $display("tb_sdram_dbuf_mirror: REPRODUCED trail without mirror (old position=%h) -- matches hardware", trail);
`endif
        $finish;
    end

    initial begin #20_000_000; $fatal(1, "tb_sdram_dbuf_mirror: global timeout"); end

    wire _unused = &{1'b0, wc_drained, wc_dropped, wc_pressure, s_grant, s_rdata, rdata_ready, 1'b0};
endmodule
