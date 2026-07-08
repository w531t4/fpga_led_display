// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// Handles remapping of RGB channels
module hub75_rgb_pack (
    input  types::rgb_signals_t rgb_in,
    output types::rgb_signals_t rgb_out
);
`ifdef SWAP_BLUE_GREEN_CHAN
    assign rgb_out = {rgb_in.red, rgb_in.blue, rgb_in.green};
`else
    assign rgb_out = rgb_in;
`endif
endmodule
