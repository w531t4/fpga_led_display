// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// =============================================================================
// f4_row_probe -- F4 one-shot hardware diagnostic. Dumps, over UART, the DISPLAYED
// pixel data (read_data_out, the bytes leaving row_prefetch toward the panel) for
// one scan row, a few lines per second while the live scene runs.
//
// With SWEEP=1 it CYCLES the probed row across all PIXEL_HALFHEIGHT scan positions,
// one row per emitted line, so a single capture shows the whole field and reveals
// WHICH rows still carry garbage (e.g. a bottom-band fill-stall vs scattered copy
// corruption). With SWEEP=0 it stays on PROBE_ROW (used by the testbench).
//
// Each line: "<row:2hex><frame:1><NUM_SAMPLES samples:2hex each>\n"
//   <row>   = scan row this line sampled
//   <frame> = frame_select (which SDRAM buffer is on display, 0/1)
//   samples = NUM_SAMPLES strided low-bytes of read_data_out across that row.
// Compare lines for the SAME row across captures: bytes that scroll/garble where the
// background should be static -> the DATA fed to the panel is corrupt on that row.
//
// Drives the f2b UART pin (wifi_gpio25). 115200 8N1 by default.
// =============================================================================
module f4_row_probe #(
    parameter integer unsigned UART_TICKS_PER_BIT = 434,
    parameter integer unsigned PROBE_ROW   = 8,    // scan position when SWEEP=0
    parameter integer unsigned NUM_SAMPLES = 32,   // samples dumped across the row
    parameter integer unsigned THROTTLE    = 8,    // emit one line per THROTTLE row-scans
    parameter bit              SWEEP       = 1'b1  // cycle the probed row across all rows
) (
    input  wire                       clk,
    input  wire                       reset,
    input  types::row_subpanel_addr_t row_address,
    input  wire                       read_valid,       // a display read happens this cycle
    input  types::mem_read_data_t     read_data_out,
    input  wire                       frame_select,
    output wire                       tx
);
    localparam integer unsigned NUM_ROWS = params::PIXEL_HALFHEIGHT;
    localparam integer unsigned STRIDE = (params::PIXEL_WIDTH / NUM_SAMPLES) < 1
                                       ? 1 : (params::PIXEL_WIDTH / NUM_SAMPLES);
    localparam integer unsigned LINE_CHARS = 2 + 1 + NUM_SAMPLES * 2 + 1;  // row + frame + hex + '\n'

    function automatic logic [7:0] hexd(input logic [3:0] n);
        hexd = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h41 + ({4'd0, n} - 8'd10));
    endfunction

    // Row currently being probed (fixed at PROBE_ROW, or cycling when SWEEP).
    logic [$clog2(NUM_ROWS)-1:0] probe_row_q;
    wire types::row_subpanel_addr_t probe_row = types::row_subpanel_addr_t'(probe_row_q);
    wire in_row = (row_address == probe_row);
    logic in_row_q;

    logic [7:0] samp [NUM_SAMPLES];
    logic [7:0] samp_send [NUM_SAMPLES];
    logic frame_send;
    logic [$clog2(NUM_ROWS)-1:0] row_send;
    logic [$clog2(NUM_SAMPLES+1)-1:0] sidx;
    logic [$clog2(STRIDE+1)-1:0]      rdcnt;
    logic [$clog2(THROTTLE+1)-1:0]    throttle_q;

    typedef enum logic [1:0] {S_IDLE, S_KICK, S_WAIT} st_e;
    st_e state;
    logic [$clog2(LINE_CHARS+1)-1:0] cidx;
    logic start;
    logic [7:0] data;
    wire  tx_busy, tx_done;

    // current output char (combinational over the latched send buffer). k/odd are
    // assigned unconditionally (no latch); they're only read in the hex-sample branch.
    wire [7:0] row_send8 = 8'(row_send);  // zero-extended row index for hex nibbles
    logic [$clog2(NUM_SAMPLES)-1:0] k;
    logic odd;
    always_comb begin
        k   = ($clog2(NUM_SAMPLES))'((32'(cidx) - 3) >> 1);  // sample index for this char pair
        odd = ~cidx[0];                                      // 2nd hex nibble of the pair (low)
        if (cidx == 0) data = hexd(row_send8[7:4]);
        else if (cidx == 1) data = hexd(row_send8[3:0]);
        else if (cidx == 2) data = frame_send ? "1" : "0";
        else if (32'(cidx) <= NUM_SAMPLES * 2 + 2)
            data = odd ? hexd(samp_send[k][3:0]) : hexd(samp_send[k][7:4]);
        else data = 8'h0A;  // '\n'
    end

    always @(posedge clk) begin
        if (reset) begin
            in_row_q <= 1'b0; sidx <= '0; rdcnt <= '0; throttle_q <= '0;
            state <= S_IDLE; cidx <= '0; start <= 1'b0; frame_send <= 1'b0;
            probe_row_q <= ($clog2(NUM_ROWS))'(PROBE_ROW); row_send <= '0;
        end else begin
            in_row_q <= in_row;
            start <= 1'b0;

            // ---- strided capture of read_data_out across the probed row ----
            if (in_row && !in_row_q) begin
                sidx <= '0; rdcnt <= '0;                  // (re)start the row capture
            end else if (in_row && read_valid) begin
                if (rdcnt == ($clog2(STRIDE+1))'(STRIDE - 1)) begin
                    rdcnt <= '0;
                    if (sidx < ($clog2(NUM_SAMPLES+1))'(NUM_SAMPLES)) begin
                        samp[sidx] <= read_data_out.raw[7:0];
                        sidx <= sidx + 1'b1;
                    end
                end else rdcnt <= rdcnt + 1'b1;
            end

            // ---- on row exit: throttle, then latch + kick a line send ----
            if (!in_row && in_row_q && state == S_IDLE) begin
                if (throttle_q == ($clog2(THROTTLE+1))'(THROTTLE - 1)) begin
                    throttle_q <= '0;
                    for (int i = 0; i < NUM_SAMPLES; i++) samp_send[i] <= samp[i];
                    frame_send <= frame_select;
                    row_send   <= probe_row_q;
                    cidx  <= '0;
                    state <= S_KICK;
                    // advance to the next row for the following line (SWEEP only)
                    if (SWEEP)
                        probe_row_q <= (probe_row_q == ($clog2(NUM_ROWS))'(NUM_ROWS - 1))
                                     ? '0 : probe_row_q + 1'b1;
                end else throttle_q <= throttle_q + 1'b1;
            end

            // ---- byte-at-a-time UART send ----
            case (state)
                S_KICK: if (!tx_busy) begin start <= 1'b1; state <= S_WAIT; end
                S_WAIT: if (tx_done) begin
                            if (cidx == ($clog2(LINE_CHARS+1))'(LINE_CHARS - 1)) state <= S_IDLE;
                            else begin cidx <= cidx + 1'b1; state <= S_KICK; end
                        end
                default: ;
            endcase
        end
    end

    uart_tx #(.TICKS_PER_BIT(UART_TICKS_PER_BIT)) u_tx (
        .i_clk(clk), .i_start(start), .i_data(data), .o_done(tx_done), .o_busy(tx_busy), .o_dout(tx)
    );
endmodule
