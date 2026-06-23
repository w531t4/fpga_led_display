// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// SUSTAINED native-port write/read/compare loop for the LiteDRAM core. It walks a
// range of addresses, writing distinct, heavily-toggling data to each and reading it
// straight back. Looping continuously over many addresses/patterns is what catches
// the INTERMITTENT, write-margin PHY errors a single transaction can miss by luck
// (static framebuffer data reads back fine; only frequently-rewritten regions show
// it). `error` is STICKY: it stays OFF only while every write AND read across the
// whole sweep is clean -> the reliable pass/fail for tuning the SDRAM clock phase on
// hardware. `done` = first full pass completed; the loop keeps running after.
module litedram_bist #(
    parameter logic [23:0] TEST_ADDR = 24'h000000,  // base of the swept address range
    parameter logic [15:0] TEST_DATA = 16'h5a3c,     // data = (addr ^ TEST_DATA), distinct per address
    // Sweep the WHOLE framebuffer address range (both double-buffer copies ~= 0x18000
    // words), not just the first 8192 -- otherwise the high addresses that back the
    // bottom display rows are never exercised. Overridable for quick runs.
`ifdef LITEDRAM_BIST_ADDR_SPAN
    parameter logic [23:0] ADDR_SPAN = `LITEDRAM_BIST_ADDR_SPAN,
`else
    parameter logic [23:0] ADDR_SPAN = 24'h01A000,
`endif
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

    typedef enum logic [1:0] {
        STATE_WAIT_INIT,
        STATE_WRITE,
        STATE_READ_CMD,
        STATE_READ_DATA
    } state_t;

    state_t state_q;
    logic [23:0] addr_q;          // current test address
    logic write_cmd_done_q;
    logic write_data_done_q;
    logic [WAIT_COUNT_BITS-1:0] wait_count_q;
    logic error_q;                // STICKY: any mismatch / timeout / init error
    logic done_q;                 // at least one full address pass completed

    wire [15:0] test_data = addr_q[15:0] ^ TEST_DATA;     // distinct per address
    wire addr_last = (addr_q == (TEST_ADDR + ADDR_SPAN - 24'd1));
    wire write_cmd_accepted  = write_cmd_done_q  || cmd_ready;
    wire write_data_accepted = write_data_done_q || wdata_ready;
    wire wait_expired = (wait_count_q == WAIT_COUNT_BITS'(MAX_WAIT_TICKS));

    always_comb begin
        busy  = !done_q;          // high until the first full pass; then it keeps looping with done held
        done  = done_q;
        error = error_q;

        cmd_valid   = 1'b0;
        cmd_we      = 1'b0;
        cmd_addr    = addr_q;
        wdata_valid = 1'b0;
        wdata_we    = 2'b11;
        wdata_data  = test_data;
        rdata_ready = 1'b0;

        case (state_q)
            STATE_WRITE: begin
                cmd_valid   = !write_cmd_done_q;
                cmd_we      = 1'b1;
                wdata_valid = !write_data_done_q;
            end
            STATE_READ_CMD: cmd_valid = 1'b1;
            STATE_READ_DATA: rdata_ready = 1'b1;
            default: begin
            end
        endcase
    end

    // Advance to the next swept address (wrap -> mark a completed pass).
    task automatic next_addr;
        if (addr_last) begin
            addr_q <= TEST_ADDR;
            done_q <= 1'b1;
        end else begin
            addr_q <= addr_q + 24'd1;
        end
    endtask

    always_ff @(posedge clk) begin
        if (reset) begin
            state_q <= STATE_WAIT_INIT;
            addr_q <= TEST_ADDR;
            write_cmd_done_q <= 1'b0;
            write_data_done_q <= 1'b0;
            wait_count_q <= '0;
            error_q <= 1'b0;
            done_q <= 1'b0;
        end else begin
            case (state_q)
                STATE_WAIT_INIT: begin
                    wait_count_q <= '0;
                    write_cmd_done_q <= 1'b0;
                    write_data_done_q <= 1'b0;
                    if (init_error) error_q <= 1'b1;
                    else if (init_done) state_q <= STATE_WRITE;
                end
                STATE_WRITE: begin
                    if (!write_cmd_done_q && cmd_ready) write_cmd_done_q <= 1'b1;
                    if (!write_data_done_q && wdata_ready) write_data_done_q <= 1'b1;
                    if (write_cmd_accepted && write_data_accepted) begin
                        state_q <= STATE_READ_CMD;
                        write_cmd_done_q <= 1'b0;
                        write_data_done_q <= 1'b0;
                        wait_count_q <= '0;
                    end else if (wait_expired) begin
                        error_q <= 1'b1;          // write didn't get accepted -> error, but keep looping
                        state_q <= STATE_READ_CMD;
                        write_cmd_done_q <= 1'b0;
                        write_data_done_q <= 1'b0;
                        wait_count_q <= '0;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_READ_CMD: begin
                    if (cmd_ready) begin
                        state_q <= STATE_READ_DATA;
                        wait_count_q <= '0;
                    end else if (wait_expired) begin
                        error_q <= 1'b1;
                        state_q <= STATE_READ_DATA;
                        wait_count_q <= '0;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                STATE_READ_DATA: begin
                    if (rdata_valid || wait_expired) begin
                        // mismatch OR read timeout -> sticky error; either way advance.
                        if (!rdata_valid || (rdata_data != test_data)) error_q <= 1'b1;
                        next_addr;
                        state_q <= STATE_WRITE;
                        wait_count_q <= '0;
                    end else begin
                        wait_count_q <= wait_count_q + 1'b1;
                    end
                end
                default: state_q <= STATE_WAIT_INIT;
            endcase
        end
    end
endmodule
