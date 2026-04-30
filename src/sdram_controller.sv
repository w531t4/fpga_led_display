// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module sdram_controller (
    input  logic clk_in,
    input  logic reset,

    input  logic host_req_valid,
    output logic host_req_ready,
    input  logic host_req_write,
    input  logic [params::SDRAM_BANK_BITS-1:0] host_req_bank,
    input  logic [params::SDRAM_ROW_BITS-1:0] host_req_row,
    input  logic [params::SDRAM_COLUMN_BITS-1:0] host_req_col,
    input  logic [(params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH)-1:0] host_req_write_data,
    output logic host_resp_valid,
    output logic [(params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH)-1:0] host_resp_read_data,

    output logic init_done,
    output logic refresh_active,
    output logic controller_busy,

    output logic sdram_clk,
    output logic sdram_cke,
    output logic sdram_csn,
    output logic sdram_rasn,
    output logic sdram_casn,
    output logic sdram_wen,
    output logic [params::SDRAM_ADDR_BITS-1:0] sdram_a,
    output logic [params::SDRAM_BANK_BITS-1:0] sdram_ba,
    output logic [params::SDRAM_DQM_BITS-1:0] sdram_dqm,
    output logic [params::SDRAM_DATA_BITS-1:0] sdram_dq_out,
    output logic sdram_dq_oe,
    input  logic [params::SDRAM_DATA_BITS-1:0] sdram_dq_in
);
    typedef enum logic [1:0] {
        REFRESH_IDLE,
        REFRESH_ISSUE,
        REFRESH_WAIT
    } refresh_state_e;

    logic init_busy;
    logic init_cmd_valid;
    enums::sdram_cmd_e init_cmd_code;
    logic [params::SDRAM_ADDR_BITS-1:0] init_cmd_addr;

    logic refresh_pending;
    logic refresh_ack;
    refresh_state_e refresh_state;
    logic [calc::safe_clog2(params::SDRAM_TRFC_CYCLES + 1)-1:0] refresh_wait_count;

    logic burst_start;
    logic burst_busy;
    logic burst_done;
    logic [(params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH)-1:0] burst_read_data;
    logic burst_cmd_valid;
    enums::sdram_cmd_e burst_cmd_code;
    logic [params::SDRAM_ADDR_BITS-1:0] burst_cmd_addr;
    logic [params::SDRAM_BANK_BITS-1:0] burst_cmd_bank;
    logic [params::SDRAM_DATA_BITS-1:0] burst_dq_out;
    logic burst_dq_oe;

    sdram_init init_fsm (
        .clk_in(clk_in),
        .reset(reset),
        .done(init_done),
        .busy(init_busy),
        .cmd_valid(init_cmd_valid),
        .cmd_code(init_cmd_code),
        .cmd_addr(init_cmd_addr)
    );

    sdram_refresh refresh_sched (
        .clk_in(clk_in),
        .reset(reset),
        .init_done(init_done),
        .refresh_ack(refresh_ack),
        .refresh_pending(refresh_pending)
    );

    sdram_burst burst_engine (
        .clk_in(clk_in),
        .reset(reset),
        .start(burst_start),
        .req_write(host_req_write),
        .req_bank(host_req_bank),
        .req_row(host_req_row),
        .req_col(host_req_col),
        .req_write_data(host_req_write_data),
        .dq_in(sdram_dq_in),
        .busy(burst_busy),
        .done(burst_done),
        .read_data(burst_read_data),
        .cmd_valid(burst_cmd_valid),
        .cmd_code(burst_cmd_code),
        .cmd_addr(burst_cmd_addr),
        .cmd_bank(burst_cmd_bank),
        .dq_out(burst_dq_out),
        .dq_oe(burst_dq_oe)
    );

    always_ff @(posedge clk_in) begin
        if (reset) begin
            refresh_state <= REFRESH_IDLE;
            refresh_wait_count <= '0;
            host_resp_valid <= 1'b0;
        end else begin
            host_resp_valid <= burst_done & ~host_req_write;

            case (refresh_state)
                REFRESH_IDLE: begin
                    if (init_done && refresh_pending && !burst_busy) begin
                        refresh_state <= REFRESH_ISSUE;
                    end
                end
                REFRESH_ISSUE: begin
                    refresh_state <= REFRESH_WAIT;
                    refresh_wait_count <= '0;
                end
                REFRESH_WAIT: begin
                    if (refresh_wait_count == $bits(refresh_wait_count)'(params::SDRAM_TRFC_CYCLES - 1)) begin
                        refresh_state <= REFRESH_IDLE;
                    end else begin
                        refresh_wait_count <= refresh_wait_count + 'd1;
                    end
                end
                default: begin
                    refresh_state <= REFRESH_IDLE;
                end
            endcase
        end
    end

    assign host_resp_read_data = burst_read_data;
    assign refresh_ack = (refresh_state == REFRESH_ISSUE);
    assign refresh_active = (refresh_state != REFRESH_IDLE);
    assign host_req_ready = init_done && !burst_busy && (refresh_state == REFRESH_IDLE) && !refresh_pending;
    assign burst_start = host_req_valid && host_req_ready;
    assign controller_busy = init_busy || burst_busy || refresh_active;
    wire _unused_ok = &{1'b0, init_cmd_valid, burst_cmd_valid, 1'b0};

    assign sdram_clk = clk_in;
    assign sdram_cke = ~reset;
    assign sdram_dqm = '0;

    always_comb begin
        sdram_csn = 1'b0;
        sdram_rasn = 1'b1;
        sdram_casn = 1'b1;
        sdram_wen = 1'b1;
        sdram_a = '0;
        sdram_ba = '0;
        sdram_dq_out = '0;
        sdram_dq_oe = 1'b0;

        if (!init_done) begin
            unique case (init_cmd_code)
                enums::SDRAM_CMD_PRECHARGE: begin
                    sdram_rasn = 1'b0;
                    sdram_casn = 1'b1;
                    sdram_wen = 1'b0;
                    sdram_a = init_cmd_addr;
                end
                enums::SDRAM_CMD_AUTO_REFRESH: begin
                    sdram_rasn = 1'b0;
                    sdram_casn = 1'b0;
                    sdram_wen = 1'b1;
                end
                enums::SDRAM_CMD_LOAD_MODE: begin
                    sdram_rasn = 1'b0;
                    sdram_casn = 1'b0;
                    sdram_wen = 1'b0;
                    sdram_a = init_cmd_addr;
                end
                default: begin
                end
            endcase
        end else if (refresh_state == REFRESH_ISSUE) begin
            sdram_rasn = 1'b0;
            sdram_casn = 1'b0;
            sdram_wen = 1'b1;
        end else begin
            unique case (burst_cmd_code)
                enums::SDRAM_CMD_ACTIVE: begin
                    sdram_rasn = 1'b0;
                    sdram_casn = 1'b1;
                    sdram_wen = 1'b1;
                    sdram_a = burst_cmd_addr;
                    sdram_ba = burst_cmd_bank;
                end
                enums::SDRAM_CMD_READ: begin
                    sdram_rasn = 1'b1;
                    sdram_casn = 1'b0;
                    sdram_wen = 1'b1;
                    sdram_a = burst_cmd_addr;
                    sdram_ba = burst_cmd_bank;
                end
                enums::SDRAM_CMD_WRITE: begin
                    sdram_rasn = 1'b1;
                    sdram_casn = 1'b0;
                    sdram_wen = 1'b0;
                    sdram_a = burst_cmd_addr;
                    sdram_ba = burst_cmd_bank;
                    sdram_dq_out = burst_dq_out;
                    sdram_dq_oe = burst_dq_oe;
                end
                default: begin
                    sdram_dq_out = burst_dq_out;
                    sdram_dq_oe = burst_dq_oe;
                end
            endcase
        end
    end
endmodule
