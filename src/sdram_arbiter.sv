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

    // When asserted, a pending client-0 (write) request PREEMPTS the otherwise
    // top-priority read fill at the arbitration point. Driven by the write client's
    // hysteretic FIFO pressure so a sustained host write burst can't be starved into
    // overflow (dropped pixels). Off in steady state -> reads keep their priority.
    input logic boost_writes,

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

    // PIPELINED copyframe client (read+write), served BETWEEN display fills only.
    // Like the prefetch read port but its commands carry a we bit, so copyframe
    // streams a run of reads then a run of writes (front->back buffer copy) at
    // ~bus rate. A pending fill (rd_req) preempts it; copyframe never runs inside a
    // fill burst, so its different-row accesses can't thrash the fill's DRAM row.
    input  logic                    cp_req,
    input  logic                    cp_we,
    input  types::sdram_word_addr_t cp_addr,
    input  types::sdram_byte_en_t   cp_wdata_we,
    input  types::sdram_word_data_t cp_wdata,
    output logic                    cp_cmd_ready,
    output logic                    cp_rvalid,
    output types::sdram_word_data_t cp_rdata,

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
        ARB_S_DONE,
        ARB_S_WBURST,  // back-to-back write drain (client 0) while the FIFO is pressured
        ARB_COPY       // pipelined copyframe burst (reads+writes) between fills
    } arb_state_t;

    arb_state_t state_q;
    logic [OUTSTANDING_BITS-1:0] outstanding_q;
    // Outstanding copyframe READS (so we know when the burst's read data has drained
    // before yielding the bus back to a preempting fill -- no read word is lost).
    logic [OUTSTANDING_BITS-1:0] cp_outstanding_q;

    logic [SIMPLE_IDX_BITS-1:0] s_active_q;
    logic s_active_we_q;
    logic cmd_done_q;
    logic data_done_q;
    types::sdram_word_data_t rdata_q;

    // Interleaved-write (client 0) progress, used only inside ARB_PREFETCH.
    logic iw_cmd_done_q;
    logic iw_data_done_q;
    // After an interleaved write, the fill is "owed" a run of read slots before the
    // next write may interleave. This bounds read starvation under a SUSTAINED write
    // stream (so the deadline-critical fill keeps progressing) while still serving
    // each write PROMPTLY the moment it arrives (rd_credit starts at 0).
    localparam logic [3:0] READS_PER_WRITE = 4'd7;
    logic [3:0] rd_credit_q;  // read slots still owed to the fill before the next write

    // Registered prefetch return (keeps rd_rvalid/rd_rdata flop-clean).
    logic                    rd_rvalid_q;
    types::sdram_word_data_t rd_rdata_q;

    // Registered copyframe read return (same flop-clean rule as the prefetch return).
    logic                    cp_rvalid_q;
    types::sdram_word_data_t cp_rdata_q;

    wire in_prefetch = (state_q == ARB_PREFETCH);
    wire in_copy     = (state_q == ARB_COPY);

    // Copyframe yields the bus to a fill: stop accepting new copy commands once a
    // fill is pending, finish draining the outstanding copy reads, then hand over.
    wire cp_preempt = rd_req;
    // A copyframe command is accepted to the port this cycle.
    wire cp_cmd_issue = in_copy && cp_req && cmd_ready && (!cp_we || wdata_ready) && !cp_preempt;
    // A copyframe READ command is accepted this cycle (only reads are tracked).
    wire cp_rd_issue  = cp_cmd_issue && !cp_we;
    // The copy burst is fully parked: client idle (or preempted) and all reads drained.
    wire cp_burst_done = in_copy && (!cp_req || cp_preempt) && (cp_outstanding_q == '0);

    // WRITE INTERLEAVE DISABLED (hardware fix, confirmed by led[2]=fill_overrun):
    // interleaving a back-buffer WRITE into the front-buffer READ fill forces the
    // SDRAM controller to precharge the read row and activate the write row (then
    // switch back) -- DRAM row "thrashing" that the flat-latency sim core charges
    // nothing for but that overran the fill deadline on real hardware. So the fill
    // burst now runs EXCLUSIVELY on its DRAM row; writes (and copyframe) drain
    // between fills via the simple path, batched on the write row. Keeping the host
    // fed during a fill is handled by the deeper write-client FIFO instead of by
    // interleaving. (iw_pending/iw_midway/iw_block/rd_credit are now inert.)
    wire iw_pending  = s_req[0];
    wire iw_midway   = iw_cmd_done_q || iw_data_done_q;
    wire burst_busy  = rd_req || (outstanding_q != '0);
    wire iw_block    = (rd_credit_q != '0) && rd_req;
    wire iw_serve    = 1'b0;
    wire _unused_iw  = &{1'b0, iw_pending, iw_midway, burst_busy, iw_block, 1'b0};

    // Interleaved-write command/data acceptance this cycle.
    wire iw_cmd_acc  = iw_cmd_done_q  || cmd_ready;
    wire iw_data_acc = iw_data_done_q || wdata_ready;
    wire iw_done     = iw_serve && iw_cmd_acc && iw_data_acc;

    // Prefetch read command accepted this cycle (only when not issuing a write, and not
    // while paused for a pressured write burst -- see ARB_PREFETCH below).
    wire prefetch_rd_issue = in_prefetch && !iw_serve && rd_req && cmd_ready && !boost_writes;
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

    // Write-burst (client 0) acceptance: gated by s_req[0] so a momentarily-empty FIFO
    // can't issue a phantom write with a stale address.
    wire wb_cmd_acc  = cmd_done_q  || (s_req[0] && cmd_ready);
    wire wb_data_acc = data_done_q || (s_req[0] && wdata_ready);
    wire wb_write_done = (state_q == ARB_S_WBURST) && s_req[0] && wb_cmd_acc && wb_data_acc;

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

        cp_cmd_ready = 1'b0;
        cp_rvalid = cp_rvalid_q;
        cp_rdata = cp_rdata_q;

        s_grant = '0;
        s_done = '0;
        s_rdata = rdata_q;

        if (in_copy) begin
            // Stream copyframe commands (read or write) -- UNLESS a fill is pending,
            // in which case stop issuing so the outstanding copy reads drain and the
            // fill can take the bus. copyframe holds its issue position (no cp_cmd_ready
            // returned) and resumes when we return to ARB_COPY.
            cmd_valid    = cp_req && !cp_preempt;
            cmd_we       = cp_we;
            cmd_addr     = cp_addr;
            wdata_valid  = cp_req && cp_we && !cp_preempt;
            wdata_we     = cp_wdata_we;
            wdata_data   = cp_wdata;
            cp_cmd_ready = cp_req && cmd_ready && (!cp_we || wdata_ready) && !cp_preempt;
        end else if (in_prefetch) begin
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
                // Stream a prefetch read command -- UNLESS the write FIFO is pressured,
                // in which case stop issuing reads so the outstanding ones can drain
                // before we hand the bus to the write burst (no read word is lost: the
                // already-issued reads still return while we're in ARB_PREFETCH).
                cmd_valid = rd_req && !boost_writes;
                cmd_we = 1'b0;
                cmd_addr = rd_addr;
                rd_cmd_ready = cmd_ready && !boost_writes;
            end
        end else if (state_q == ARB_S_WBURST) begin
            // Drain client 0 writes back-to-back (same DRAM row -> hits) until the FIFO
            // pressure clears. No read data, so no ordering hazard with prefetch.
            s_grant[0]  = 1'b1;
            cmd_valid   = s_req[0] && !cmd_done_q;
            cmd_we      = 1'b1;
            cmd_addr    = s_addr[0];
            wdata_valid = s_req[0] && !data_done_q;
            wdata_we    = s_wdata_we[0];
            wdata_data  = s_wdata[0];
            if (wb_write_done) s_done[0] = 1'b1;
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
            cp_outstanding_q <= '0;
            s_active_q <= '0;
            s_active_we_q <= 1'b0;
            cmd_done_q <= 1'b0;
            data_done_q <= 1'b0;
            iw_cmd_done_q <= 1'b0;
            iw_data_done_q <= 1'b0;
            rd_credit_q <= '0;
            rd_rvalid_q <= 1'b0;
            rd_rdata_q <= '0;
            cp_rvalid_q <= 1'b0;
            cp_rdata_q <= '0;
            rdata_q <= '0;
        end else begin
            // Registered prefetch data return: every port rdata during a burst
            // becomes one rd_rvalid pulse the next cycle (in command order).
            rd_rvalid_q <= in_prefetch && rdata_valid;
            if (in_prefetch && rdata_valid) rd_rdata_q <= rdata_data;

            // Registered copyframe read return: same rule, gated to the copy burst.
            // Returns during a copy burst all belong to copyframe (reads are never
            // interleaved with fill reads), so no per-read tagging is needed.
            cp_rvalid_q <= in_copy && rdata_valid;
            if (in_copy && rdata_valid) cp_rdata_q <= rdata_data;

            // Outstanding read accounting (writes don't count).
            if (in_prefetch) begin
                if (prefetch_rd_issue && !rdata_valid)
                    outstanding_q <= outstanding_q + 1'b1;
                else if (!prefetch_rd_issue && rdata_valid)
                    outstanding_q <= outstanding_q - 1'b1;
            end

            // Outstanding copyframe read accounting.
            if (in_copy) begin
                if (cp_rd_issue && !rdata_valid)
                    cp_outstanding_q <= cp_outstanding_q + 1'b1;
                else if (!cp_rd_issue && rdata_valid)
                    cp_outstanding_q <= cp_outstanding_q - 1'b1;
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

            // Read-credit for the write fairness: each interleaved write owes the
            // fill READS_PER_WRITE reads before the next write; reads spend the
            // credit. Reset on leaving the prefetch burst.
            if (in_prefetch) begin
                if (iw_done)
                    rd_credit_q <= READS_PER_WRITE;
                else if (prefetch_rd_issue && rd_credit_q != '0)
                    rd_credit_q <= rd_credit_q - 1'b1;
            end else begin
                rd_credit_q <= '0;
            end

            case (state_q)
                ARB_IDLE: begin
                    outstanding_q <= '0;
                    cp_outstanding_q <= '0;
                    if (init_done && boost_writes && s_req[0]) begin
                        // Write FIFO near overflow: drain writes (in a burst) ahead of
                        // the fill. A late fill is a transient flicker; a dropped write
                        // is a persistent wrong pixel -- the sanctioned trade.
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                        state_q <= ARB_S_WBURST;
                    end else if (init_done && rd_req) begin
                        state_q <= ARB_PREFETCH;
                    end else if (init_done && s_winner_valid) begin
                        s_active_q <= s_winner;
                        s_active_we_q <= s_we[s_winner];
                        state_q <= ARB_S_CMD;
                    end else if (init_done && cp_req) begin
                        // Lowest priority: copyframe runs only in idle bus time between
                        // fills/writes. A fill (rd_req) arriving mid-burst preempts it.
                        state_q <= ARB_COPY;
                    end
                end
                ARB_PREFETCH: begin
                    if (prefetch_done) begin
                        state_q <= ARB_IDLE;
                    end else if (boost_writes && s_req[0] && outstanding_q == '0) begin
                        // Fill paused (reads gated off above) and all outstanding read
                        // data has drained -> safe to hand the bus to the write burst.
                        // row_prefetch holds its issue position (no rd_cmd_ready), so the
                        // fill resumes correctly when we return to ARB_PREFETCH.
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                        state_q <= ARB_S_WBURST;
                    end
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
                ARB_COPY: begin
                    // Park the burst once the client is idle or a fill is pending AND all
                    // outstanding copy reads have returned (no read word stranded), then
                    // yield to ARB_IDLE so the fill (or write/idle) can take the bus next.
                    if (cp_burst_done) state_q <= ARB_IDLE;
                end
                ARB_S_DONE: state_q <= ARB_IDLE;
                ARB_S_WBURST: begin
                    if (!s_req[0]) begin
                        // FIFO drained -> hand the bus back to the (priority) read fill.
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                        state_q <= ARB_IDLE;
                    end else begin
                        if (!cmd_done_q && cmd_ready) cmd_done_q <= 1'b1;
                        if (!data_done_q && wdata_ready) data_done_q <= 1'b1;
                        if (wb_write_done) begin
                            cmd_done_q <= 1'b0;
                            data_done_q <= 1'b0;
                            // Keep bursting while still pressured; the client presents the
                            // next write. Once pressure clears, yield to reads.
                            if (!boost_writes) state_q <= ARB_IDLE;
                        end
                    end
                end
                default: state_q <= ARB_IDLE;
            endcase
        end
    end
endmodule
