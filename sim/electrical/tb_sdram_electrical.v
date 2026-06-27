// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ps
// =============================================================================
// tb_sdram_electrical -- off-chip timing experiment (Icarus). The FPGA drives the
// SDRAM bus a clock-to-out delay TCO after its clk_root edge; the chip samples on
// sdram_clk = clk_root + PHASE_NS (90deg = 5ns @ 50MHz). Setup achieved at the chip =
// PHASE_NS - TCO, vs tAS = 1.5ns. The HIGH (row-only) address bits addr[12:9] --
// driven ONLY by ACTIVATE -- can get an extra TCO_HI_EXTRA (longer route / only-
// toggled-on-activate), which is what would make ROW-MISS (drawColumn: 32 activates)
// fail while ROW-HIT (fillRect: no activate) stays clean.
// =============================================================================
`ifndef TCO
`define TCO 4.0
`endif
`ifndef PHASE_NS
`define PHASE_NS 5.0
`endif
`ifndef TCO_HI_EXTRA
`define TCO_HI_EXTRA 0.0
`endif

module tb_sdram_electrical;
    localparam real TCK = 20.0;

    reg clk_root = 1'b0;
    always #(TCK/2.0) clk_root = ~clk_root;
    wire #(`PHASE_NS) sdram_clk = clk_root;

    reg        cke = 1'b1, cs_n = 1'b1, ras_n = 1'b1, cas_n = 1'b1, we_n = 1'b1;
    reg [1:0]  ba = 0;
    reg [8:0]  addr_lo = 0;
    reg [12:9] addr_hi = 0;
    wire [12:0] addr = {addr_hi, addr_lo};
    reg [1:0]  dqm = 0;
    reg [15:0] dq_o = 0;  reg dq_drv = 1'b0;
    wire [15:0] dq = dq_drv ? dq_o : 16'hzzzz;

    localparam [3:0] CMD_ACT=4'b0011, CMD_READ=4'b0101, CMD_WRITE=4'b0100,
                     CMD_PRE=4'b0010, CMD_NOP=4'b0111;

    mt48lc16m16_timed dram (
        .clk(sdram_clk), .cke(cke), .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n),
        .we_n(we_n), .ba(ba), .addr(addr), .dqm(dqm), .dq(dq)
    );

    // issue a command at the next clk_root edge; bus changes TCO later (clock-to-out).
    // high row bits get +TCO_HI_EXTRA, and only matter on ACTIVATE.
    task automatic issue(input [3:0] c, input [1:0] bank, input [12:0] a,
                         input [15:0] d, input drive_dq);
        begin
            @(posedge clk_root);
            #(`TCO);
            {cs_n,ras_n,cas_n,we_n} = c; ba = bank; addr_lo = a[8:0];
            dq_drv = drive_dq; dq_o = d;
            if (`TCO_HI_EXTRA > 0.0) addr_hi = #(`TCO_HI_EXTRA) a[12:9];
            else                     addr_hi = a[12:9];
        end
    endtask
    task automatic nop; issue(CMD_NOP, 0, 0, 0, 0); endtask

    integer i, miss_lost, hit_lost;
    reg [15:0] rd;

    // clean readback (negligible TCO so only the WRITE path's timing is under test)
    task automatic read_clean(input [1:0] bank, input [12:0] row, input [8:0] col,
                              output [15:0] val);
        begin
            @(posedge clk_root) #0.1 {cs_n,ras_n,cas_n,we_n}=CMD_ACT; ba=bank; {addr_hi,addr_lo}=row;
            @(posedge clk_root) #0.1 {cs_n,ras_n,cas_n,we_n}=CMD_NOP;
            @(posedge clk_root) #0.1 {cs_n,ras_n,cas_n,we_n}=CMD_READ; ba=bank; addr_lo=col;
            #(`PHASE_NS + 5.4 + 1.0) val = dq;          // sample mid read-data window
            @(posedge clk_root) #0.1 {cs_n,ras_n,cas_n,we_n}=CMD_PRE; ba=bank;
            @(posedge clk_root) #0.1 {cs_n,ras_n,cas_n,we_n}=CMD_NOP;
        end
    endtask

    initial begin
        $dumpfile("/tmp/electrical.vcd"); $dumpvars(0, tb_sdram_electrical);
        repeat (20) nop;
        $display("=== TCO=%0.2f  PHASE=%0.2f  TCO_HI_EXTRA=%0.2f  tAS=1.5 ===",
                 `TCO, `PHASE_NS, `TCO_HI_EXTRA);

        // ROW-MISS: 32 writes, each a different row (drawColumn). col index = i&31.
        for (i = 0; i < 32; i = i + 1) begin
            issue(CMD_PRE,  0, 13'h0, 0, 0);  nop; nop;
            issue(CMD_ACT,  0, i*131, 0, 0);  nop; nop;
            issue(CMD_WRITE,0, i,     16'hA000 | i, 1); nop;   // col=i, data=A00i
        end
        miss_lost = 0;
        for (i = 0; i < 32; i = i + 1) begin
            read_clean(0, i*131, i, rd);
            if (rd !== (16'hA000 | i)) miss_lost = miss_lost + 1;
        end

        // ROW-HIT: 1 activate, then 32 writes to the SAME row (fillRect).
        issue(CMD_PRE, 1, 13'h0, 0, 0); nop; nop;
        issue(CMD_ACT, 1, 13'd100, 0, 0); nop; nop;
        for (i = 0; i < 32; i = i + 1) begin
            issue(CMD_WRITE, 1, i, 16'hB000 | i, 1); nop;
        end
        issue(CMD_PRE, 1, 13'h0, 0, 0); nop; nop;
        hit_lost = 0;
        for (i = 0; i < 32; i = i + 1) begin
            read_clean(1, 13'd100, i, rd);
            if (rd !== (16'hB000 | i)) hit_lost = hit_lost + 1;
        end

        $display("RESULT  row-miss writes lost = %0d / 32   row-hit writes lost = %0d / 32",
                 miss_lost, hit_lost);
        $display("        setup achieved: low/col bits = %0.2f ns,  high/row bits = %0.2f ns  (need >= 1.5)",
                 `PHASE_NS - `TCO, `PHASE_NS - `TCO - `TCO_HI_EXTRA);
        $finish;
    end
    initial begin #2000000 $display("TIMEOUT"); $finish; end
endmodule
