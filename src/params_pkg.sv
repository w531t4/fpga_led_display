// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package params_pkg;
`ifdef RGB24
    parameter int unsigned BRIGHTNESS_LEVELS = 8;
`else
    parameter int unsigned BRIGHTNESS_LEVELS = 6;
`endif
endpackage
