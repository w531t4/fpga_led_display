// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Project-facing wrapper around the generated LiteDRAM core. This keeps LiteX's
// generated port names at the boundary and gives the rest of the design a stable
// native-port interface plus board-level SDRAM pins.
module ulx3s_litedram_wrapper (
    input  logic        clk,
    input  logic        reset,

    output logic        init_done,
    output logic        init_error,

    output logic        sdram_clk,
    output logic [12:0] sdram_a,
    output logic  [1:0] sdram_ba,
    output logic        sdram_casn,
    output logic        sdram_cke,
    output logic        sdram_csn,
    output logic  [1:0] sdram_dqm,
    // The generated LiteDRAM core instantiates TRELLIS_IO pads internally and
    // exposes DQ as an input pad net, so keep this boundary direction matched.
    input  wire  [15:0] sdram_d,
    output logic        sdram_rasn,
    output logic        sdram_wen,

    output logic        user_clk,
    output logic        user_rst,

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
    output logic [15:0] rdata_data
);
    logic [29:0] wb_ctrl_adr;
    logic  [1:0] wb_ctrl_bte;
    logic  [2:0] wb_ctrl_cti;
    logic        wb_ctrl_cyc;
    logic [31:0] wb_ctrl_dat_r;
    logic [31:0] wb_ctrl_dat_w;
    logic        wb_ctrl_ack;
    logic        wb_ctrl_err;
    logic  [3:0] wb_ctrl_sel;
    logic        wb_ctrl_stb;
    logic        wb_ctrl_we;
    logic        init_fsm_done;

    // SDRAM output clock. The SDR device samples command/address/write-data on
    // the RISING edge of sdram_clk; that edge must land in the MIDDLE of the
    // FPGA's data-valid window, not on the FPGA's own clock edge (where outputs
    // are transitioning). `sdram_clk = clk` (in phase) sampled right on the data
    // transitions -> corrupted, flickering reads on real hardware (sim's
    // idealized PHY has no clock phase, so it never showed this). Shift 180deg
    // (invert) so the device's rising edge falls at the FPGA's falling edge =
    // mid data eye -- the standard SDR phase relationship. Tune on hardware; a
    // dedicated ODDR + PLL phase output is the cleaner long-term form.
    // (Plain invert keeps the Verilator/sim build free of vendor primitives;
    // sdram_clk is unused there anyway.)
`ifdef SDRAM_CLK_INPHASE
    assign sdram_clk = clk;
`else
    assign sdram_clk = ~clk;  // 180 degrees
`endif

    litedram_init init (
        .clk(clk),
        .reset(reset),
        .wb_adr(wb_ctrl_adr),
        .wb_dat_w(wb_ctrl_dat_w),
        .wb_dat_r(wb_ctrl_dat_r),
        .wb_sel(wb_ctrl_sel),
        .wb_cyc(wb_ctrl_cyc),
        .wb_stb(wb_ctrl_stb),
        .wb_we(wb_ctrl_we),
        .wb_ack(wb_ctrl_ack),
        .wb_cti(wb_ctrl_cti),
        .wb_bte(wb_ctrl_bte),
        .done(init_fsm_done)
    );

`ifdef SIM
    // Simulation core generated with `litedram_gen --sim`: the real ECP5 PHY
    // (TRELLIS_IO/OFS1P3BX/... primitives Verilator can't model) is replaced by
    // a behavioral SDRAMPHYModel that lives inside the core, so there are no
    // sdram_* pads and no external reset (it self-resets via an internal POR).
    // The wb_ctrl bus and native port are identical to the real core, so
    // litedram_init drives bring-up the same way. This lets main (and every
    // testbench that reaches it) simulate the full SDRAM datapath in Verilator.
    ulx3s_litedram_sim core (
        .clk(clk),
        .init_done(init_done),
        .init_error(init_error),
        .sim_trace(1'b0),
        .user_clk(user_clk),
        .user_rst(user_rst),
        .user_port_native_0_cmd_addr(cmd_addr),
        .user_port_native_0_cmd_ready(cmd_ready),
        .user_port_native_0_cmd_valid(cmd_valid),
        .user_port_native_0_cmd_we(cmd_we),
        .user_port_native_0_wdata_data(wdata_data),
        .user_port_native_0_wdata_ready(wdata_ready),
        .user_port_native_0_wdata_valid(wdata_valid),
        .user_port_native_0_wdata_we(wdata_we),
        .user_port_native_0_rdata_data(rdata_data),
        .user_port_native_0_rdata_ready(rdata_ready),
        .user_port_native_0_rdata_valid(rdata_valid),
        .wb_ctrl_ack(wb_ctrl_ack),
        .wb_ctrl_adr(wb_ctrl_adr),
        .wb_ctrl_bte(wb_ctrl_bte),
        .wb_ctrl_cti(wb_ctrl_cti),
        .wb_ctrl_cyc(wb_ctrl_cyc),
        .wb_ctrl_dat_r(wb_ctrl_dat_r),
        .wb_ctrl_dat_w(wb_ctrl_dat_w),
        .wb_ctrl_err(wb_ctrl_err),
        .wb_ctrl_sel(wb_ctrl_sel),
        .wb_ctrl_stb(wb_ctrl_stb),
        .wb_ctrl_we(wb_ctrl_we)
    );
    // No SDRAM pads in the sim core: hold the board-level outputs in a benign
    // idle state and absorb the (unused) DQ input.
    assign sdram_a    = '0;
    assign sdram_ba   = '0;
    assign sdram_casn = 1'b1;
    assign sdram_cke  = 1'b0;
    assign sdram_csn  = 1'b1;
    assign sdram_dqm  = '0;
    assign sdram_rasn = 1'b1;
    assign sdram_wen  = 1'b1;
    wire _unused_ok_sim_pads = &{1'b0, sdram_d, 1'b0};
`else
    ulx3s_litedram core (
        .clk(clk),
        .rst(reset),
        .init_done(init_done),
        .init_error(init_error),
        .sdram_a(sdram_a),
        .sdram_ba(sdram_ba),
        .sdram_cas_n(sdram_casn),
        .sdram_cke(sdram_cke),
        .sdram_cs_n(sdram_csn),
        .sdram_dm(sdram_dqm),
        .sdram_dq(sdram_d),
        .sdram_ras_n(sdram_rasn),
        .sdram_we_n(sdram_wen),
        .user_clk(user_clk),
        .user_rst(user_rst),
        .user_port_native_0_cmd_addr(cmd_addr),
        .user_port_native_0_cmd_ready(cmd_ready),
        .user_port_native_0_cmd_valid(cmd_valid),
        .user_port_native_0_cmd_we(cmd_we),
        .user_port_native_0_wdata_data(wdata_data),
        .user_port_native_0_wdata_ready(wdata_ready),
        .user_port_native_0_wdata_valid(wdata_valid),
        .user_port_native_0_wdata_we(wdata_we),
        .user_port_native_0_rdata_data(rdata_data),
        .user_port_native_0_rdata_ready(rdata_ready),
        .user_port_native_0_rdata_valid(rdata_valid),
        .wb_ctrl_ack(wb_ctrl_ack),
        .wb_ctrl_adr(wb_ctrl_adr),
        .wb_ctrl_bte(wb_ctrl_bte),
        .wb_ctrl_cti(wb_ctrl_cti),
        .wb_ctrl_cyc(wb_ctrl_cyc),
        .wb_ctrl_dat_r(wb_ctrl_dat_r),
        .wb_ctrl_dat_w(wb_ctrl_dat_w),
        .wb_ctrl_err(wb_ctrl_err),
        .wb_ctrl_sel(wb_ctrl_sel),
        .wb_ctrl_stb(wb_ctrl_stb),
        .wb_ctrl_we(wb_ctrl_we)
    );
`endif

    wire _unused_ok_init_fsm_done = &{1'b0, init_fsm_done, 1'b0};
    wire _unused_ok_wb_ctrl_err = &{1'b0, wb_ctrl_err, 1'b0};
endmodule
