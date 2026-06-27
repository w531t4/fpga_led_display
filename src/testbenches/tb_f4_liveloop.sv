// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// =============================================================================
// tb_f4_liveloop -- end-to-end correctness check for control_cmd_copyframe through
// the REAL sdram_arbiter + timing-real SDRAM model, UNDER rd-port (display prefetch)
// contention that forces the arbiter to PREEMPT the copy mid-flight.
//
// Closes a real coverage gap: copyframe is the lowest-priority arbiter client
// (cp_preempt = rd_req) and the only live-mode carry-forward path -- the test pattern
// never uses it, and its sole unit test drives an IDEAL mock (cmd_ready=1 every cycle,
// never preempted), so its behaviour while being repeatedly preempted/resumed had
// never run in sim. This test confirms the copy stays correct under preemption (it
// does -- so copyframe is NOT the F4 fault).
//
// Seed-free check: the timing model returns def_data(addr)=addr[15:0]^0x5a3c for
// any unwritten word. copyframe reads the (unwritten) FRONT buffer -> gets
// def_data(front_addr) -> writes it to BACK. So a correct copy leaves
//   back[BUFFER_WORDS + k] == def_data(k)
// and a misalignment-by-D leaves def_data(k +/- D) instead -- trivially visible.
// Requires the timing model (tb_f4_liveloop.args adds -DSDRAM_SIM_TIMING_MODEL).
// =============================================================================
module tb_f4_liveloop;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES   = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned BUFFER_WORDS =
        calc::num_sdram_buffer_words(params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                     PIXEL_BYTES, params::SDRAM_WORD_BYTES);

    logic clk = 1'b0;
    logic reset = 1'b1;
    always #5 clk = ~clk;

    // copyframe: front = frame_select, back = ~frame_select. fsel=0 => front_base=0,
    // back_base=BUFFER_WORDS.
    localparam logic FSEL = 1'b0;

    // ---- SDRAM core (timing-real model via -DSDRAM_SIM_TIMING_MODEL) ----
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

    // ---- copyframe engine on the arbiter cp port ----
    logic cf_enable = 1'b0;
    wire  cf_req, cf_we, cf_cmd_ready, cf_rvalid, cf_done;
    wire types::sdram_word_addr_t cf_addr;
    wire types::sdram_byte_en_t   cf_wdata_we;
    wire types::sdram_word_data_t cf_wdata, cf_rdata;

    control_cmd_copyframe cf (
        .reset(reset), .enable(cf_enable), .clk(clk), .frame_select(FSEL),
        .sdram_req(cf_req), .sdram_we(cf_we), .sdram_addr(cf_addr),
        .sdram_wdata_we(cf_wdata_we), .sdram_wdata(cf_wdata),
        .sdram_cmd_ready(cf_cmd_ready), .sdram_rvalid(cf_rvalid), .sdram_rdata(cf_rdata),
        .done(cf_done)
    );

    // ---- rd port: MUXED so the contention driver and the verify driver never
    // fight over the same register. `copying` selects which one owns the port.
    logic copying = 1'b0;
    logic c_req = 1'b0;                          // contention driver (during copy)
    types::sdram_word_addr_t c_addr = '0;
    logic v_req = 1'b0;                          // verify driver (after copy)
    types::sdram_word_addr_t v_addr = '0;
    wire  tb_rd_req = copying ? c_req : v_req;
    wire  types::sdram_word_addr_t tb_rd_addr = copying ? c_addr : v_addr;
    wire arb_rd_cmd_ready, arb_rd_rvalid;
    wire types::sdram_word_data_t arb_rd_rdata;

    // ---- arbiter (no simple clients) ----
    localparam int unsigned NUM_SIMPLE = 1;
    wire [NUM_SIMPLE-1:0] s_req  = '0;
    wire [NUM_SIMPLE-1:0] s_we   = '1;
    wire types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr = '0;
    wire types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wwe  = '0;
    wire types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdat = '0;
    wire [NUM_SIMPLE-1:0] s_grant, s_done;
    wire types::sdram_word_data_t s_rdata;

    sdram_arbiter #(.NUM_SIMPLE(NUM_SIMPLE)) arb (
        .clk(clk), .reset(reset), .init_done(init_done), .boost_writes(1'b0),
        .rd_req(tb_rd_req), .rd_addr(tb_rd_addr), .rd_cmd_ready(arb_rd_cmd_ready),
        .rd_rvalid(arb_rd_rvalid), .rd_rdata(arb_rd_rdata),
        .s_req(s_req), .s_we(s_we), .s_addr(s_addr), .s_wdata_we(s_wwe), .s_wdata(s_wdat),
        .s_grant(s_grant), .s_done(s_done), .s_rdata(s_rdata),
        .cp_req(cf_req), .cp_we(cf_we), .cp_addr(cf_addr), .cp_wdata_we(cf_wdata_we), .cp_wdata(cf_wdata),
        .cp_cmd_ready(cf_cmd_ready), .cp_rvalid(cf_rvalid), .cp_rdata(cf_rdata),
        .cmd_valid(lcmd_valid), .cmd_ready(lcmd_ready), .cmd_we(lcmd_we), .cmd_addr(lcmd_addr),
        .wdata_valid(lwdata_valid), .wdata_ready(lwdata_ready), .wdata_we(lwdata_we), .wdata_data(lwdata_data),
        .rdata_valid(lrdata_valid), .rdata_ready(lrdata_ready), .rdata_data(lrdata_data)
    );

    function automatic logic [15:0] def_data(input logic [23:0] a);
        def_data = a[15:0] ^ 16'h5a3c;
    endfunction

    // single rd-port read (verify phase: copying=0, so the mux selects v_*)
    task automatic rd_word(input int unsigned word_addr, output logic [15:0] val);
        @(negedge clk);
        v_addr = types::sdram_word_addr_t'(word_addr);
        v_req  = 1'b1;
        while (!arb_rd_cmd_ready) @(negedge clk);
        @(negedge clk);
        v_req = 1'b0;
        while (!arb_rd_rvalid) @(negedge clk);
        val = types::sdram_word_data_t'(arb_rd_rdata);
    endtask

    // contention: while `copying`, fire periodic rd bursts (mimics the display
    // prefetch) to PREEMPT copyframe mid-burst. Drives ONLY c_* (no conflict).
    initial begin : contention
        int unsigned roll;
        roll = 0;
        forever begin
            @(negedge clk);
            if (copying) begin
                for (int b = 0; b < 8; b++) begin   // 8-cycle read burst
                    c_addr = types::sdram_word_addr_t'(roll % BUFFER_WORDS);
                    c_req  = 1'b1;
                    roll   = roll + 41;
                    @(negedge clk);
                    if (!copying) break;
                end
                c_req = 1'b0;
                repeat (20) @(negedge clk);          // gap so copyframe can progress
            end else begin
                c_req = 1'b0;
            end
        end
    end


    integer errors = 0;
    integer checked = 0;
    logic [15:0] got;

    // detect a constant misalignment offset if back[k] != def_data(k)
    function automatic int find_shift(input int unsigned k, input logic [15:0] g);
        find_shift = 0;
        for (int d = -8; d <= 8; d++) begin
            if (d != 0 && g == def_data(24'(int'(k) + d))) begin
                find_shift = d;
                return find_shift;
            end
        end
    endfunction

    task automatic check_word(input int unsigned k);
        logic [15:0] exp;
        int sh;
        begin
            rd_word(BUFFER_WORDS + k, got);     // back buffer word k
            exp = def_data(24'(k));             // front_base=0 -> front addr == k
            checked = checked + 1;
            if (got !== exp) begin
                errors = errors + 1;
                sh = find_shift(k, got);
                if (errors <= 20)
                    $display("  MISMATCH back[%0d]: got %04h exp %04h%s",
                             k, got, exp, (sh != 0) ? $sformatf("  (== front word k + shift %0d)", sh) : "");
            end
        end
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_f4_liveloop);
        repeat (8) @(posedge clk);
        reset = 1'b0;
        while (!init_done) @(posedge clk);
        repeat (8) @(posedge clk);

        // ---- run ONE full copyframe UNDER prefetch contention (preemption) ----
        copying   = 1'b1;                 // contention owns the rd port + preempts cp
        cf_enable = 1'b1;
        @(posedge clk);
        while (!cf_req) @(posedge clk);   // copy started issuing
        cf_enable = 1'b0;                 // enable only sampled in STATE_IDLE -> no re-trigger
        while (!cf_done) @(posedge clk);  // copy complete (despite preemption)
        copying = 1'b0;                   // hand the rd port to the verify driver
        repeat (200) @(posedge clk);      // let the last cp writes commit through the model

        // ---- verify the back buffer matches the (def_data) front buffer ----
        $display("  BUFFER_WORDS=%0d (copyframe just copied [0,BW) -> [BW,2BW))", BUFFER_WORDS);
        for (int unsigned k = 0; k < 256; k++)                   check_word(k);              // head
        for (int unsigned k = 1000; k < BUFFER_WORDS; k += 1511) check_word(k);              // spread
        check_word(BUFFER_WORDS - 1);                                                        // tail

        if (errors == 0)
            $display("tb_f4_liveloop: copyframe COPIES CORRECTLY UNDER PREEMPTION (%0d words checked) -- NOT the F4 bug", checked);
        else
            $error("tb_f4_liveloop: copyframe data WRONG UNDER PREEMPTION: %0d/%0d words mismatched (F4 mechanism)", errors, checked);
        $finish;
    end

    initial begin
        #40_000_000;
        $fatal(1, "tb_f4_liveloop: global timeout (copyframe never completed under contention?)");
    end

    wire _unused = &{1'b0, init_error, user_clk, user_rst, sdram_clk, sdram_a, sdram_ba, sdram_casn,
                     sdram_cke, sdram_csn, sdram_dqm, sdram_rasn, sdram_wen, s_grant, s_done, s_rdata, 1'b0};
endmodule
