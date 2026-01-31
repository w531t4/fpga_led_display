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

    // control_module (out)
    logic                       [7:0] num_commands_processed;
    enums::control_module_fsm_e       cmd_line_state2;
    // end control_module
    `define DEBUGGER_DATA_FIELDS \
    rxdata_to_controller, \
    num_commands_processed, \
    rgb_enable, \
    cmd_line_state2, \
    brightness_enable

    localparam integer unsigned DEBUGGER_DATA_WIDTH = $bits({`DEBUGGER_DATA_FIELDS});
    logic [DEBUGGER_DATA_WIDTH-1:0] ddata;
    logic [$clog2(DEBUGGER_DATA_WIDTH)-1:0] current_position;

    always @(posedge clk) begin
        ddata <= {`DEBUGGER_DATA_FIELDS};
    end

    // control_module signals for debugging
    modport control_module(output num_commands_processed, output cmd_line_state2);

    // debugger
    modport debugger(output current_position, output ddata);

`ifdef SIM
    // Simulation-only sink so testbenches do not need to manually list every field in _unused_ok.
    // This keeps lint noise down without affecting synthesis builds.
    wire _unused_ok_sim = &{1'b0,
                            ddata,
                            rxdata_to_controller,
                            brightness_enable,
                            rgb_enable,
                            num_commands_processed,
                            cmd_line_state2,
                            current_position,
                            1'b0};
`endif
endinterface
