// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
package commands_pkg;

    // Command opcodes accepted by control_module.
    typedef enum logic [7:0] {
        READBRIGHTNESS = "T",
        BLANKPANEL     = "Z",
        FILLPANEL      = "F",
        FILLRECT       = "f",
        READFRAME      = "Y",
        READROW        = "L",
        READPIXEL      = "P",
`ifdef USE_WATCHDOG
        WATCHDOG       = "W",
`endif
`ifdef DOUBLE_BUFFER
        TOGGLE_FRAME   = "t",
`endif
        RED_ENABLE     = "R",
        RED_DISABLE    = "r",
        BLUE_ENABLE    = "G",
        BLUE_DISABLE   = "g",
        GREEN_ENABLE   = "B",
        GREEN_DISABLE  = "b",

        BRIGHTNESS_ZERO  = "0",
        BRIGHTNESS_ONE   = "1",
        BRIGHTNESS_TWO   = "2",
        BRIGHTNESS_THREE = "3",
        BRIGHTNESS_FOUR  = "4",
        BRIGHTNESS_FIVE  = "5",
        BRIGHTNESS_SIX   = "6",
`ifdef RGB24
        BRIGHTNESS_SEVEN = "7",
        BRIGHTNESS_EIGHT = "8",
`endif
        BRIGHTNESS_NINE  = "9"
    } cmd_opcode_t;
    typedef union packed {
        cmd_opcode_t opcode;
        logic [7:0]  data;
    } indata8_t;
endpackage
