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

    // Backing-store fill port (drives framebuffer_fabric's RAM-B port).
    output types::mem_read_addr_t fill_address,
    output logic                  fill_clk_enable,
    input  types::mem_read_data_t fill_data_in
);
    // Matches the AddressB -> QB latency in mem_lane (sync read + outreg stage).
    localparam int unsigned READ_LATENCY = 2;
    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);

    typedef enum logic [1:0] {
        STATE_FILL,
        STATE_DRAIN,
        STATE_IDLE
    } fill_state_t;
    fill_state_t state_q;

    logic                      bank_sel_q;  // bank currently active for display reads
    types::row_subpanel_addr_t fill_row_q;
    types::col_addr_t          issue_col_q;
    types::col_addr_t          col_pipe[READ_LATENCY];
    logic                      valid_pipe[READ_LATENCY];
    logic                      fill_done_q;

    // Two row-deep banks; bank_sel_q selects which one is the active (display) bank.
    types::mem_read_data_t bank0[params::PIXEL_WIDTH];
    types::mem_read_data_t bank1[params::PIXEL_WIDTH];

    assign fill_address    = {fill_row_q, issue_col_q};
    assign fill_clk_enable = (state_q == STATE_FILL);

    wire trigger = row_latch && (brightness_mask == types::brightness_level_t'(1)) && fill_done_q;

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
            for (int i = 0; i < READ_LATENCY; i++) begin
                col_pipe[i] <= '0;
                valid_pipe[i] <= 1'b0;
            end
        end else begin
            for (int i = READ_LATENCY - 1; i > 0; i--) begin
                col_pipe[i] <= col_pipe[i-1];
                valid_pipe[i] <= valid_pipe[i-1];
            end

            if (trigger) begin
                bank_sel_q <= ~bank_sel_q;
                state_q <= STATE_FILL;
                fill_row_q <= row_address + types::row_subpanel_addr_t'(2);
                issue_col_q <= '0;
                fill_done_q <= 1'b0;
                col_pipe[0] <= '0;
                valid_pipe[0] <= 1'b0;
            end else begin
                case (state_q)
                    STATE_FILL: begin
                        col_pipe[0]   <= issue_col_q;
                        valid_pipe[0] <= 1'b1;
                        if (issue_col_q == LAST_COL) begin
                            state_q <= STATE_DRAIN;
                        end else begin
                            issue_col_q <= issue_col_q + 1'b1;
                        end
                    end
                    STATE_DRAIN: begin
                        col_pipe[0]   <= '0;
                        valid_pipe[0] <= 1'b0;
                        if (!valid_pipe[READ_LATENCY-1]) begin
                            state_q     <= STATE_IDLE;
                            fill_done_q <= 1'b1;
                        end
                    end
                    STATE_IDLE: begin
                        col_pipe[0]   <= '0;
                        valid_pipe[0] <= 1'b0;
                    end
                    default: state_q <= STATE_IDLE;
                endcase
            end

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
        end
    end

    // Display-side read: synchronous, mirrors multimem's QB shape. framebuffer_fetch
    // already applies its own sample-tick delay, so no extra pipeline stage is added.
    always @(posedge clk_in) begin
        if (reset) begin
            read_data_out <= '0;
        end else if (read_clk_enable) begin
            read_data_out <= bank_sel_q ? bank1[read_address.col] : bank0[read_address.col];
        end
    end

    wire _unused_ok = &{1'b0, read_address.row, 1'b0};
endmodule
