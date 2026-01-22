// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package enums;
    typedef enum {
        STATE_IDLE,
        STATE_CMD_READROW,
        STATE_CMD_READCOL,
        STATE_CMD_READBRIGHTNESS,
        STATE_CMD_BLANKPANEL,
        STATE_CMD_FILLPANEL,
        STATE_CMD_FILLRECT,
        STATE_CMD_READRECT,
        STATE_CMD_READPIXEL,
        STATE_CMD_READFRAME
`ifdef USE_WATCHDOG,
        STATE_CMD_WATCHDOG
`endif
    } control_module_fsm_e;
endpackage
