// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module control_cmd_copyframe #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input enable,
    input clk,
`ifdef USE_SDRAM_FB
    input logic frame_select,

    // PIPELINED arbiter client port (analogous to row_prefetch's read port, but
    // it also issues writes). Command channel: sdram_req asserts while there is a
    // command to issue, sdram_we picks read(0)/write(1), sdram_addr/wdata carry it,
    // and sdram_cmd_ready pulses when the arbiter accepts it (issue advances). Read
    // data returns later, in command order, on sdram_rvalid/sdram_rdata. Many reads
    // can be outstanding at once, so a full-buffer copy streams at ~bus rate instead
    // of one round trip per word.
    output logic                    sdram_req,
    output logic                    sdram_we,
    output types::sdram_word_addr_t sdram_addr,
    output types::sdram_byte_en_t   sdram_wdata_we,
    output types::sdram_word_data_t sdram_wdata,
    input  logic                    sdram_cmd_ready,
    input  logic                    sdram_rvalid,
    input  types::sdram_word_data_t sdram_rdata,

    output logic done
`else
    input types::mem_write_data_t data_in,

    output types::fb_addr_t read_addr,
    output types::fb_addr_t write_addr,
    output logic ram_write_enable,
    output logic ram_access_start,
    output types::mem_write_data_t data_out,
    output logic done
`endif
);
`ifdef USE_SDRAM_FB
    // Front buffer -> back buffer is a flat word-for-word copy: calc::sdram_word_addr
    // already visits every word in [0, BUFFER_WORDS) exactly once for a fixed frame,
    // so this engine doesn't need per-pixel addressing at all, just a linear offset
    // added to whichever frame's base is currently the front/back buffer.
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned BUFFER_WORDS =
        calc::num_sdram_buffer_words(params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                                      params::SDRAM_WORD_BYTES);
    localparam types::sdram_word_addr_t BUFFER_WORDS_T = types::sdram_word_addr_t'(BUFFER_WORDS);
    // Word-index counter type: counts [0, BUFFER_WORDS] so == BUFFER_WORDS means "all done".
    typedef logic [$clog2(BUFFER_WORDS + 1)-1:0] word_idx_t;
    localparam word_idx_t BUFFER_WORDS_IDX = word_idx_t'(BUFFER_WORDS);

    // Read-data FIFO between the (pipelined) read stream and the write stream.
    // FIFO_DEPTH also bounds how many reads may be outstanding+buffered at once, so it
    // sets the steady-state pipelining depth: it must exceed the arbiter/SDRAM round
    // trip to fully hide latency. Power-of-two keeps the wraparound pointers cheap.
    localparam int unsigned FIFO_DEPTH = 16;
    localparam int unsigned FIFO_PTR_BITS = $clog2(FIFO_DEPTH);
    typedef logic [FIFO_PTR_BITS-1:0] fifo_ptr_t;
    typedef logic [FIFO_PTR_BITS:0]   fifo_cnt_t;  // 0..FIFO_DEPTH
    // Same-direction commands issued before switching the bus to the other direction.
    // copyframe reads from the FRONT buffer row and writes to the BACK buffer row --
    // different DRAM rows -- so alternating read/write every word would force a
    // precharge/activate (row thrash) every command. Batching a run of same-direction
    // commands amortizes one row open over the whole run. The arbiter only runs
    // copyframe BETWEEN display fills, so this batching never interleaves with a fill.
    localparam int unsigned BATCH = FIFO_DEPTH / 2;
    typedef logic [$clog2(BATCH + 1)-1:0] batch_t;

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_READ,   // issuing read commands (front buffer) into the FIFO
        STATE_WRITE,  // draining the FIFO as write commands (back buffer)
        STATE_DONE
    } copy_state_t;
    copy_state_t state_q;

    // FIFO storage + occupancy.
    types::sdram_word_data_t fifo_mem[FIFO_DEPTH];
    fifo_ptr_t fifo_wr_ptr_q;
    fifo_ptr_t fifo_rd_ptr_q;
    fifo_cnt_t fifo_count_q;

    word_idx_t rd_word_q;   // next FRONT word to REQUEST (advances on read cmd accept)
    word_idx_t rd_inflight_q;  // reads requested but not yet returned into the FIFO
    word_idx_t wr_word_q;   // next BACK word to WRITE (advances on write cmd accept)
    batch_t    batch_q;     // commands left to issue in the current direction's batch

    // Registered command outputs: sdram_addr/sdram_we are deliberately pure flops into
    // the arbiter/LiteDRAM path; chaining the address/select arithmetic straight
    // through blew timing at 80MHz (see PLAN.md 3.3 hardware note).
    logic                    sdram_req_q;
    logic                    sdram_we_q;
    types::sdram_word_addr_t sdram_addr_q;

    wire types::sdram_word_addr_t front_base = frame_select ? BUFFER_WORDS_T : '0;
    wire types::sdram_word_addr_t back_base = frame_select ? '0 : BUFFER_WORDS_T;

    // Channel events this cycle.
    wire fifo_push  = sdram_rvalid;                                   // a read word lands in the FIFO
    wire fifo_pop   = sdram_req_q && sdram_we_q && sdram_cmd_ready;   // a write consumed the FIFO head
    wire rd_cmd_acc = sdram_req_q && !sdram_we_q && sdram_cmd_ready;  // a read command was accepted

    assign sdram_req = sdram_req_q;
    assign sdram_we = sdram_we_q;
    assign sdram_addr = sdram_addr_q;
    assign sdram_wdata_we = '1;
    // Write data is the FIFO head -- a data-path mux, not the address arithmetic that
    // had to be registered, so reading it combinationally here is fine.
    assign sdram_wdata = fifo_mem[fifo_rd_ptr_q];

    // Counter values AFTER this cycle's accepted commands (used to pick the next cmd
    // so the registered output already reflects the in-flight advance).
    wire word_idx_t rd_word_n     = rd_cmd_acc ? rd_word_q + 1'b1 : rd_word_q;
    wire word_idx_t wr_word_n     = fifo_pop   ? wr_word_q + 1'b1 : wr_word_q;
    wire word_idx_t rd_inflight_n = rd_inflight_q + (rd_cmd_acc ? word_idx_t'(1) : '0)
                                                  - (fifo_push  ? word_idx_t'(1) : '0);
    wire fifo_cnt_t fifo_count_n  = fifo_count_q + (fifo_push ? fifo_cnt_t'(1) : '0)
                                                 - (fifo_pop  ? fifo_cnt_t'(1) : '0);
    wire batch_t    batch_n       = (batch_q != '0) ? batch_q - 1'b1 : batch_q;

    // After this cycle's events, may we still issue a read / a write?
    wire reads_remain  = (rd_word_n != BUFFER_WORDS_IDX);
    wire writes_remain = (wr_word_n != BUFFER_WORDS_IDX);
    // A read may issue only if every word already buffered (fifo_count) plus every
    // word still outstanding (rd_inflight) plus the new one still fits the FIFO -- so
    // each outstanding read always has a reserved slot and the FIFO can't overflow.
    wire [FIFO_PTR_BITS+1:0] reserved_n = (FIFO_PTR_BITS+2)'(fifo_count_n) + (FIFO_PTR_BITS+2)'(rd_inflight_n);
    wire fifo_room     = (reserved_n < (FIFO_PTR_BITS+2)'(FIFO_DEPTH));
    wire fifo_has_data = (fifo_count_n != '0);
    wire can_read_more  = reads_remain && fifo_room;
    wire can_write_more = writes_remain && fifo_has_data;
    wire all_done = !reads_remain && !writes_remain;

    always @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            fifo_wr_ptr_q <= '0;
            fifo_rd_ptr_q <= '0;
            fifo_count_q <= '0;
            rd_word_q <= '0;
            rd_inflight_q <= '0;
            wr_word_q <= '0;
            batch_q <= '0;
            sdram_req_q <= 1'b0;
            sdram_we_q <= 1'b0;
            sdram_addr_q <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;

            // ---- FIFO + in-flight accounting (independent of the FSM arm below) ----
            if (fifo_push) begin
                fifo_mem[fifo_wr_ptr_q] <= sdram_rdata;
                fifo_wr_ptr_q <= fifo_wr_ptr_q + 1'b1;
            end
            if (fifo_pop) fifo_rd_ptr_q <= fifo_rd_ptr_q + 1'b1;
            fifo_count_q <= fifo_count_n;
            rd_inflight_q <= rd_inflight_n;
            if (rd_cmd_acc) rd_word_q <= rd_word_n;
            if (fifo_pop)   wr_word_q <= wr_word_n;
            if ((rd_cmd_acc || fifo_pop) && batch_q != '0) batch_q <= batch_n;

            // ---- decide the next command to present (keeps outputs registered) ----
            case (state_q)
                STATE_IDLE: begin
                    if (enable) begin
                        // Present the first read command (front_base + word 0). It is not
                        // accepted until the first STATE_READ cycle, where the accounting
                        // above counts it -- so the counters start at zero here (no
                        // pre-count, else word 0 would be double-counted as in-flight).
                        fifo_wr_ptr_q <= '0;
                        fifo_rd_ptr_q <= '0;
                        fifo_count_q <= '0;
                        rd_word_q <= '0;
                        rd_inflight_q <= '0;
                        wr_word_q <= '0;
                        batch_q <= batch_t'(BATCH);
                        sdram_req_q <= 1'b1;
                        sdram_we_q <= 1'b0;
                        sdram_addr_q <= front_base;
                        state_q <= STATE_READ;
                    end else begin
                        sdram_req_q <= 1'b0;
                    end
                end

                STATE_READ: begin
                    if (all_done) begin
                        sdram_req_q <= 1'b0;
                        // (writes_remain is false here, so this only fires once the whole
                        // buffer has been copied -- normally we switch to writes first.)
                    end else if (can_read_more && (batch_n != '0 || !can_write_more)) begin
                        // Keep streaming reads (batch has room, or there's nothing to drain yet).
                        sdram_req_q <= 1'b1;
                        sdram_we_q <= 1'b0;
                        sdram_addr_q <= front_base + types::sdram_word_addr_t'(rd_word_n);
                    end else if (can_write_more) begin
                        // Hand the bus to a write batch to drain the FIFO.
                        sdram_req_q <= 1'b1;
                        sdram_we_q <= 1'b1;
                        sdram_addr_q <= back_base + types::sdram_word_addr_t'(wr_word_n);
                        batch_q <= batch_t'(BATCH);
                        state_q <= STATE_WRITE;
                    end else begin
                        // No room to read and nothing yet to write (FIFO mid-flight): pause
                        // issuing; the outstanding reads still return and refill the FIFO.
                        sdram_req_q <= 1'b0;
                    end
                end

                STATE_WRITE: begin
                    if (all_done) begin
                        sdram_req_q <= 1'b0;
                        done <= 1'b1;
                        state_q <= STATE_DONE;
                    end else if (can_write_more && (batch_n != '0 || !can_read_more)) begin
                        // Keep draining writes.
                        sdram_req_q <= 1'b1;
                        sdram_we_q <= 1'b1;
                        sdram_addr_q <= back_base + types::sdram_word_addr_t'(wr_word_n);
                    end else if (can_read_more) begin
                        // FIFO drained (or batch done) and reads remain -> read more.
                        sdram_req_q <= 1'b1;
                        sdram_we_q <= 1'b0;
                        sdram_addr_q <= front_base + types::sdram_word_addr_t'(rd_word_n);
                        batch_q <= batch_t'(BATCH);
                        state_q <= STATE_READ;
                    end else begin
                        // Nothing acceptable this cycle (FIFO momentarily empty while reads
                        // are still in flight). Pause; a returning read reopens the drain.
                        sdram_req_q <= 1'b0;
                    end
                end

                STATE_DONE: begin
                    sdram_req_q <= 1'b0;
                    state_q <= STATE_IDLE;
                end

                default: state_q <= STATE_IDLE;
            endcase
        end
    end
`else
    // 1‑byte/clk copy pipeline:
    //  - issue a read every cycle (front buffer)
    //  - QA output is valid READ_LATENCY cycles later
    //  - write that data to the back buffer each cycle
    localparam int unsigned TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Matches the AddressA -> QA latency in multimem (addr reg + BRAM + QA pipeline).
    localparam int unsigned READ_LATENCY = 5;

    typedef logic [$clog2(TOTAL_BYTES + 1)-1:0] copy_count_t;
    localparam copy_count_t TOTAL_BYTES_COUNT = copy_count_t'(TOTAL_BYTES);
    localparam copy_count_t TOTAL_BYTES_LAST = copy_count_t'(TOTAL_BYTES - 1);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_COPY,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;

    types::fb_addr_t read_addr_q;
    types::fb_addr_t read_addr_pipe[READ_LATENCY];
    logic [READ_LATENCY-1:0] read_valid_pipe;
    copy_count_t read_count;
    copy_count_t write_count;

    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    localparam types::pixel_addr_t LAST_PIXEL = types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);

    assign read_addr = read_addr_q;
    assign write_addr = read_addr_pipe[READ_LATENCY-1];

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            read_addr_q <= '0;
            for (int i = 0; i < READ_LATENCY; i++) begin
                read_addr_pipe[i] <= '0;
            end
            read_valid_pipe <= '0;
            read_count <= '0;
            write_count <= '0;
            ram_access_start <= 1'b0;
            ram_write_enable <= 1'b0;
            data_out <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            ram_write_enable <= 1'b0;
            data_out <= '0;
            case (state)
                STATE_IDLE: begin
                    if (enable) begin
                        state <= STATE_COPY;
                        read_addr_q.row <= '0;
                        read_addr_q.col <= '0;
                        read_addr_q.pixel <= LAST_PIXEL;
                        for (int i = 0; i < READ_LATENCY; i++) begin
                            read_addr_pipe[i] <= '0;
                        end
                        read_valid_pipe <= '0;
                        read_count <= '0;
                        write_count <= '0;
                        // Prime the access toggle so ClockEnA is high on the first copy cycle.
                        ram_access_start <= 1'b1;
                    end else begin
                        ram_access_start <= 1'b0;
                    end
                end
                STATE_COPY: begin
                    // Toggle every cycle to keep ClockEnA asserted.
                    ram_access_start <= ~ram_access_start;

                    // Shift the address/valid pipelines.
                    for (int i = READ_LATENCY - 1; i > 0; i--) begin
                        read_addr_pipe[i] <= read_addr_pipe[i - 1];
                        read_valid_pipe[i] <= read_valid_pipe[i - 1];
                    end

                    // Issue a new read when there are bytes remaining.
                    if (read_count < TOTAL_BYTES_COUNT) begin
                        read_addr_pipe[0] <= read_addr_q;
                        read_valid_pipe[0] <= 1'b1;
                        read_count <= read_count + 1;
                        // Advance address for the next cycle (pixel counts down).
                        if (read_addr_q.pixel == 'd0) begin
                            read_addr_q.pixel <= LAST_PIXEL;
                            if (read_addr_q.col == LAST_COL) begin
                                read_addr_q.col <= '0;
                                read_addr_q.row <= read_addr_q.row + 'd1;
                            end else begin
                                read_addr_q.col <= read_addr_q.col + 'd1;
                            end
                        end else begin
                            read_addr_q.pixel <= read_addr_q.pixel - 'd1;
                        end
                    end else begin
                        read_addr_pipe[0] <= read_addr_q;
                        read_valid_pipe[0] <= 1'b0;
                    end

                    // Emit a write when the read data is aligned to the pipeline tail.
                    if (read_valid_pipe[READ_LATENCY - 1]) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        if (write_count == TOTAL_BYTES_LAST) begin
                            done <= 1'b1;
                            state <= STATE_DONE;
                        end
                        write_count <= write_count + 1;
                    end
                end
                STATE_DONE: begin
                    // Hold idle outputs for one cycle after done.
                    ram_access_start <= 1'b0;
                    state <= STATE_IDLE;
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end
`endif
endmodule
