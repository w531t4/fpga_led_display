// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package params_pkg;
`ifdef CLK_110
    parameter int unsigned ROOT_CLOCK = 110_000_000;
`elsif CLK_100
    parameter int unsigned ROOT_CLOCK = 100_000_000;
`elsif CLK_90
    parameter int unsigned ROOT_CLOCK = 90_000_000;
`elsif CLK_50
    parameter int unsigned ROOT_CLOCK = 50_000_000;
`else
    parameter int unsigned ROOT_CLOCK = 16_000_000;
`endif
`ifdef RGB24
    parameter int unsigned BYTES_PER_PIXEL = 3;
    parameter int unsigned BRIGHTNESS_LEVELS = 8;
`else
    parameter int unsigned BYTES_PER_PIXEL = 2;
    parameter int unsigned BRIGHTNESS_LEVELS = 6;
`endif
`ifdef W128
`ifdef SIM
    parameter int unsigned PIXEL_WIDTH = 64 * 6;
`else
    parameter int unsigned PIXEL_WIDTH = 64 * 12;
`endif
`else
    parameter int unsigned PIXEL_WIDTH = 64;
`endif
    parameter int unsigned PIXEL_HEIGHT = 32;
    parameter int unsigned PIXEL_HALFHEIGHT = 16;
endpackage
