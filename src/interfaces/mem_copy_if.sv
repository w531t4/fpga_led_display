// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// mem_copy_if: Copyframe datapath interface between the copy engine (control_module)
// and the framebuffer memory fabric (main + multimem).
interface mem_copy_if;
    // Front-buffer data sampled from QA (copy source).
    types::mem_write_data_t read_data_in;
    // Read address into the front buffer (row/col/pixel).
    types::fb_addr_t read_addr;
    // Write address into the back buffer (row/col/pixel).
    types::fb_addr_t write_addr;
    // Data to write into the back buffer.
    types::mem_write_data_t write_data_out;
    // Write strobe for the back buffer.
    logic write_enable;
    // Toggle signal that is converted into ClockEnA (see main.sv).
    logic access_start;
    // Copyframe active flag from the control state machine.
    logic active;

    // Copy engine / control side.
    modport engine(
        input read_data_in,
        output read_addr,
        output write_addr,
        output write_data_out,
        output write_enable,
        output access_start,
        output active
    );

    // Framebuffer fabric / top-level side.
    modport fabric(
        output read_data_in,
        input read_addr,
        input write_addr,
        input write_data_out,
        input write_enable,
        input access_start,
        input active
    );
`ifdef SIM
    // Simulation-only sink so testbenches do not need to manually list every field in _unused_ok.
    // This keeps lint noise down without affecting synthesis builds.
    wire _unused_ok_sim = &{1'b0,
                            read_data_in,
                            read_addr,
                            write_addr,
                            write_data_out,
                            write_enable,
                            access_start,
                            active,
                            1'b0};
`endif
endinterface
