// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
`ifdef SIM
// =============================================================================
// sdram_native_timing_model -- SIM-ONLY behavioral SDRAM on the LiteDRAM native
// port that is BOTH functional (stores/returns data) AND timing-real: per-bank
// open-row tracking, row-hit vs row-miss command cost, CAS read latency, and
// periodic refresh -- i.e. it WITHHOLDS cmd_ready/wdata_ready/rdata_valid exactly
// like a real MT48LC16M16 + controller would.
//
// WHY: the generated `--sim` core (SDRAMPHYModel) is OPTIMISTIC at the native port
// -- it grants cmd_ready essentially for free, so it never produces the precharge/
// activate/refresh backpressure that a row-miss-heavy access pattern (drawColumn:
// 32 px down 32 rows = a row-miss every write) actually generates. If our RTL
// (write_client/arbiter/row_prefetch) mishandles that backpressure, the flat core
// can never show it. This model produces that backpressure, so the full design can
// be run under realistic timing. Drop-in for ulx3s_litedram_sim behind
// -DSDRAM_SIM_TIMING_MODEL. Timing model copied from tb_sdram_contention's slave.
//
// LIMIT: this is cycle/protocol-faithful, NOT electrically faithful. It returns
// correct data whenever the protocol is honored, so it CANNOT reproduce analog
// corruption (clock-phase / setup-hold margin). If a fault reproduces here it is a
// LOGIC bug under real timing (fixable in sim); if it stays clean here, that is
// evidence the fault is electrical (needs hardware), earned rather than guessed.
// =============================================================================
module sdram_native_timing_model #(
    parameter int unsigned CAS_LAT       = 3,
    parameter int unsigned ROW_HIT_COST  = 1,
    parameter int unsigned ROW_MISS_COST = 9,
    parameter int unsigned REFRESH_EVERY = 600,
    parameter int unsigned REFRESH_COST  = 20
) (
    input  logic        clk,
    input  logic        reset,
    output logic        init_done,
    output logic        init_error,
    output logic        user_clk,
    output logic        user_rst,
    // native port (slave)
    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  logic        cmd_we,
    input  logic [23:0] cmd_addr,
    input  logic        wdata_valid,
    output logic        wdata_ready,
    input  logic  [1:0] wdata_we,
    input  logic [15:0] wdata_data,
    output logic        rdata_valid,
    input  logic        rdata_ready,
    output logic [15:0] rdata_data,
    // wb_ctrl bring-up: litedram_init only WRITES config -> just ack it
    input  logic [29:0] wb_ctrl_adr,
    input  logic  [1:0] wb_ctrl_bte,
    input  logic  [2:0] wb_ctrl_cti,
    input  logic        wb_ctrl_cyc,
    output logic [31:0] wb_ctrl_dat_r,
    input  logic [31:0] wb_ctrl_dat_w,
    output logic        wb_ctrl_ack,
    output logic        wb_ctrl_err,
    input  logic  [3:0] wb_ctrl_sel,
    input  logic        wb_ctrl_stb,
    input  logic        wb_ctrl_we
);
    assign user_clk   = clk;
    assign user_rst   = reset;
    assign init_error = 1'b0;

    // --- bring-up plumbing: ack every wb write; init_done after a short settle ---
    assign wb_ctrl_dat_r = '0;
    assign wb_ctrl_err   = 1'b0;
    logic wb_ack_q;
    always_ff @(posedge clk) begin
        if (reset) wb_ack_q <= 1'b0;
        else       wb_ack_q <= wb_ctrl_cyc && wb_ctrl_stb && !wb_ack_q;
    end
    assign wb_ctrl_ack = wb_ack_q;

    logic [9:0] init_cnt_q;
    always_ff @(posedge clk) begin
        if (reset) init_cnt_q <= '0;
        else if (!init_done) init_cnt_q <= init_cnt_q + 1'b1;
    end
    assign init_done = init_cnt_q[9];   // ~512 cycles after reset

    // --- timing-real functional native-port slave (from tb_sdram_contention) ---
    function automatic int unsigned bank_of(input logic [23:0] a); bank_of = a[10:9]; endfunction
    function automatic int unsigned row_of (input logic [23:0] a); row_of  = a[23:11]; endfunction
    function automatic logic [15:0] def_data(input logic [23:0] a); def_data = a[15:0] ^ 16'h5a3c; endfunction

    logic [15:0] mem [logic [23:0]];
    int  open_row [4];
    int  busy_q, refresh_cnt, refresh_busy;
    int          rq_due  [$];
    logic [15:0] rq_data [$];
    longint      now_q;
    integer fi;

    wire ctrl_free = (busy_q == 0) && (refresh_busy == 0) && init_done;
    always_comb begin cmd_ready = ctrl_free; wdata_ready = ctrl_free; end

    always_ff @(posedge clk) begin
        if (reset) begin
            busy_q <= 0; refresh_cnt <= 0; refresh_busy <= 0; now_q <= 0;
            rdata_valid <= 1'b0; rdata_data <= '0;
            for (fi = 0; fi < 4; fi++) open_row[fi] <= -1;
            rq_due.delete(); rq_data.delete();
        end else begin
            now_q <= now_q + 1;
            rdata_valid <= 1'b0;
            if (refresh_busy > 0) refresh_busy <= refresh_busy - 1;
            else if (refresh_cnt >= REFRESH_EVERY) begin
                refresh_cnt <= 0; refresh_busy <= REFRESH_COST;
                for (fi = 0; fi < 4; fi++) open_row[fi] <= -1;
            end else refresh_cnt <= refresh_cnt + 1;

            if (busy_q > 0) busy_q <= busy_q - 1;

            if (cmd_valid && cmd_ready) begin
                automatic int unsigned bk = bank_of(cmd_addr);
                automatic logic hit = (open_row[bk] == int'(row_of(cmd_addr)));
                busy_q <= (hit ? ROW_HIT_COST : ROW_MISS_COST) - 1;
                open_row[bk] <= int'(row_of(cmd_addr));
                if (cmd_we) begin
                    if (wdata_valid && wdata_ready) begin
                        automatic logic [15:0] cur = mem.exists(cmd_addr) ? mem[cmd_addr] : def_data(cmd_addr);
                        if (wdata_we[0]) cur[7:0]  = wdata_data[7:0];
                        if (wdata_we[1]) cur[15:8] = wdata_data[15:8];
                        mem[cmd_addr] = cur;
                    end
                end else begin
                    rq_due.push_back(int'(now_q) + CAS_LAT);
                    rq_data.push_back(mem.exists(cmd_addr) ? mem[cmd_addr] : def_data(cmd_addr));
                end
            end

            if (rq_due.size() > 0 && rq_due[0] <= int'(now_q)) begin
                rdata_valid <= 1'b1;
                rdata_data  <= rq_data[0];
                void'(rq_due.pop_front());
                void'(rq_data.pop_front());
            end
        end
    end

    wire _unused_ok = &{1'b0, wb_ctrl_adr, wb_ctrl_bte, wb_ctrl_cti, wb_ctrl_dat_w,
                        wb_ctrl_sel, wb_ctrl_we, rdata_ready, 1'b0};
endmodule
`endif
`default_nettype wire
