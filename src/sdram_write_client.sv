// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Depth of the write FIFO (must be a power of 2). The arbiter no longer interleaves
// writes into a prefetch read fill (that thrashed DRAM rows and overran the fill on
// real hardware), so writes only drain BETWEEN fills -- this FIFO must hold a full
// fill's worth of host writes so the (un-stallable) host isn't dropped mid-command.
// Sized for ~a display-row fill duration at the host write rate, with margin.
// Overridable per-build, e.g. EXTRA_BUILD_FLAGS="... -DSDRAM_WRITE_FIFO_DEPTH=256".
`ifndef SDRAM_WRITE_FIFO_DEPTH
`define SDRAM_WRITE_FIFO_DEPTH 512
`endif

// sdram_write_client: Converts control_module's existing per-byte BRAM-style write
// output into a priority-2 client of sdram_arbiter. One write at a time -- `ready`
// gates control_module's `ready_for_data` so the host can't outrun us.
module sdram_write_client #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0,
    // verilator lint_on UNUSEDPARAM
    // Double-buffer write mirror (see the block comment below). Defaults to the
    // build-time `ifdef so synthesis is unchanged; exposed as a parameter only so a
    // testbench can instantiate both MIRROR=0 and MIRROR=1 in one compile.
`ifdef USE_SDRAM_DBUF_MIRROR
    parameter bit MIRROR = 1'b1
`else
    parameter bit MIRROR = 1'b0
`endif
) (
    input logic reset,
    input logic clk_in,

    // 0/1 (or tied to 1'b0 without DOUBLE_BUFFER); writes always target the back
    // buffer, i.e. the opposite of whichever frame row_prefetch is displaying.
    input logic frame_select,

    input types::mem_write_addr_t source_addr,
    input types::mem_write_data_t source_data,
    input logic                   source_write_valid,

    output logic ready,
    // High only when every accepted write has COMMITTED to SDRAM (FIFO empty and
    // no in-flight write). control_module gates `busy` on this so the host can't
    // swap the frame (TOGGLE_FRAME) before the delta tail lands -> no stale pixels.
    // (`ready` = !full is NOT sufficient: it is high with up to DEPTH writes still
    // queued.)
    output logic drained,
    // STICKY (-> LED): a host write arrived while the FIFO was FULL, so push was
    // gated off and the byte was LOST. Makes the persistent-wrong-pixels failure
    // observable: on real DRAM the one-at-a-time write drain can't keep up with a
    // sustained host write burst, the FIFO fills, and writes are silently dropped.
    output logic dropped,
    // HYSTERETIC backpressure-demand (-> arbiter boost_writes): asserts when the FIFO
    // crosses HIGH_WATER and holds until it drains below LOW_WATER. The arbiter uses
    // it to let writes PREEMPT the (otherwise top-priority) read fill, so a sustained
    // host write burst can't starve the drain into overflow + dropped pixels. Costs at
    // most an occasional late fill (transient), never a lost write.
    output logic wr_pressure,

    output logic                    sdram_req,
    input  logic                    sdram_done,
    output types::sdram_word_addr_t sdram_addr,
    output types::sdram_byte_en_t   sdram_wdata_we,
    output types::sdram_word_data_t sdram_wdata
);
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;

    // Write FIFO (depth DEPTH) ahead of a single arbiter-facing in-flight slot.
    //
    // WHY A DEEP FIFO (not a 1-deep skid): the ESP32 is the SPI master and CANNOT
    // be stalled mid-command -- `ready`/control_module's ready_for_data is NOT
    // wired off-chip (the only off-chip flow control is the command-level `busy`
    // line, polled between commands). So within one host write command
    // (readrow/readrect/readframe) the FPGA must absorb every byte at the SPI rate
    // or that byte is silently dropped on the wire, desyncing the pixel stream --
    // the "persistent wrong pixels / failed to interpret ESP32 data" hardware
    // failure. (Reproduced in sim by tb_main + -DTB_SPI_FREERUN, which free-runs
    // the modeled master like the real ESP32; a 1-deep skid drops bytes there.)
    // The SDRAM has ~30x the host's average write bandwidth even while sharing the
    // bus with prefetch, so a FIFO this deep rides out the prefetch-fill bursts and
    // keeps `ready` high for the whole command. DEPTH is overridable for tuning.
    //
    // CRITICAL PATH: the deep src_addr arithmetic (calc::sdram_word_addr) ONLY
    // lands at the FIFO write port; the arbiter-facing sdram_addr_q is a plain
    // register copy of the FIFO head (no arithmetic in that path). Driving
    // src_addr straight into sdram_addr_q's input mux dropped the SDRAM-clock Fmax
    // below 80MHz (see PLAN.md 3.3 hardware note); keeping it behind the FIFO
    // restores it.
    localparam int unsigned DEPTH = `SDRAM_WRITE_FIFO_DEPTH;
    localparam int unsigned PTR_BITS = $clog2(DEPTH);

    // DOUBLE-BUFFER WRITE MIRROR: the host (ESPHome display_layout) is a delta-only,
    // persistent-canvas renderer -- it never redraws the full frame; each frame only the
    // changed regions are written, and it relies on the ESP32 driver's copyFrame to keep
    // the two SDRAM buffers identical. On real DRAM copyframe is far too slow and gets
    // raced/dropped, so the buffers desync and stale pixels survive exactly where content
    // moved (the persistent trail). Mirroring every host write into BOTH buffers keeps
    // them identical by construction, so a slow/dropped copyframe can no longer desync
    // them. Each FIFO entry is then drained as TWO writes (buffer 0, then buffer 1).
    // (MIRROR is a module parameter, defaulted from USE_SDRAM_DBUF_MIRROR above.)
    localparam types::sdram_word_addr_t BUFFER_WORDS_OFFSET =
        types::sdram_word_addr_t'(calc::num_sdram_buffer_words(params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT,
                                                                NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES));
    // Demand-backpressure watermarks: start preempting reads at 3/4 full, stop once
    // back down to 1/2 (hysteresis avoids flapping read/write priority every cycle).
    localparam int unsigned HIGH_WATER = DEPTH - (DEPTH / 4);
    localparam int unsigned LOW_WATER  = DEPTH / 2;

    types::sdram_word_addr_t fifo_addr_q [DEPTH];   // deep arith lands here (write port)
    types::sdram_byte_en_t   fifo_we_q   [DEPTH];
    types::sdram_word_data_t fifo_data_q [DEPTH];
    logic [PTR_BITS-1:0]     wr_ptr_q, rd_ptr_q;
    logic [PTR_BITS:0]       count_q;               // occupancy 0..DEPTH

    logic inflight_q;                               // a write issued to the arbiter, awaiting sdram_done
    logic dropped_q;                                // STICKY: a host write was lost to a full FIFO
    logic wr_pressure_q;                            // hysteretic: FIFO is filling, preempt reads to drain
    types::sdram_word_addr_t sdram_addr_q;          // in-flight (arbiter-facing) regs -- register copy of FIFO head
    types::sdram_word_addr_t sdram_addr_mirror_q;   // buffer-1 copy of the in-flight write (mirror, +BUFFER_WORDS)
    logic                    mirror_phase_q;        // 0 = issuing the buffer-0 write, 1 = the buffer-1 write
    types::sdram_byte_en_t   sdram_wdata_we_q;
    types::sdram_word_data_t sdram_wdata_q;

    wire word_select_in = calc::sdram_pixel_word_select($bits(int)'(source_addr.pixel), params::SDRAM_WORD_BYTES);
    wire types::sdram_byte_in_word_t byte_in_word_in =
        types::sdram_byte_in_word_t'(calc::sdram_byte_in_word_select($bits(int)'(source_addr.pixel),
                                                                      params::SDRAM_WORD_BYTES));
    // With mirroring, write to the canonical frame-0 buffer (frame 1 is reached by
    // +BUFFER_WORDS in the drain); without it, the back buffer (~frame_select) as before.
    wire src_frame = MIRROR ? 1'b0 : ~frame_select;
    wire types::sdram_word_addr_t src_addr =
        calc::sdram_word_addr(src_frame, $bits(int)'(source_addr.row), $bits(int)'(source_addr.col),
                              source_addr.subpanel, word_select_in, params::PIXEL_WIDTH,
                              params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES);
    wire types::sdram_byte_en_t   src_wdata_we = types::sdram_byte_en_t'(1 << byte_in_word_in);
    wire types::sdram_word_data_t src_wdata =
        types::sdram_word_data_t'($bits(int)'(source_data) << (byte_in_word_in * 8));

    // A FIFO entry is fully written once its buffer-0 write (and, when mirroring, its
    // buffer-1 write) has been acknowledged by the arbiter.
    wire entry_done    = inflight_q && sdram_done && (!MIRROR || mirror_phase_q);
    wire inflight_free = !inflight_q || entry_done;
    wire empty = (count_q == '0);
    wire full  = count_q[PTR_BITS];                 // count_q == DEPTH (DEPTH is 2**PTR_BITS)

    wire push = source_write_valid && !full;        // accept a host write into the FIFO tail
`ifdef SDRAM_SIM_SLOW_WRITES
    // SIM-ONLY (never synthesized): periodically stall write draining to mimic the
    // real-DRAM stalls (refresh / tRC / row-miss, plus longer prefetch fills) that
    // the optimistic SDRAMPHYModel doesn't model -- so the sim can reproduce the
    // on-chip write-overrun byte drop and demonstrate this FIFO's depth fixing it.
    // Stalls draining SDRAM_SIM_WRITE_PAUSE cycles out of every SDRAM_SIM_WRITE_PERIOD.
    `ifndef SDRAM_SIM_WRITE_PERIOD
    `define SDRAM_SIM_WRITE_PERIOD 2000
    `endif
    `ifndef SDRAM_SIM_WRITE_PAUSE
    `define SDRAM_SIM_WRITE_PAUSE 200
    `endif
    int unsigned throttle_cnt_q = 0;
    wire write_drain_paused = (throttle_cnt_q < `SDRAM_SIM_WRITE_PAUSE);
    always @(posedge clk_in)
        throttle_cnt_q <= (reset || throttle_cnt_q >= `SDRAM_SIM_WRITE_PERIOD - 1) ? 0 : throttle_cnt_q + 1;
`else
    wire write_drain_paused = 1'b0;
`endif
    wire pop  = inflight_free && !empty && !write_drain_paused;  // move FIFO head into the in-flight slot

    assign ready = !full;
    assign drained = empty && !inflight_q;
    assign dropped = dropped_q;
    assign wr_pressure = wr_pressure_q;
    assign sdram_req = inflight_q;
    assign sdram_addr = (MIRROR && mirror_phase_q) ? sdram_addr_mirror_q : sdram_addr_q;
    assign sdram_wdata_we = sdram_wdata_we_q;
    assign sdram_wdata = sdram_wdata_q;

    always @(posedge clk_in) begin
        if (reset) begin
            inflight_q <= 1'b0;
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q <= '0;
            sdram_addr_q <= '0;
            sdram_addr_mirror_q <= '0;
            mirror_phase_q <= 1'b0;
            sdram_wdata_we_q <= '0;
            sdram_wdata_q <= '0;
            dropped_q <= 1'b0;
            wr_pressure_q <= 1'b0;
        end else begin
            // A host write presented while full is lost (push is gated by !full).
            if (source_write_valid && full) dropped_q <= 1'b1;

            // Hysteretic fill-pressure: demand read-preemption above HIGH_WATER, release
            // below LOW_WATER.
            if (count_q >= (PTR_BITS+1)'(HIGH_WATER)) wr_pressure_q <= 1'b1;
            else if (count_q <= (PTR_BITS+1)'(LOW_WATER)) wr_pressure_q <= 1'b0;

            // Push: capture a new source write into the FIFO tail. This is the only
            // flop the deep src_addr arithmetic feeds.
            if (push) begin
                fifo_addr_q[wr_ptr_q] <= src_addr;
                fifo_we_q[wr_ptr_q]   <= src_wdata_we;
                fifo_data_q[wr_ptr_q] <= src_wdata;
                wr_ptr_q <= wr_ptr_q + 1'b1;
            end

            // Mirror: once the buffer-0 write is accepted, advance to the buffer-1 write
            // before this entry is considered done / popped.
            if (MIRROR && inflight_q && sdram_done && !mirror_phase_q) mirror_phase_q <= 1'b1;

            // Pop: promote the FIFO head into the freeing in-flight slot. Plain register
            // copy from the FIFO read port; the +BUFFER_WORDS for the buffer-1 mirror is
            // registered here too (not in the arbiter-facing path) to keep timing.
            if (pop) begin
                sdram_addr_q        <= fifo_addr_q[rd_ptr_q];
                sdram_addr_mirror_q <= fifo_addr_q[rd_ptr_q] + BUFFER_WORDS_OFFSET;
                sdram_wdata_we_q    <= fifo_we_q[rd_ptr_q];
                sdram_wdata_q       <= fifo_data_q[rd_ptr_q];
                inflight_q          <= 1'b1;
                mirror_phase_q      <= 1'b0;
                rd_ptr_q            <= rd_ptr_q + 1'b1;
            end else if (inflight_free) begin
                inflight_q <= 1'b0;
            end

            // Occupancy: push and pop may co-occur (host streams the next byte as a
            // write completes), netting zero change -- only a lone push/pop moves it.
            if (push && !pop)
                count_q <= count_q + 1'b1;
            else if (pop && !push)
                count_q <= count_q - 1'b1;
        end
    end
endmodule
