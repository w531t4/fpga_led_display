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

    // GENSDRPHY does not expose a separate clock pad. Forward the same clock to
    // the SDRAM device; later timing work can replace this with a dedicated ODDR.
    assign sdram_clk = clk;

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

    wire _unused_ok_init_fsm_done = &{1'b0, init_fsm_done, 1'b0};
    wire _unused_ok_wb_ctrl_err = &{1'b0, wb_ctrl_err, 1'b0};
endmodule
