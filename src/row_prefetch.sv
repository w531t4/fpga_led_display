// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// row_prefetch: Ping-pong row buffer that decouples the BAM scan engine's
// per-pixel reads from the framebuffer backing store. One bank is read by
// framebuffer_fetch (display side) while the other is refilled from the
// backing store ahead of the next row swap. The display-side read port
// mirrors multimem's port B shape so framebuffer_fetch needs no changes;
// only the .col field of the address is used, since the active bank
// already corresponds to the row currently being scanned.
//
// Fill ordering: at each row_latch with brightness_mask==1 (the last
// bitplane of the row that's ending), the bank that has spent the whole
// row finishing its fill becomes active, and a new fill for row_address+2
// begins into the bank that just went inactive. This gives the fill a full
// row's display time (8x its own duration) to complete before it's needed.
//
// Fill source: under USE_SDRAM_FB, each column is fetched word-by-word from
// the SDRAM arbiter (one req/done round trip per word, WORDS_PER_COL words
// per column) instead of a free-running BRAM burst, since SDRAM latency
// isn't fixed the way multimem's was. Without the flag, the original
// fixed-latency multimem burst is unchanged.
module row_prefetch #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input logic reset,
    input logic clk_in,

    // Display-side read port (drives framebuffer_fetch, mirrors multimem port B).
    input  types::mem_read_addr_t read_address,
    input  logic                  read_clk_enable,
    output types::mem_read_data_t read_data_out,

    // Scan timing, from matrix_scan.
    input types::row_subpanel_addr_t row_address,
    input types::brightness_level_t  brightness_mask,
    input logic                      row_latch,

`ifdef USE_SDRAM_FB
    // Backing-store fill port (drives sdram_arbiter's priority-1 client).
    input  logic                    frame_select,
    output logic                    sdram_req,
    input  logic                    sdram_done,
    output types::sdram_word_addr_t sdram_addr,
    input  types::sdram_word_data_t sdram_rdata
`else
    // Backing-store fill port (drives framebuffer_fabric's RAM-B port).
    output types::mem_read_addr_t fill_address,
    output logic                  fill_clk_enable,
    input  types::mem_read_data_t fill_data_in
`endif
);
    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);

`ifdef USE_SDRAM_FB
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned WORD_BITS = $bits(types::sdram_word_data_t);
    localparam int unsigned WORDS_PER_COL = $bits(types::mem_read_data_t) / WORD_BITS;
    localparam int unsigned WORD_IDX_BITS = calc::safe_clog2(WORDS_PER_COL);
`else
    // Matches the AddressB -> QB latency in mem_lane (sync read + outreg stage).
    localparam int unsigned READ_LATENCY = 2;
`endif

    typedef enum logic [1:0] {
        STATE_FILL,
`ifndef USE_SDRAM_FB
        STATE_DRAIN,
`endif
        STATE_IDLE
    } fill_state_t;
    fill_state_t state_q;

    logic                      bank_sel_q;  // bank currently active for display reads
    types::row_subpanel_addr_t fill_row_q;
    types::col_addr_t          issue_col_q;
    logic                      fill_done_q;

`ifdef USE_SDRAM_FB
    logic [WORD_IDX_BITS-1:0] word_idx_q;
    logic [$bits(types::mem_read_data_t)-1:0] accum_q;
    // Registered so sdram_addr is a pure flop output: computing it live from
    // fill_row_q/issue_col_q/word_idx_q on every cycle chained the address
    // arithmetic straight into the arbiter/LiteDRAM round trip with no
    // register in between, which blew timing at 80MHz (see PLAN.md 3.3
    // (build) hardware note). Computed alongside those counters below instead,
    // using whatever values they're about to take.
    types::sdram_word_addr_t sdram_addr_q;
`else
    types::col_addr_t col_pipe[READ_LATENCY];
    logic             valid_pipe[READ_LATENCY];
`endif

    // Two row-deep banks; bank_sel_q selects which one is the active (display) bank.
    // Force block RAM (matches mem_lane.sv's precedent): without ram_style,
    // and with the bank_sel_q mux previously living *inside* the read index
    // expression, yosys's BRAM-transparency heuristic declined to map these
    // to DP16KD and fell back to ~12KB of flip-flops instead -- the real
    // driver of the nextpnr place&route blowup, not BRAM "congestion" with
    // multimem (which removing multimem under USE_SDRAM_FB didn't fix).
    (* ram_style = "block", no_rw_check *)
    types::mem_read_data_t bank0[params::PIXEL_WIDTH];
    (* ram_style = "block", no_rw_check *)
    types::mem_read_data_t bank1[params::PIXEL_WIDTH];

    wire trigger = row_latch && (brightness_mask == types::brightness_level_t'(1)) && fill_done_q;

`ifdef USE_SDRAM_FB
    wire [$bits(types::mem_read_data_t)-1:0] shifted_word =
        ($bits(types::mem_read_data_t))'(sdram_rdata) << (int'(word_idx_q) * WORD_BITS);
    wire [$bits(types::mem_read_data_t)-1:0] merged_word = accum_q | shifted_word;
    wire [WORD_IDX_BITS-1:0] next_word_idx = word_idx_q + 1'b1;

    assign sdram_req = (state_q == STATE_FILL);
    assign sdram_addr = sdram_addr_q;
`else
    assign fill_address    = {fill_row_q, issue_col_q};
    assign fill_clk_enable = (state_q == STATE_FILL);
`endif

    always @(posedge clk_in) begin
        if (reset) begin
            state_q <= STATE_FILL;
            bank_sel_q <= 1'b0;
            // Bank0 starts as the active (display) bank holding its default-zero
            // contents -- the same blank state multimem would show pre-migration.
            // Bank1 is primed with row 1 immediately so the first real swap is correct.
            fill_row_q <= types::row_subpanel_addr_t'(1);
            issue_col_q <= '0;
            fill_done_q <= 1'b0;
`ifdef USE_SDRAM_FB
            word_idx_q <= '0;
            accum_q <= '0;
            sdram_addr_q <= calc::sdram_word_addr(frame_select, $bits(int)'(types::row_subpanel_addr_t'(1)), 0,
                                                   1'b0, 1'b0, params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT,
                                                   NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES);
`else
            for (int i = 0; i < READ_LATENCY; i++) begin
                col_pipe[i] <= '0;
                valid_pipe[i] <= 1'b0;
            end
`endif
        end else begin
`ifndef USE_SDRAM_FB
            for (int i = READ_LATENCY - 1; i > 0; i--) begin
                col_pipe[i] <= col_pipe[i-1];
                valid_pipe[i] <= valid_pipe[i-1];
            end
`endif

            if (trigger) begin
                bank_sel_q <= ~bank_sel_q;
                state_q <= STATE_FILL;
                fill_row_q <= row_address + types::row_subpanel_addr_t'(2);
                issue_col_q <= '0;
                fill_done_q <= 1'b0;
`ifdef USE_SDRAM_FB
                word_idx_q <= '0;
                accum_q <= '0;
                sdram_addr_q <= calc::sdram_word_addr(frame_select,
                                                       $bits(int)'(row_address + types::row_subpanel_addr_t'(2)), 0,
                                                       1'b0, 1'b0, params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT,
                                                       NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES);
`else
                col_pipe[0] <= '0;
                valid_pipe[0] <= 1'b0;
`endif
            end else begin
                case (state_q)
                    STATE_FILL: begin
`ifdef USE_SDRAM_FB
                        if (sdram_done) begin
                            if (word_idx_q == WORD_IDX_BITS'(WORDS_PER_COL - 1)) begin
                                if (bank_sel_q) begin
                                    bank0[issue_col_q] <= types::mem_read_data_t'(merged_word);
                                end else begin
                                    bank1[issue_col_q] <= types::mem_read_data_t'(merged_word);
                                end
                                word_idx_q <= '0;
                                accum_q <= '0;
                                if (issue_col_q == LAST_COL) begin
                                    state_q <= STATE_IDLE;
                                    fill_done_q <= 1'b1;
                                end else begin
                                    issue_col_q <= issue_col_q + 1'b1;
                                    sdram_addr_q <= calc::sdram_word_addr(frame_select, $bits(int)'(fill_row_q),
                                                                           $bits(int)'(issue_col_q + 1'b1), 1'b0,
                                                                           1'b0, params::PIXEL_WIDTH,
                                                                           params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                                                           PIXEL_BYTES, params::SDRAM_WORD_BYTES);
                                end
                            end else begin
                                accum_q <= merged_word;
                                word_idx_q <= word_idx_q + 1'b1;
                                sdram_addr_q <= calc::sdram_word_addr(frame_select, $bits(int)'(fill_row_q),
                                                                       $bits(int)'(issue_col_q), next_word_idx[1],
                                                                       next_word_idx[0], params::PIXEL_WIDTH,
                                                                       params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                                                       PIXEL_BYTES, params::SDRAM_WORD_BYTES);
                            end
                        end
`else
                        col_pipe[0]   <= issue_col_q;
                        valid_pipe[0] <= 1'b1;
                        if (issue_col_q == LAST_COL) begin
                            state_q <= STATE_DRAIN;
                        end else begin
                            issue_col_q <= issue_col_q + 1'b1;
                        end
`endif
                    end
`ifndef USE_SDRAM_FB
                    STATE_DRAIN: begin
                        col_pipe[0]   <= '0;
                        valid_pipe[0] <= 1'b0;
                        if (!valid_pipe[READ_LATENCY-1]) begin
                            state_q     <= STATE_IDLE;
                            fill_done_q <= 1'b1;
                        end
                    end
`endif
                    STATE_IDLE: begin
`ifndef USE_SDRAM_FB
                        col_pipe[0]   <= '0;
                        valid_pipe[0] <= 1'b0;
`endif
                    end
                    default: state_q <= STATE_IDLE;
                endcase
            end

`ifndef USE_SDRAM_FB
            // Commit the read data for the column now aligned at the tail of the
            // pipeline into whichever bank is currently the fill target (the bank
            // not selected for display).
            if (valid_pipe[READ_LATENCY-1]) begin
                if (bank_sel_q) begin
                    bank0[col_pipe[READ_LATENCY-1]] <= fill_data_in;
                end else begin
                    bank1[col_pipe[READ_LATENCY-1]] <= fill_data_in;
                end
            end
`endif
        end
    end

    // Display-side read: synchronous, mirrors multimem's QB shape. framebuffer_fetch
    // already applies its own sample-tick delay, so no extra pipeline stage is added.
    // Each bank is read unconditionally into its own register (matching
    // mem_lane.sv's pattern) and bank_sel_q muxes the two registered outputs,
    // rather than muxing inside the read index -- same one-cycle latency as
    // before, but in a shape yosys's BRAM mapper actually recognizes.
    types::mem_read_data_t bank0_dout_q;
    types::mem_read_data_t bank1_dout_q;
    always @(posedge clk_in) begin
        if (reset) begin
            bank0_dout_q <= '0;
            bank1_dout_q <= '0;
        end else if (read_clk_enable) begin
            bank0_dout_q <= bank0[read_address.col];
            bank1_dout_q <= bank1[read_address.col];
        end
    end
    assign read_data_out = bank_sel_q ? bank1_dout_q : bank0_dout_q;

    wire _unused_ok = &{1'b0, read_address.row, 1'b0};
endmodule
