// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none (* blackbox *)
// Blackbox declaration for the ECP5 ODDRX1F DDR output register, so the slang
// synthesis frontend (and Verilator) can elaborate the design that instantiates
// it (used in ulx3s_litedram_wrapper to forward the phase-shifted SDRAM clock to
// the pad). synth_ecp5 maps the real primitive; under SIM it is never
// instantiated. Mirrors src/ehxplll_stub.sv.
// verilog_lint: waive-start module-filename
// verilog_lint: waive-start explicit-parameter-storage-type
// verilog_lint: waive-start paramater-not-used
// verilator lint_off DECLFILENAME
module ODDRX1F #(
    // verilator lint_off UNUSEDSIGNAL
    // verilator lint_off UNUSEDPARAM
    // verilator lint_off UNDRIVEN
    parameter GSR = "ENABLED"
) (
    input  D0,
    input  D1,
    input  SCLK,
    input  RST,
    output Q
    // verilator lint_on UNDRIVEN
    // verilator lint_on UNUSEDPARAM
    // verilator lint_on UNUSEDSIGNAL
);
endmodule
// verilator lint_on DECLFILENAME
// verilog_lint: waive-stop paramater-not-used
// verilog_lint: waive-stop explicit-parameter-storage-type
// verilog_lint: waive-stop module-filename
