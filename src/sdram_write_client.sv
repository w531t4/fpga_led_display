// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// sdram_write_client: Converts control_module's existing per-byte BRAM-style write
// output into a priority-2 client of sdram_arbiter. One write at a time -- `ready`
// gates control_module's `ready_for_data` so the host can't outrun us.
module sdram_write_client #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
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

    output logic                    sdram_req,
    input  logic                    sdram_done,
    output types::sdram_word_addr_t sdram_addr,
    output types::sdram_byte_en_t   sdram_wdata_we,
    output types::sdram_word_data_t sdram_wdata
);
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;

    // 1-deep skid buffer (capacity 2: one in-flight to the arbiter + one
    // pending). Without it the client was strictly one-at-a-time, so `ready`
    // (which gates control_module's ready_for_data) stayed low for a whole write
    // round trip after every byte and the host SPI serialized as SPI-byte-time +
    // write-round-trip per byte. Buffering one write lets the host stream the
    // next byte while the current write is in flight, so the write overlaps the
    // next SPI transfer and large host writes (readrow/readframe) run near their
    // SPI floor.
    //
    // CRITICAL PATH: the deep src_addr arithmetic (calc::sdram_word_addr) ONLY
    // lands in the pending/skid registers; the arbiter-facing sdram_addr_q is
    // loaded by a plain register copy (pending -> in-flight). Driving src_addr
    // straight into sdram_addr_q's input mux dropped the SDRAM-clock Fmax below
    // 80MHz (see PLAN.md 3.3 hardware note); keeping it one stage back restores it.
    logic inflight_q;    // a write issued to the arbiter, awaiting sdram_done
    logic pend_valid_q;  // a captured write buffered behind the in-flight one

    types::sdram_word_addr_t sdram_addr_q;      // in-flight (arbiter-facing) regs
    types::sdram_byte_en_t   sdram_wdata_we_q;
    types::sdram_word_data_t sdram_wdata_q;
    types::sdram_word_addr_t pend_addr_q;       // buffered next write (deep arith lands here)
    types::sdram_byte_en_t   pend_wdata_we_q;
    types::sdram_word_data_t pend_wdata_q;

    wire word_select_in = calc::sdram_pixel_word_select($bits(int)'(source_addr.pixel), params::SDRAM_WORD_BYTES);
    wire types::sdram_byte_in_word_t byte_in_word_in =
        types::sdram_byte_in_word_t'(calc::sdram_byte_in_word_select($bits(int)'(source_addr.pixel),
                                                                      params::SDRAM_WORD_BYTES));
    wire types::sdram_word_addr_t src_addr =
        calc::sdram_word_addr(~frame_select, $bits(int)'(source_addr.row), $bits(int)'(source_addr.col),
                              source_addr.subpanel, word_select_in, params::PIXEL_WIDTH,
                              params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES, params::SDRAM_WORD_BYTES);
    wire types::sdram_byte_en_t   src_wdata_we = types::sdram_byte_en_t'(1 << byte_in_word_in);
    wire types::sdram_word_data_t src_wdata =
        types::sdram_word_data_t'($bits(int)'(source_data) << (byte_in_word_in * 8));

    wire inflight_free = !inflight_q || sdram_done;

    assign ready = !pend_valid_q || inflight_free;
    assign sdram_req = inflight_q;
    assign sdram_addr = sdram_addr_q;
    assign sdram_wdata_we = sdram_wdata_we_q;
    assign sdram_wdata = sdram_wdata_q;

    always @(posedge clk_in) begin
        if (reset) begin
            inflight_q <= 1'b0;
            pend_valid_q <= 1'b0;
            sdram_addr_q <= '0;
            sdram_wdata_we_q <= '0;
            sdram_wdata_q <= '0;
            pend_addr_q <= '0;
            pend_wdata_we_q <= '0;
            pend_wdata_q <= '0;
        end else begin
            // Issue: promote the pending write into the freeing in-flight slot.
            // Register-to-register copy only -- no arithmetic in this path.
            if (inflight_free) begin
                if (pend_valid_q) begin
                    sdram_addr_q     <= pend_addr_q;
                    sdram_wdata_we_q <= pend_wdata_we_q;
                    sdram_wdata_q    <= pend_wdata_q;
                    inflight_q       <= 1'b1;
                    pend_valid_q     <= 1'b0;
                end else begin
                    inflight_q <= 1'b0;
                end
            end

            // Capture a new source write into the pending slot. This is the only
            // flop the deep src_addr arithmetic feeds. Non-blocking semantics let
            // an issue (reading old pend_*) and a capture (writing new pend_*)
            // co-occur, so steady-state throughput stays one write per cycle-pair.
            if (source_write_valid && ready) begin
                pend_addr_q     <= src_addr;
                pend_wdata_we_q <= src_wdata_we;
                pend_wdata_q    <= src_wdata;
                pend_valid_q    <= 1'b1;
            end
        end
    end
endmodule
