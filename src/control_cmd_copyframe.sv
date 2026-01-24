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
    input types::mem_write_data_t data_in,
    // Dirty rectangle bounds (inclusive). When dirty_valid is low, copyframe is a no-op.
    input logic dirty_valid,
    input types::row_addr_t dirty_row_min,
    input types::row_addr_t dirty_row_max,
    input types::col_addr_t dirty_col_min,
    input types::col_addr_t dirty_col_max,

    output types::fb_addr_t read_addr,
    output types::fb_addr_t write_addr,
    output logic ram_write_enable,
    output logic ram_access_start,
    output types::mem_write_data_t data_out,
    output logic done
);
    // 1‑byte/clk copy pipeline:
    //  - issue a read every cycle (front buffer)
    //  - QA output is valid READ_LATENCY cycles later
    //  - write that data to the back buffer each cycle
    // Matches the AddressA -> QA latency in multimem (addr reg + BRAM + QA pipeline).
    localparam int unsigned READ_LATENCY = 5;

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_COPY,
        STATE_DONE
    } ctrl_fsm_t;
    ctrl_fsm_t state;

    types::fb_addr_t read_addr_q;
    types::fb_addr_t read_addr_pipe[READ_LATENCY];
    logic [READ_LATENCY-1:0] read_valid_pipe;
    types::fb_addr_t read_addr_pipe_next[READ_LATENCY];
    logic [READ_LATENCY-1:0] read_valid_pipe_next;
    // Track end-of-read so we stop issuing new reads after the last dirty pixel.
    logic read_done;
    // Assert done one cycle after the final write to match command semantics.
    logic last_write_pending;
    localparam types::pixel_addr_t LAST_PIXEL = types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);

    assign read_addr = read_addr_q;
    assign write_addr = read_addr_pipe[READ_LATENCY-1];
    wire last_read_addr = (read_addr_q.row == dirty_row_max)
                          && (read_addr_q.col == dirty_col_max)
                          && (read_addr_q.pixel == 'd0);

    always_comb begin
        for (int i = 0; i < READ_LATENCY; i++) begin
            read_addr_pipe_next[i] = read_addr_pipe[i];
            read_valid_pipe_next[i] = read_valid_pipe[i];
        end
        if (state == STATE_COPY) begin
            // Shift the address/valid pipelines (next-state) so the write strobe
            // lines up with the post-shift tail that feeds the write address.
            for (int i = READ_LATENCY - 1; i > 0; i--) begin
                read_addr_pipe_next[i] = read_addr_pipe[i - 1];
                read_valid_pipe_next[i] = read_valid_pipe[i - 1];
            end
            read_addr_pipe_next[0] = read_addr_q;
            read_valid_pipe_next[0] = read_done ? 1'b0 : 1'b1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            read_addr_q <= '0;
            for (int i = 0; i < READ_LATENCY; i++) begin
                read_addr_pipe[i] <= '0;
            end
            read_valid_pipe <= '0;
            read_done <= 1'b0;
            last_write_pending <= 1'b0;
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
                        // If nothing is dirty, complete immediately.
                        if (!dirty_valid) begin
                            done <= 1'b1;
                            state <= STATE_DONE;
                        end else begin
                            state <= STATE_COPY;
                            read_done <= 1'b0;
                            last_write_pending <= 1'b0;
                            // Seed the copy address at the rectangle origin.
                            read_addr_q.row <= dirty_row_min;
                            read_addr_q.col <= dirty_col_min;
                            read_addr_q.pixel <= LAST_PIXEL;
                        end
                        for (int i = 0; i < READ_LATENCY; i++) begin
                            read_addr_pipe[i] <= '0;
                        end
                        read_valid_pipe <= '0;
                        // Prime the access toggle so ClockEnA is high on the first copy cycle.
                        ram_access_start <= 1'b1;
                    end else begin
                        ram_access_start <= 1'b0;
                    end
                end
                STATE_COPY: begin
                    // Toggle every cycle to keep ClockEnA asserted.
                    ram_access_start <= ~ram_access_start;

                    // Issue a new read until the last dirty address is issued.
                    if (!read_done) begin
                        if (last_read_addr) begin
                            read_done <= 1'b1;
                        end
                        // Advance address for the next cycle (pixel counts down).
                        if (read_addr_q.pixel == 'd0) begin
                            read_addr_q.pixel <= LAST_PIXEL;
                            if (read_addr_q.col == dirty_col_max) begin
                                read_addr_q.col <= dirty_col_min;
                                read_addr_q.row <= read_addr_q.row + 'd1;
                            end else begin
                                read_addr_q.col <= read_addr_q.col + 'd1;
                            end
                        end else begin
                            read_addr_q.pixel <= read_addr_q.pixel - 'd1;
                        end
                    end
                    read_addr_pipe <= read_addr_pipe_next;
                    read_valid_pipe <= read_valid_pipe_next;

                    // Emit a write when the read data is aligned to the post-shift pipeline tail.
                    if (last_write_pending) begin
                        done <= 1'b1;
                        state <= STATE_DONE;
                        last_write_pending <= 1'b0;
                    end else if (read_valid_pipe_next[READ_LATENCY - 1]) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        if ((read_addr_pipe_next[READ_LATENCY - 1].row == dirty_row_max)
                            && (read_addr_pipe_next[READ_LATENCY - 1].col == dirty_col_max)
                            && (read_addr_pipe_next[READ_LATENCY - 1].pixel == 'd0)) begin
                            last_write_pending <= 1'b1;
                        end
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
endmodule
