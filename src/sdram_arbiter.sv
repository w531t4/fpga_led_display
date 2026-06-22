// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// sdram_arbiter: muxes the single LiteDRAM native port among one high-priority
// PIPELINED read client (row_prefetch) and NUM_SIMPLE one-at-a-time clients
// (index 0 = write, index 1 = copyframe).
//
// Prefetch path (rd_*): while bursting, the arbiter passes the client's read
// command straight to the port and streams returned words back WITHOUT waiting
// for each word's data before issuing the next command. Many reads are
// outstanding at once (bounded by the port's cmd_ready backpressure), so a row
// fill takes ~WORDS cycles + one round trip instead of WORDS round trips -- the
// only way the fill meets its display-row deadline at real DRAM latency.
//
// Write interleave: a pending simple WRITE (client 0) is issued *inside* the
// prefetch read burst. Writes produce no read data, so they don't disturb the
// in-order return of the outstanding reads -- this lets the host keep streaming
// pixels during a fill instead of stalling for the whole burst. Simple READS
// (copyframe) are not interleaved (their data would mix with prefetch's); they
// wait for the burst to drain, which is fine since they aren't latency critical.
//
// Simple path (s_*, between bursts): unchanged one-transaction-at-a-time
// req/grant/done -- issue cmd (+wdata for writes), wait for completion, pulse done.
//
// rd_rvalid/s_done/s_rdata-style outputs are registered to stay flop-clean;
// chaining cmd_ready/wdata_ready/rdata_valid straight through blew timing at
// 80MHz (see PLAN.md 3.3 (build) hardware note).
module sdram_arbiter #(
    parameter int unsigned NUM_SIMPLE = 2
) (
    input logic clk,
    input logic reset,
    input logic init_done,

    // Pipelined read-only client (row_prefetch), highest priority.
    input  logic                    rd_req,
    input  types::sdram_word_addr_t rd_addr,
    output logic                    rd_cmd_ready,
    output logic                    rd_rvalid,
    output types::sdram_word_data_t rd_rdata,

    // One-at-a-time clients (index 0 = write, highest priority among these).
    input  logic                    [NUM_SIMPLE-1:0] s_req,
    input  logic                    [NUM_SIMPLE-1:0] s_we,
    input  types::sdram_word_addr_t [NUM_SIMPLE-1:0] s_addr,
    input  types::sdram_byte_en_t   [NUM_SIMPLE-1:0] s_wdata_we,
    input  types::sdram_word_data_t [NUM_SIMPLE-1:0] s_wdata,
    output logic                    [NUM_SIMPLE-1:0] s_grant,
    output logic                    [NUM_SIMPLE-1:0] s_done,
    output types::sdram_word_data_t                  s_rdata,

    output logic                    cmd_valid,
    input  logic                    cmd_ready,
    output logic                    cmd_we,
    output types::sdram_word_addr_t cmd_addr,

    output logic                    wdata_valid,
    input  logic                    wdata_ready,
    output types::sdram_byte_en_t   wdata_we,
    output types::sdram_word_data_t wdata_data,

    input  logic                    rdata_valid,
    output logic                    rdata_ready,
    input  types::sdram_word_data_t rdata_data
);
    localparam int unsigned SIMPLE_IDX_BITS = calc::safe_clog2(NUM_SIMPLE);
    localparam int unsigned OUTSTANDING_BITS = 6;  // wide enough to never wrap

    typedef enum logic [2:0] {
        ARB_IDLE,
        ARB_PREFETCH,
        ARB_S_CMD,
        ARB_S_RWAIT,
        ARB_S_DONE
    } arb_state_t;

    arb_state_t state_q;
    logic [OUTSTANDING_BITS-1:0] outstanding_q;

    logic [SIMPLE_IDX_BITS-1:0] s_active_q;
    logic s_active_we_q;
    logic cmd_done_q;
    logic data_done_q;
    types::sdram_word_data_t rdata_q;

    // Interleaved-write (client 0) progress, used only inside ARB_PREFETCH.
    logic iw_cmd_done_q;
    logic iw_data_done_q;

    // Registered prefetch return (keeps rd_rvalid/rd_rdata flop-clean).
    logic                    rd_rvalid_q;
    types::sdram_word_data_t rd_rdata_q;

    wire in_prefetch = (state_q == ARB_PREFETCH);

    // Serve an interleaved write only while the burst is genuinely active (reads
    // pending or outstanding) or one is already mid-flight -- never start a fresh
    // write just as the burst is draining, so the burst can exit cleanly.
    wire iw_pending = s_req[0];
    wire iw_midway  = iw_cmd_done_q || iw_data_done_q;
    wire burst_busy = rd_req || (outstanding_q != '0);
    wire iw_serve   = in_prefetch && iw_pending && (burst_busy || iw_midway);

    // Interleaved-write command/data acceptance this cycle.
    wire iw_cmd_acc  = iw_cmd_done_q  || cmd_ready;
    wire iw_data_acc = iw_data_done_q || wdata_ready;
    wire iw_done     = iw_serve && iw_cmd_acc && iw_data_acc;

    // Prefetch read command accepted this cycle (only when not issuing a write).
    wire prefetch_rd_issue = in_prefetch && !iw_serve && rd_req && cmd_ready;
    wire prefetch_done = in_prefetch && !rd_req && (outstanding_q == '0) && !iw_serve && !iw_midway;

    // Highest-priority requesting simple client (index 0 wins ties).
    logic [SIMPLE_IDX_BITS-1:0] s_winner;
    logic                       s_winner_valid;
    always_comb begin
        s_winner = '0;
        s_winner_valid = 1'b0;
        for (int i = NUM_SIMPLE - 1; i >= 0; i--) begin
            if (s_req[i]) begin
                s_winner = SIMPLE_IDX_BITS'(i);
                s_winner_valid = 1'b1;
            end
        end
    end

    wire s_cmd_accepted = cmd_done_q || (!cmd_done_q && cmd_ready);
    wire s_data_accepted = data_done_q || (!data_done_q && wdata_ready);
    wire s_write_done = (state_q == ARB_S_CMD) && s_active_we_q && s_cmd_accepted && s_data_accepted;
    wire s_read_cmd_accepted = (state_q == ARB_S_CMD) && !s_active_we_q && s_cmd_accepted;
    wire s_read_done = (state_q == ARB_S_RWAIT) && rdata_valid;

    always_comb begin
        cmd_valid = 1'b0;
        cmd_we = 1'b0;
        cmd_addr = '0;
        wdata_valid = 1'b0;
        wdata_we = '0;
        wdata_data = '0;
        rdata_ready = 1'b1;

        rd_cmd_ready = 1'b0;
        rd_rvalid = rd_rvalid_q;
        rd_rdata = rd_rdata_q;

        s_grant = '0;
        s_done = '0;
        s_rdata = rdata_q;

        if (in_prefetch) begin
            if (iw_serve) begin
                // Interleave client-0's write into the read stream.
                s_grant[0] = 1'b1;
                cmd_valid   = !iw_cmd_done_q;
                cmd_we      = 1'b1;
                cmd_addr    = s_addr[0];
                wdata_valid = !iw_data_done_q;
                wdata_we    = s_wdata_we[0];
                wdata_data  = s_wdata[0];
                if (iw_done) s_done[0] = 1'b1;
            end else begin
                // Stream a prefetch read command.
                cmd_valid = rd_req;
                cmd_we = 1'b0;
                cmd_addr = rd_addr;
                rd_cmd_ready = cmd_ready;
            end
        end else if (state_q == ARB_S_CMD || state_q == ARB_S_RWAIT || state_q == ARB_S_DONE) begin
            s_grant[s_active_q] = 1'b1;
            if (state_q == ARB_S_CMD) begin
                cmd_valid   = !cmd_done_q;
                cmd_we      = s_active_we_q;
                cmd_addr    = s_addr[s_active_q];
                wdata_valid = s_active_we_q && !data_done_q;
                wdata_we    = s_wdata_we[s_active_q];
                wdata_data  = s_wdata[s_active_q];
            end
            if (state_q == ARB_S_DONE) s_done[s_active_q] = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= ARB_IDLE;
            outstanding_q <= '0;
            s_active_q <= '0;
            s_active_we_q <= 1'b0;
            cmd_done_q <= 1'b0;
            data_done_q <= 1'b0;
            iw_cmd_done_q <= 1'b0;
            iw_data_done_q <= 1'b0;
            rd_rvalid_q <= 1'b0;
            rd_rdata_q <= '0;
            rdata_q <= '0;
        end else begin
            // Registered prefetch data return: every port rdata during a burst
            // becomes one rd_rvalid pulse the next cycle (in command order).
            rd_rvalid_q <= in_prefetch && rdata_valid;
            if (in_prefetch && rdata_valid) rd_rdata_q <= rdata_data;

            // Outstanding read accounting (writes don't count).
            if (in_prefetch) begin
                if (prefetch_rd_issue && !rdata_valid)
                    outstanding_q <= outstanding_q + 1'b1;
                else if (!prefetch_rd_issue && rdata_valid)
                    outstanding_q <= outstanding_q - 1'b1;
            end

            // Interleaved-write progress within the burst.
            if (in_prefetch) begin
                if (iw_done) begin
                    iw_cmd_done_q <= 1'b0;
                    iw_data_done_q <= 1'b0;
                end else if (iw_serve) begin
                    if (!iw_cmd_done_q && cmd_ready) iw_cmd_done_q <= 1'b1;
                    if (!iw_data_done_q && wdata_ready) iw_data_done_q <= 1'b1;
                end
            end

            case (state_q)
                ARB_IDLE: begin
                    outstanding_q <= '0;
                    if (init_done && rd_req) begin
                        state_q <= ARB_PREFETCH;
                    end else if (init_done && s_winner_valid) begin
                        s_active_q <= s_winner;
                        s_active_we_q <= s_we[s_winner];
                        state_q <= ARB_S_CMD;
                    end
                end
                ARB_PREFETCH: begin
                    if (prefetch_done) state_q <= ARB_IDLE;
                end
                ARB_S_CMD: begin
                    if (!cmd_done_q && cmd_ready) cmd_done_q <= 1'b1;
                    if (s_active_we_q && !data_done_q && wdata_ready) data_done_q <= 1'b1;
                    if (s_write_done) begin
                        state_q <= ARB_S_DONE;
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                    end else if (s_read_cmd_accepted) begin
                        state_q <= ARB_S_RWAIT;
                        cmd_done_q <= 1'b0;
                    end
                end
                ARB_S_RWAIT: begin
                    if (s_read_done) begin
                        rdata_q <= rdata_data;
                        state_q <= ARB_S_DONE;
                    end
                end
                ARB_S_DONE: state_q <= ARB_IDLE;
                default: state_q <= ARB_IDLE;
            endcase
        end
    end
endmodule
