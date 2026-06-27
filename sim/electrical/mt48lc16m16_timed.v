// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
// =============================================================================
// mt48lc16m16_timed -- focused, datasheet-timed MT48LC16M16A2 model for OFF-CHIP
// timing simulation in Icarus (Verilator can't do real-delay timing). It MEASURES the
// actual setup time of the command/address/write-data relative to the SDRAM sampling
// clock ($realtime - last_change) and compares to tAS/tDS. On a setup violation the
// LATCH is corrupted to X -- so a marginal address at ACTIVATE opens a WRONG (X) row
// and the following write is lost / mislanded, exactly as a real chip would behave.
//
// The whole point: does the 90deg-forwarded clock + the FPGA's clock-to-out leave
// enough setup margin for the row-miss-heavy (rapid ACTIVATE) access drawColumn
// generates? -- a margin our on-chip STA never checks (it doesn't know the chip's
// setup/hold or the board). NOT a full Micron model; just the timing-critical path.
// Default timings ~ -7E grade.
// =============================================================================
module mt48lc16m16_timed #(
    parameter real tDS = 1.5,   // DQ input setup
    parameter real tAS = 1.5,   // ADDR/cmd input setup
    parameter real tAC = 5.4    // clk -> read DQ valid
) (
    input              clk,     // sdram_clk
    input              cke,
    input              cs_n, ras_n, cas_n, we_n,
    input       [1:0]  ba,
    input      [12:0]  addr,
    input       [1:0]  dqm,
    inout      [15:0]  dq
);
    localparam [3:0] CMD_ACT = 4'b0011, CMD_READ = 4'b0101, CMD_WRITE = 4'b0100,
                     CMD_PRE = 4'b0010, CMD_NOP  = 4'b0111;
    wire [3:0] cmd = {cs_n, ras_n, cas_n, we_n};

    reg  [15:0] mem [0:(1<<20)-1];     // {ba(2), row(13), col[4:0](5)} = 20-bit index
    integer     open_row [0:3];        // -1 closed, -2 corrupted, else row
    integer     b;

    reg  [15:0] dq_out; reg dq_drive;
    assign dq = dq_drive ? dq_out : 16'hzzzz;

    // ---- real-time setup measurement: when did cmd/addr/dq last change? ----
    real last_a_chg, last_d_chg;
    initial begin
        for (b = 0; b < 4; b = b + 1) open_row[b] = -1;
        dq_drive = 1'b0; dq_out = 16'h0;
        last_a_chg = -1000.0; last_d_chg = -1000.0;
    end
    always @(addr or ba or cs_n or ras_n or cas_n or we_n) last_a_chg = $realtime;
    always @(dq)                                           last_d_chg = $realtime;

    integer viol_setup_a, viol_setup_d;
    initial begin viol_setup_a = 0; viol_setup_d = 0; end

    always @(posedge clk) if (cke) begin : sample
        real su_a, su_d;
        reg  a_bad, d_bad;
        su_a = $realtime - last_a_chg;      // command/address setup actually achieved
        su_d = $realtime - last_d_chg;      // write-data setup actually achieved
        a_bad = (su_a < tAS);
        d_bad = (su_d < tDS);
        if (a_bad && cmd !== CMD_NOP) viol_setup_a = viol_setup_a + 1;
        case (cmd)
            CMD_ACT:  open_row[ba] = a_bad ? -2 : addr;             // marginal addr -> X row
            CMD_WRITE: if (open_row[ba] >= 0 && !a_bad && !d_bad) begin
                          if (!dqm[0]) mem[{ba, open_row[ba][12:0], addr[4:0]}][7:0]  = dq[7:0];
                          if (!dqm[1]) mem[{ba, open_row[ba][12:0], addr[4:0]}][15:8] = dq[15:8];
                       end else if (d_bad) viol_setup_d = viol_setup_d + 1;
                       // else write LOST: closed/corrupted row or marginal addr/data
            CMD_READ: begin
                          if (open_row[ba] >= 0 && !a_bad)
                              dq_out <= #(tAC) mem[{ba, open_row[ba][12:0], addr[4:0]}];
                          else
                              dq_out <= #(tAC) 16'hxxxx;
                          dq_drive <= #(tAC) 1'b1;
                          dq_drive <= #(tAC + 12.0) 1'b0;
                      end
            CMD_PRE:  open_row[ba] = -1;
            default: ;
        endcase
    end
endmodule
