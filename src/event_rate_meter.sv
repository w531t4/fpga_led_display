// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Sliding-window event rate meter.
// inputs: one-clk event pulses
// output: count of events over the last BINS complete bins
//
// Mental model: counting cars on a road, always wanting the total over a few
// recent minutes. Keep a notepad with one line per recent minute and a
// running TOTAL in the corner. Each minute: jot the minute that just
// finished, erase the one now too old, and fix TOTAL by +new -erased --
// never re-adding the whole pad. Only FINISHED minutes count (the minute in
// progress isn't in TOTAL yet), so TOTAL steps once a minute.
//
// Contract:
//   - time is divided into bins of BIN_TICKS clks; count sums the BINS most
//     recently COMPLETED bins (the in-progress bin is excluded)
//   - count updates once per bin boundary and holds between boundaries
//   - a full window with no events decays count back to 0
//   - count cannot overflow: at most one event per clk, so
//     count <= BINS * BIN_TICKS by construction
//   - reset zeroes the window (count restarts from an empty history)
module event_rate_meter #(
    parameter integer unsigned BIN_TICKS = 1,
    parameter integer unsigned BINS = 1,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0,
    // verilator lint_on UNUSEDPARAM
    // Derived (localparam: not overridable): worst case is one event per clk.
    localparam integer unsigned COUNT_BITS = calc::safe_clog2(BINS * BIN_TICKS + 1)
) (
    input                         clk,
    input                         reset,
    input                         event_pulse,
    output logic [COUNT_BITS-1:0] count
);
    // Indexes the tick within the current bin, 0..BIN_TICKS-1.
    typedef logic [calc::safe_clog2(BIN_TICKS)-1:0] tick_index_t;
    localparam tick_index_t TICK_LAST = tick_index_t'(BIN_TICKS - 1);

    // Events within one bin, 0..BIN_TICKS inclusive.
    typedef logic [calc::safe_clog2(BIN_TICKS+1)-1:0] bin_count_t;

    tick_index_t tick_index;
    wire bin_boundary = (tick_index == TICK_LAST);

    // The in-progress bin's event count.
    bin_count_t live_bin;
    // Completed bins, oldest at index BINS-1 (shifted out at each boundary).
    bin_count_t bins_q[BINS];

    always @(posedge clk) begin
        if (reset) begin
            tick_index <= '0;
            live_bin   <= '0;
            count      <= '0;
            for (int unsigned b = 0; b < BINS; b = b + 1) begin
                bins_q[b] <= '0;
            end
        end else if (bin_boundary) begin
            tick_index <= '0;
            // Close the live bin (including an event on this very clk),
            // retire the oldest, and adjust the running sum with both.
            bins_q[0]  <= live_bin + bin_count_t'(event_pulse);
            for (int unsigned b = 1; b < BINS; b = b + 1) begin
                bins_q[b] <= bins_q[b-1];
            end
            count <= count + COUNT_BITS'(live_bin) + COUNT_BITS'(event_pulse) - COUNT_BITS'(bins_q[BINS-1]);
            live_bin <= '0;
        end else begin
            tick_index <= tick_index + 1'b1;
            if (event_pulse) live_bin <= live_bin + 1'b1;
        end
    end
endmodule
