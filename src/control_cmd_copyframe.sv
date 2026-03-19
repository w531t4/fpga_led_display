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
    localparam int unsigned TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Matches the AddressA -> QA latency in multimem (addr reg + BRAM + QA pipeline).
    localparam int unsigned READ_LATENCY = params::MULTIMEM_QA_LATENCY + 1; // +1 because of registered read in this module

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

    assign read_addr  = read_addr_q;
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
            ram_access_start <= 1'b0;
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
                        // Kick the RAM pipeline immediately on copy start.
                        ram_access_start <= 1'b1;
                    end
                end
                STATE_COPY: begin
                    ram_access_start <= 1'b1;

                    // Shift the address/valid pipelines.
                    for (int i = READ_LATENCY - 1; i > 0; i--) begin
                        read_addr_pipe[i]  <= read_addr_pipe[i-1];
                        read_valid_pipe[i] <= read_valid_pipe[i-1];
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
                        read_addr_pipe[0]  <= read_addr_q;
                        read_valid_pipe[0] <= 1'b0;
                    end

                    // Emit a write when the read data is aligned to the pipeline tail.
                    if (read_valid_pipe[READ_LATENCY-1]) begin
                        ram_write_enable <= 1'b1;
                        data_out <= data_in;
                        if (write_count == TOTAL_BYTES_LAST) begin
                            done  <= 1'b1;
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
endmodule
