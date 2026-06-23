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

    output logic                    sdram_req,
    output logic                    sdram_we,
    output types::sdram_word_addr_t sdram_addr,
    output types::sdram_byte_en_t   sdram_wdata_we,
    output types::sdram_word_data_t sdram_wdata,
    input  logic                    sdram_done,
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
    localparam types::sdram_word_addr_t BUFFER_WORDS_LAST = types::sdram_word_addr_t'(BUFFER_WORDS - 1);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_READ,
        STATE_WRITE
    } copy_state_t;
    copy_state_t state_q;

    types::sdram_word_addr_t word_q;
    types::sdram_word_data_t data_q;
    // Registered so sdram_addr/sdram_we are pure flop outputs instead of a live
    // combinational function of state_q/word_q: chaining that arithmetic
    // straight into the arbiter/LiteDRAM round trip with no register in
    // between blew timing at 80MHz (see PLAN.md 3.3 (build) hardware note).
    types::sdram_word_addr_t sdram_addr_q;
    logic sdram_we_q;

    wire types::sdram_word_addr_t front_base = frame_select ? types::sdram_word_addr_t'(BUFFER_WORDS) : '0;
    wire types::sdram_word_addr_t back_base = frame_select ? '0 : types::sdram_word_addr_t'(BUFFER_WORDS);
    wire types::sdram_word_addr_t next_word = word_q + 1'b1;

    assign sdram_req = state_q == STATE_READ || state_q == STATE_WRITE;
    assign sdram_we = sdram_we_q;
    assign sdram_addr = sdram_addr_q;
    assign sdram_wdata_we = '1;
    assign sdram_wdata = data_q;

    always @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            word_q <= '0;
            data_q <= '0;
            done <= 1'b0;
            sdram_addr_q <= '0;
            sdram_we_q <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state_q)
                STATE_IDLE: begin
                    if (enable) begin
`ifdef USE_SDRAM_DBUF_MIRROR
                        // Write mirroring (sdram_write_client) commits every host write
                        // to BOTH buffers, so they are already identical -- the front->back
                        // copy is a no-op. Skip it: the full-frame copy otherwise burns
                        // huge SDRAM bandwidth every frame and starves the display row
                        // fills (late fills -> stale/garbled bottom rows). Report done
                        // immediately so the host's command sequence keeps flowing.
                        done <= 1'b1;
`else
                        word_q <= '0;
                        state_q <= STATE_READ;
                        sdram_addr_q <= front_base;
                        sdram_we_q <= 1'b0;
`endif
                    end
                end
                STATE_READ: begin
                    if (sdram_done) begin
                        data_q <= sdram_rdata;
                        state_q <= STATE_WRITE;
                        sdram_addr_q <= back_base + word_q;
                        sdram_we_q <= 1'b1;
                    end
                end
                STATE_WRITE: begin
                    if (sdram_done) begin
                        if (word_q == BUFFER_WORDS_LAST) begin
                            done <= 1'b1;
                            state_q <= STATE_IDLE;
                        end else begin
                            word_q <= next_word;
                            state_q <= STATE_READ;
                            sdram_addr_q <= front_base + next_word;
                            sdram_we_q <= 1'b0;
                        end
                    end
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
