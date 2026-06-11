// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Minimal native-port probe for the LiteDRAM core. It intentionally performs a
// single write/read/compare transaction so hardware bring-up can prove the
// controller is initialized and accepting user traffic before framebuffer
// plumbing depends on it.
module litedram_bist #(
    parameter logic [23:0] TEST_ADDR = 24'h000000,
    parameter logic [15:0] TEST_DATA = 16'h5a3c,
    parameter int unsigned MAX_WAIT_TICKS = 1024
) (
    input logic clk,
    input logic reset,

    input logic init_done,
    input logic init_error,

    output logic busy,
    output logic done,
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

    typedef enum logic [2:0] {
        STATE_WAIT_INIT,
        STATE_WRITE,
        STATE_READ_CMD,
        STATE_READ_DATA,
        STATE_DONE,
        STATE_ERROR
    } state_t;

    state_t state_q;
    logic write_cmd_done_q;
    logic write_data_done_q;
    logic [WAIT_COUNT_BITS-1:0] wait_count_q;

    wire write_cmd_accepted = write_cmd_done_q || (!write_cmd_done_q && cmd_ready);
    wire write_data_accepted = write_data_done_q || (!write_data_done_q && wdata_ready);
    wire wait_expired = wait_count_q == WAIT_COUNT_BITS'(MAX_WAIT_TICKS);

    always_comb begin
        busy = state_q != STATE_DONE && state_q != STATE_ERROR;
        done = state_q == STATE_DONE || state_q == STATE_ERROR;
        error = state_q == STATE_ERROR;

        cmd_valid = 1'b0;
        cmd_we = 1'b0;
        cmd_addr = TEST_ADDR;
        wdata_valid = 1'b0;
        wdata_we = 2'b11;
        wdata_data = TEST_DATA;
        rdata_ready = 1'b0;

        case (state_q)
            STATE_WRITE: begin
                cmd_valid = !write_cmd_done_q;
                cmd_we = 1'b1;
                wdata_valid = !write_data_done_q;
            end
            STATE_READ_CMD: begin
                cmd_valid = 1'b1;
            end
            STATE_READ_DATA: begin
                rdata_ready = 1'b1;
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_WAIT_INIT;
            write_cmd_done_q <= 1'b0;
            write_data_done_q <= 1'b0;
            wait_count_q <= '0;
        end else begin
            case (state_q)
                STATE_WAIT_INIT: begin
                    wait_count_q <= '0;
                    write_cmd_done_q <= 1'b0;
                    write_data_done_q <= 1'b0;
                    if (init_error) begin
                        state_q <= STATE_ERROR;
                    end else if (init_done) begin
                        state_q <= STATE_WRITE;
                    end
                end
                STATE_WRITE: begin
                    if (!write_cmd_done_q && cmd_ready) begin
                        write_cmd_done_q <= 1'b1;
                    end
                    if (!write_data_done_q && wdata_ready) begin
                        write_data_done_q <= 1'b1;
                    end
                    if (write_cmd_accepted && write_data_accepted) begin
                        state_q <= STATE_READ_CMD;
                        write_cmd_done_q <= 1'b0;
                        write_data_done_q <= 1'b0;
                        wait_count_q <= '0;
                    end else if (wait_expired) begin
                        state_q <= STATE_ERROR;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_READ_CMD: begin
                    if (cmd_ready) begin
                        state_q <= STATE_READ_DATA;
                        wait_count_q <= '0;
                    end else if (wait_expired) begin
                        state_q <= STATE_ERROR;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_READ_DATA: begin
                    if (rdata_valid) begin
                        state_q <= (rdata_data == TEST_DATA) ? STATE_DONE : STATE_ERROR;
                        wait_count_q <= '0;
                    end else if (wait_expired) begin
                        state_q <= STATE_ERROR;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_DONE, STATE_ERROR: begin
                    wait_count_q <= '0;
                end
                default: begin
                    state_q <= STATE_ERROR;
                end
            endcase
        end
    end
endmodule
