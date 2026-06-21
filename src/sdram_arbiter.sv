// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Generic fixed-priority req/grant mux for the single LiteDRAM native port.
// Client 0 is highest priority. One transaction in flight at a time; the
// arbiter re-arbitrates after every word, so it carries no knowledge of what
// any client is doing (row fills, writes, copies all look identical here).
module sdram_arbiter #(
    parameter int unsigned NUM_CLIENTS = 3
) (
    input logic clk,
    input logic reset,

    input  logic                    [NUM_CLIENTS-1:0] client_req,
    input  logic                    [NUM_CLIENTS-1:0] client_we,
    input  types::sdram_word_addr_t [NUM_CLIENTS-1:0] client_addr,
    input  types::sdram_byte_en_t   [NUM_CLIENTS-1:0] client_wdata_we,
    input  types::sdram_word_data_t [NUM_CLIENTS-1:0] client_wdata,
    output logic                    [NUM_CLIENTS-1:0] client_grant,
    output logic                    [NUM_CLIENTS-1:0] client_done,
    output types::sdram_word_data_t                   client_rdata,

    output logic                    cmd_valid,
    input  logic                    cmd_ready,
    output logic                    cmd_we,
    output types::sdram_word_addr_t cmd_addr,

    output logic                    wdata_valid,
    input  logic                    wdata_ready,
    output types::sdram_byte_en_t   wdata_we,
    output types::sdram_word_data_t wdata_data,

    input  logic                    rdata_valid,
    output logic                    rdata_ready,
    input  types::sdram_word_data_t rdata_data
);
    localparam int unsigned CLIENT_IDX_BITS = calc::safe_clog2(NUM_CLIENTS);

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_CMD,
        STATE_READ_WAIT
    } state_t;

    state_t state_q;
    logic [CLIENT_IDX_BITS-1:0] active_q;
    logic active_we_q;
    logic cmd_done_q;
    logic data_done_q;

    logic [CLIENT_IDX_BITS-1:0] winner;
    logic winner_valid;

    always_comb begin
        winner = '0;
        winner_valid = 1'b0;
        for (int i = NUM_CLIENTS - 1; i >= 0; i--) begin
            if (client_req[i]) begin
                winner = CLIENT_IDX_BITS'(i);
                winner_valid = 1'b1;
            end
        end
    end

    wire cmd_accepted = cmd_done_q || (!cmd_done_q && cmd_ready);
    wire data_accepted = data_done_q || (!data_done_q && wdata_ready);
    wire write_done = state_q == STATE_CMD && active_we_q && cmd_accepted && data_accepted;
    wire read_cmd_accepted = state_q == STATE_CMD && !active_we_q && cmd_accepted;
    wire read_done = state_q == STATE_READ_WAIT && rdata_valid;

    always_comb begin
        cmd_valid = state_q == STATE_CMD && !cmd_done_q;
        cmd_we = active_we_q;
        cmd_addr = client_addr[active_q];
        wdata_valid = state_q == STATE_CMD && active_we_q && !data_done_q;
        wdata_we = client_wdata_we[active_q];
        wdata_data = client_wdata[active_q];
        rdata_ready = 1'b1;
        client_rdata = rdata_data;

        client_grant = '0;
        if (state_q == STATE_CMD || state_q == STATE_READ_WAIT) client_grant[active_q] = 1'b1;

        client_done = '0;
        if (write_done || read_done) client_done[active_q] = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_IDLE;
            active_q <= '0;
            active_we_q <= 1'b0;
            cmd_done_q <= 1'b0;
            data_done_q <= 1'b0;
        end else begin
            case (state_q)
                STATE_IDLE: begin
                    if (winner_valid) begin
                        active_q <= winner;
                        active_we_q <= client_we[winner];
                        state_q <= STATE_CMD;
                    end
                end
                STATE_CMD: begin
                    if (!cmd_done_q && cmd_ready) cmd_done_q <= 1'b1;
                    if (active_we_q && !data_done_q && wdata_ready) data_done_q <= 1'b1;
                    if (write_done) begin
                        state_q <= STATE_IDLE;
                        cmd_done_q <= 1'b0;
                        data_done_q <= 1'b0;
                    end else if (read_cmd_accepted) begin
                        state_q <= STATE_READ_WAIT;
                        cmd_done_q <= 1'b0;
                    end
                end
                STATE_READ_WAIT: begin
                    if (read_done) state_q <= STATE_IDLE;
                end
                default: state_q <= STATE_IDLE;
            endcase
        end
    end
endmodule
