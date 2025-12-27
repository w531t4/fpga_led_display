// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package params_pkg;
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
