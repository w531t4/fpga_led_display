// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

interface debugger_if (
    input clk
);
    // main
    logic                       [7:0] rxdata_to_controller;  // from spi_slave/uart_rx
    types::brightness_level_t         brightness_enable;  // from control_module
    types::rgb_signals_t              rgb_enable;  // from control_module
    // end main

    // matrix_scan (out)
    types::edge_detect_t              row_latch_state2;
    logic                             row_latch2;
    logic                             state_advance2;
    logic                             clk_pixel_load_en2;
    // end matrix_scan

    // control_module (out)
    logic                       [7:0] num_commands_processed;
    enums::control_module_fsm_e       cmd_line_state2;
    logic                             ram_access_start2;
    logic                             ram_access_start_latch2;
    types::mem_write_addr_t           cmd_line_addr2;
    // end control_module

    // debugger
    logic                             debug_start;
    logic                             do_close;
    logic                             tx_start;
    logic                             command_pulse;
    logic                             command_busy;
    // end debugger
    `define DEBUGGER_DATA_FIELDS \
    rxdata_to_controller, \
    num_commands_processed, \
    rgb_enable, \
    cmd_line_state2, \
    brightness_enable, \
    ram_access_start2, \
    ram_access_start_latch2, \
    cmd_line_addr2, \
    row_latch_state2, \
    row_latch2, \
    state_advance2, \
    clk_pixel_load_en2, \
    debug_start, \
    do_close, \
    tx_start, \
    command_pulse, \
    command_busy

    localparam integer unsigned DEBUGGER_DATA_WIDTH = $bits({`DEBUGGER_DATA_FIELDS});
    logic [DEBUGGER_DATA_WIDTH-1:0] ddata;
    logic [$clog2(DEBUGGER_DATA_WIDTH)-1:0] current_position;

    always @(posedge clk) begin
        ddata <= {`DEBUGGER_DATA_FIELDS};
    end

    // control_module signals for debugging
    modport control_module(
        output num_commands_processed,
        output cmd_line_state2,
        output ram_access_start2,
        output ram_access_start_latch2,
        output cmd_line_addr2
    );

    // verilog_format: off
    modport matrix_scan(
        output row_latch_state2,
        output row_latch2,
        output state_advance2,
        output clk_pixel_load_en2
    );
    // verilog_format: on

    // debugger
    // verilog_format: off
    modport debugger(
        output current_position,
        output ddata,
        output debug_start,
        output do_close,
        output tx_start,
        output command_pulse,
        output command_busy
    );
    // verilog_format: on
`ifdef SIM
    // Simulation-only sink so testbenches do not need to manually list every field in _unused_ok.
    // This keeps lint noise down without affecting synthesis builds.
    // verilog_format: off
    wire _unused_ok_sim = &{1'b0,
                            ddata,
                            `DEBUGGER_DATA_FIELDS,
                            1'b0};
    // verilog_format: on
`endif
endinterface
