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

    typedef enum logic {
        STATE_IDLE,
        STATE_WRITE
    } write_state_t;
    write_state_t state_q;

    // Registered so sdram_addr/sdram_wdata_we/sdram_wdata are pure flop outputs
    // instead of a live combinational function of addr_q/data_q: computing
    // them on the fly chained the decomposition arithmetic straight into the
    // arbiter/LiteDRAM round trip with no register in between, which blew
    // timing at 80MHz (see PLAN.md 3.3 (build) hardware note). Computed once
    // from source_addr/source_data at capture time instead, replacing the
    // need to keep the raw mem_write_addr_t/mem_write_data_t around.
    types::sdram_word_addr_t sdram_addr_q;
    types::sdram_byte_en_t   sdram_wdata_we_q;
    types::sdram_word_data_t sdram_wdata_q;

    wire word_select_in = calc::sdram_pixel_word_select($bits(int)'(source_addr.pixel), params::SDRAM_WORD_BYTES);
    wire types::sdram_byte_in_word_t byte_in_word_in =
        types::sdram_byte_in_word_t'(calc::sdram_byte_in_word_select($bits(int)'(source_addr.pixel),
                                                                      params::SDRAM_WORD_BYTES));

    assign ready = state_q == STATE_IDLE;
    assign sdram_req = state_q == STATE_WRITE;
    assign sdram_addr = sdram_addr_q;
    assign sdram_wdata_we = sdram_wdata_we_q;
    assign sdram_wdata = sdram_wdata_q;

    always @(posedge clk_in) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            sdram_addr_q <= '0;
            sdram_wdata_we_q <= '0;
            sdram_wdata_q <= '0;
        end else begin
            case (state_q)
                STATE_IDLE: begin
                    if (source_write_valid) begin
                        state_q <= STATE_WRITE;
                        sdram_addr_q <= calc::sdram_word_addr(~frame_select, $bits(int)'(source_addr.row),
                                                               $bits(int)'(source_addr.col), source_addr.subpanel,
                                                               word_select_in, params::PIXEL_WIDTH,
                                                               params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                                                               params::SDRAM_WORD_BYTES);
                        sdram_wdata_we_q <= types::sdram_byte_en_t'(1 << byte_in_word_in);
                        sdram_wdata_q <= types::sdram_word_data_t'($bits(int)'(source_data) << (byte_in_word_in * 8));
                    end
                end
                STATE_WRITE: begin
                    if (sdram_done) begin
                        state_q <= STATE_IDLE;
                    end
                end
                default: state_q <= STATE_IDLE;
            endcase
        end
    end
endmodule
