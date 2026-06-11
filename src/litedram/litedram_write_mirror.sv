// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Opportunistically mirrors controller framebuffer writes into LiteDRAM while
// the BRAM framebuffer remains the source of truth. This deliberately never
// backpressures the existing write path: missed writes are reported with a
// sticky dropped flag so bring-up can measure whether this simple client keeps up.
module litedram_write_mirror #(
    parameter int unsigned MAX_WAIT_TICKS = 1024
) (
    input logic clk,
    input logic reset,

    input logic init_done,
    input logic init_error,

    input types::mem_write_addr_t source_addr,
    input types::mem_write_data_t source_data,
    input logic                   source_write_valid,
    input logic                   source_frame,

    output logic busy,
    output logic seen_write,
    output logic dropped,
    output logic error,

    output logic        cmd_valid,
    input  logic        cmd_ready,
    output logic        cmd_we,
    output logic [23:0] cmd_addr,

    output logic        wdata_valid,
    input  logic        wdata_ready,
    output logic  [1:0] wdata_we,
    output logic [15:0] wdata_data,

    input  logic        rdata_valid,
    output logic        rdata_ready,
    input  logic [15:0] rdata_data
);
    localparam int unsigned WAIT_COUNT_BITS = $clog2(MAX_WAIT_TICKS + 1);
    localparam int unsigned MIRROR_ADDR_BITS = $bits(types::mem_write_addr_t) + 1;

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_WRITE,
        STATE_ERROR
    } state_t;

    state_t state_q;
    types::mem_write_addr_t addr_q;
    types::mem_write_data_t data_q;
    logic frame_q;
    logic cmd_done_q;
    logic data_done_q;
    logic [WAIT_COUNT_BITS-1:0] wait_count_q;

    wire cmd_accepted = cmd_done_q || (!cmd_done_q && cmd_ready);
    wire data_accepted = data_done_q || (!data_done_q && wdata_ready);
    wire wait_expired = wait_count_q == WAIT_COUNT_BITS'(MAX_WAIT_TICKS);

    function automatic logic [23:0] mirror_addr(input logic frame, input types::mem_write_addr_t addr);
        logic [MIRROR_ADDR_BITS-1:0] packed_addr;
        begin
            // One LiteDRAM word per framebuffer byte keeps the byte-lane mapping
            // simple and leaves the high byte unused for this first mirror path.
            packed_addr = {frame, addr};
            mirror_addr = 24'(packed_addr);
        end
    endfunction

    always_comb begin
        busy = state_q == STATE_WRITE;
        cmd_valid = state_q == STATE_WRITE && !cmd_done_q;
        cmd_we = 1'b1;
        cmd_addr = mirror_addr(frame_q, addr_q);
        wdata_valid = state_q == STATE_WRITE && !data_done_q;
        wdata_we = 2'b01;
        wdata_data = {8'h00, data_q};
        rdata_ready = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            addr_q <= '0;
            data_q <= '0;
            frame_q <= 1'b0;
            cmd_done_q <= 1'b0;
            data_done_q <= 1'b0;
            wait_count_q <= '0;
            seen_write <= 1'b0;
            dropped <= 1'b0;
            error <= 1'b0;
        end else begin
            if (init_error) begin
                error <= 1'b1;
                state_q <= STATE_ERROR;
            end

            case (state_q)
                STATE_IDLE: begin
                    wait_count_q <= '0;
                    cmd_done_q <= 1'b0;
                    data_done_q <= 1'b0;
                    if (source_write_valid) begin
                        if (init_done) begin
                            addr_q <= source_addr;
                            data_q <= source_data;
                            frame_q <= source_frame;
                            state_q <= STATE_WRITE;
                        end else begin
                            dropped <= 1'b1;
                        end
                    end
                end
                STATE_WRITE: begin
                    if (source_write_valid) begin
                        dropped <= 1'b1;
                    end
                    if (!cmd_done_q && cmd_ready) begin
                        cmd_done_q <= 1'b1;
                    end
                    if (!data_done_q && wdata_ready) begin
                        data_done_q <= 1'b1;
                    end
                    if (cmd_accepted && data_accepted) begin
                        seen_write <= 1'b1;
                        state_q <= STATE_IDLE;
                        wait_count_q <= '0;
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                    end else if (wait_expired) begin
                        error <= 1'b1;
                        state_q <= STATE_ERROR;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_ERROR: begin
                    if (source_write_valid) begin
                        dropped <= 1'b1;
                    end
                end
                default: begin
                    error <= 1'b1;
                    state_q <= STATE_ERROR;
                end
            endcase
        end
    end

    wire _unused_ok = &{1'b0, rdata_valid, rdata_data, 1'b0};
endmodule
