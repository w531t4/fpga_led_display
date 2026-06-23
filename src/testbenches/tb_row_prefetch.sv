// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// tb_row_prefetch:
// - Drives row_prefetch's backing-store fill port with a behavioral memory model
//   (multimem-shaped 2-cycle latency by default; PIPELINED native-style read
//   interface under USE_SDRAM_FB).
// - Pulses row_latch/brightness_mask the way matrix_scan would at the end of a
//   row's bitplane sequence, and checks the display-side read port returns the
//   correct row's data after each ping-pong swap (DATA CORRECTNESS).
// - Under USE_SDRAM_FB, uses a deliberately HIGH read latency and asserts the
//   fill still completes within a row's display window (THROUGHPUT): the old
//   one-word-per-round-trip path could not, which is what scrambled hardware.
module tb_row_prefetch;
    localparam time CLK_PERIOD = 10ns;
    localparam int unsigned RESET_CYCLES = 4;
`ifdef USE_SDRAM_FB
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned WORD_BITS = $bits(types::sdram_word_data_t);
    localparam int unsigned WORDS_PER_COL = $bits(types::mem_read_data_t) / WORD_BITS;
    localparam int unsigned WORDS_PER_FILL = params::PIXEL_WIDTH * WORDS_PER_COL;

    // Deliberately high read latency to model real LiteDRAM (refresh / row miss)
    // round trips -- far worse than the optimistic sim PHY -- so the throughput
    // assertion actually bites. Pipelining must hide this.
    localparam int unsigned MOCK_LATENCY = 24;
    // The mock also backpressures command accept 1 cycle in 4, so the issue rate
    // is ~3/4 word/cycle even when fully pipelined.
    localparam int unsigned MOCK_BP_PERIOD = 4;

    // A pipelined fill is ~ WORDS_PER_FILL * (MOCK_BP_PERIOD/(MOCK_BP_PERIOD-1))
    // + MOCK_LATENCY cycles. Give generous slack for pacing between checks.
    localparam int unsigned FILL_WAIT_CYCLES = WORDS_PER_FILL * 2 + MOCK_LATENCY + 256;

    // THROUGHPUT DEADLINE: the fill must land well inside a display row window.
    // The measured row window is ~21000 cycles; require the fill to finish in
    // under a quarter of that. The old unpipelined path at MOCK_LATENCY=24 took
    // ~WORDS_PER_FILL*(24+overhead) ~= 40k cycles and would blow this.
    localparam int unsigned THROUGHPUT_DEADLINE_CYCLES = 5000;
`else
    localparam int unsigned FILL_MARGIN_CYCLES = 8;
    localparam int unsigned FILL_WAIT_CYCLES = params::PIXEL_WIDTH + FILL_MARGIN_CYCLES;
`endif

    logic clk_in;
    logic reset;

    types::mem_read_addr_t read_address;
    logic                  read_clk_enable;
    types::mem_read_data_t read_data_out;

    types::row_subpanel_addr_t row_address;
    types::brightness_level_t  brightness_mask;
    logic                       row_latch;

`ifdef USE_SDRAM_FB
    logic                    frame_select;
    logic                    sdram_req;
    types::sdram_word_addr_t sdram_addr;
    logic                    sdram_cmd_ready;
    logic                    sdram_rvalid;
    types::sdram_word_data_t sdram_rdata;
`else
    types::mem_read_addr_t fill_address;
    logic                  fill_clk_enable;
    types::mem_read_data_t fill_data_in;
`endif

    row_prefetch #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk_in),
        .read_address(read_address),
        .read_clk_enable(read_clk_enable),
        .read_data_out(read_data_out),
        .row_address(row_address),
        .brightness_mask(brightness_mask),
        .row_latch(row_latch),
`ifdef USE_SDRAM_FB
        .frame_select(frame_select),
        .sdram_req(sdram_req),
        .sdram_addr(sdram_addr),
        .sdram_cmd_ready(sdram_cmd_ready),
        .sdram_rvalid(sdram_rvalid),
        .sdram_rdata(sdram_rdata)
`else
        .fill_address(fill_address),
        .fill_clk_enable(fill_clk_enable),
        .fill_data_in(fill_data_in)
`endif
    );

    always #(CLK_PERIOD / 2) clk_in = ~clk_in;

    function automatic types::mem_read_data_t make_pattern(input int unsigned row, input types::col_addr_t col);
        types::mem_read_data_t v;
        v = '0;
        // +1 so row0/col0 isn't all-zero; explicit width matches v.raw exactly so the
        // assignment never truncates/expands regardless of the build's pixel format.
        v.raw = ($bits(v.raw))'(longint'(row) * 1000 + longint'(col) + 1);
        make_pattern = v;
    endfunction

`ifdef USE_SDRAM_FB
    // ----- Pipelined behavioral SDRAM read model: fixed MOCK_LATENCY, 1 cmd/cycle
    // accept with periodic backpressure, in-order data return via a delay line. -----
    types::sdram_word_data_t model_words[types::sdram_word_addr_t];

    logic [$clog2(MOCK_BP_PERIOD)-1:0] bp_q;
    assign sdram_cmd_ready = (bp_q != 0);  // not-ready 1 cycle in MOCK_BP_PERIOD

    logic                    pipe_valid_q[MOCK_LATENCY];
    types::sdram_word_addr_t pipe_addr_q [MOCK_LATENCY];

    always_ff @(posedge clk_in) begin
        if (reset) begin
            bp_q <= '0;
            sdram_rvalid <= 1'b0;
            sdram_rdata <= '0;
            for (int i = 0; i < MOCK_LATENCY; i++) begin
                pipe_valid_q[i] <= 1'b0;
                pipe_addr_q[i] <= '0;
            end
        end else begin
            bp_q <= (bp_q == ($clog2(MOCK_BP_PERIOD))'(MOCK_BP_PERIOD - 1)) ? '0 : bp_q + 1'b1;

            // Shift the latency delay line up by one stage.
            for (int i = MOCK_LATENCY - 1; i > 0; i--) begin
                pipe_valid_q[i] <= pipe_valid_q[i-1];
                pipe_addr_q[i]  <= pipe_addr_q[i-1];
            end
            // Enqueue an accepted command at stage 0.
            if (sdram_req && sdram_cmd_ready) begin
                pipe_valid_q[0] <= 1'b1;
                pipe_addr_q[0]  <= sdram_addr;
            end else begin
                pipe_valid_q[0] <= 1'b0;
            end
            // Drive the data return from the last stage (registered).
            sdram_rvalid <= pipe_valid_q[MOCK_LATENCY-1];
            sdram_rdata  <= model_words[pipe_addr_q[MOCK_LATENCY-1]];
        end
    end
`else
    // ----- Behavioral backing-store model: 2-cycle read latency, like mem_lane. -----
    types::mem_read_data_t model_mem[params::PIXEL_HALFHEIGHT][params::PIXEL_WIDTH];
    types::mem_read_data_t mock_pipe0, mock_pipe1;

    always @(posedge clk_in) begin
        mock_pipe0 <= model_mem[fill_address.row][fill_address.col];
        mock_pipe1 <= mock_pipe0;
    end
    assign fill_data_in = mock_pipe1;
`endif

    // ----- Helpers -----
    task automatic pulse_trigger(input types::row_subpanel_addr_t current_row);
        @(negedge clk_in);
        row_address = current_row;
        brightness_mask = types::brightness_level_t'(1);
        row_latch = 1'b1;
        @(posedge clk_in);
        @(negedge clk_in);
        row_latch = 1'b0;
    endtask

    task automatic check_read(input types::col_addr_t col, input types::row_subpanel_addr_t junk_row,
                              input types::mem_read_data_t expected);
        @(negedge clk_in);
        read_address = {junk_row, col};
        read_clk_enable = 1'b1;
        @(posedge clk_in);
        #1;
        if (read_data_out !== expected) begin
            $fatal(1, "read mismatch col=%0d expected=%0h got=%0h", col, expected, read_data_out);
        end
        @(negedge clk_in);
        read_clk_enable = 1'b0;
    endtask

    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    localparam types::col_addr_t MID_COL = types::col_addr_t'(params::PIXEL_WIDTH / 2);
    localparam types::row_subpanel_addr_t JUNK_ROW = '1;

`ifdef USE_SDRAM_FB
    // ----- Throughput watchdog: time the first fill (primed at reset) and assert
    // it finishes within the row-window deadline. row_prefetch.fill_done_q rises
    // when a fill's last word has been received. -----
    initial begin : throughput_check
        int unsigned cyc;
        cyc = 0;
        @(negedge reset);
        // Wait for the reset-primed fill of row 1 to complete.
        while (dut.fill_done_q !== 1'b1) begin
            @(posedge clk_in);
            cyc = cyc + 1;
            if (cyc > THROUGHPUT_DEADLINE_CYCLES)
                $fatal(1, "THROUGHPUT: fill did not complete within %0d cycles (latency=%0d) -- read path not pipelined",
                       THROUGHPUT_DEADLINE_CYCLES, MOCK_LATENCY);
        end
        $display("tb_row_prefetch: fill completed in %0d cycles (deadline %0d, latency %0d)",
                 cyc, THROUGHPUT_DEADLINE_CYCLES, MOCK_LATENCY);
    end
`endif

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_row_prefetch);

        clk_in = 1'b0;
        reset = 1'b1;
        read_address = '0;
        read_clk_enable = 1'b0;
        row_address = '0;
        brightness_mask = '0;
        row_latch = 1'b0;
`ifdef USE_SDRAM_FB
        frame_select = 1'b0;

        for (int r = 0; r < params::PIXEL_HALFHEIGHT; r++) begin
            for (int c = 0; c < params::PIXEL_WIDTH; c++) begin
                types::mem_read_data_t pattern;
                pattern = make_pattern(r, types::col_addr_t'(c));
                for (int w = 0; w < WORDS_PER_COL; w++) begin
                    types::sdram_word_addr_t addr;
                    addr = calc::sdram_word_addr(1'b0, r, c, logic'(w[1]), logic'(w[0]), params::PIXEL_WIDTH,
                                                  params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                                                  params::SDRAM_WORD_BYTES);
                    model_words[addr] = pattern.raw[w*WORD_BITS+:WORD_BITS];
                end
            end
        end
`else
        for (int r = 0; r < params::PIXEL_HALFHEIGHT; r++) begin
            for (int c = 0; c < params::PIXEL_WIDTH; c++) begin
                model_mem[r][c] = make_pattern(r, types::col_addr_t'(c));
            end
        end
`endif

        repeat (RESET_CYCLES) @(posedge clk_in);
        reset = 1'b0;

        // Bank0 (initially active) should read back its default-zero contents:
        // no fill has targeted it yet, matching multimem's blank-at-boot state.
        check_read(0, JUNK_ROW, '0);
        check_read(LAST_COL, JUNK_ROW, '0);

        // Reset primes a fill of row 1 into bank1; give it time to land.
        repeat (FILL_WAIT_CYCLES) @(posedge clk_in);

        // Sweep EVERY scan position. pulse_trigger(R) makes the bank holding row R+1
        // (filled the previous iteration) active and kicks off the fill of row R+2.
        // Checking the full assembled column at every row catches any scan-position-
        // specific fill/assembly bug -- the bottom display rows are the bottom subpanel
        // of high scan positions, which e2e (row 1 only) never exercised.
        for (int unsigned R = 0; R < params::PIXEL_HALFHEIGHT - 1; R++) begin
            pulse_trigger(types::row_subpanel_addr_t'(R));
            check_read(0,        JUNK_ROW, make_pattern(R + 1, 0));
            check_read(MID_COL,  JUNK_ROW, make_pattern(R + 1, MID_COL));
            check_read(LAST_COL, JUNK_ROW, make_pattern(R + 1, LAST_COL));
            repeat (FILL_WAIT_CYCLES) @(posedge clk_in);
        end

        $display("tb_row_prefetch: PASS (swept scan rows 1..%0d)", params::PIXEL_HALFHEIGHT - 1);
        $finish;
    end

`ifndef USE_SDRAM_FB
    wire _unused_ok = &{1'b0, fill_clk_enable, 1'b0};
`endif
endmodule
