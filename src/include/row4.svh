// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`ifdef RGB24
    `ifdef W128
        // this is abcdefghij placed in middle of displays
        // 2048 + 16
        localparam readrow_cmd_t myled_row_basic = readrow_cmd_t'({commands_pkg::READROW, row_addr_view_t'('h04), row_data_t'('h490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa7014501860186014501650186018609460145014501450125012401250124012501450145014501250145014501450125014501660186096601650166016501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a20083006501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a2008300490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa7014501860186014501650186018609460145014501450125012401250124012501450145014501250145014501450125014501660186096601650166016501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a20083006501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a2008300490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa7014501860186014501650186018609460145014501450125012401250124012501450145014501250145014501450125014501660186096601650166016501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a20083006501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a2008300)});

    `else
        localparam readrow_cmd_t myled_row_basic = readrow_cmd_t'({commands_pkg::READROW, row_addr_view_t'('h04), row_data_t'('hFFFEFD000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000_EFEEED)});
        // FF-> 0x04fd (12bits)
        // FE-> 0x04fe
        // FD-> 0x04ff
        // EF-> 0x0401
        // EE-> 0x0402
        // ED-> 0x0403
    `endif
`else
    `ifdef W128
        localparam readrow_cmd_t myled_row_basic = readrow_cmd_t'({commands_pkg::READROW, row_addr_view_t'('h04), row_data_t'('h490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa7014501860186014501650186018609460145014501450125012401250124012501450145014501250145014501450125014501660186096601650166016501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a2008300490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa701450186018601450165018601860946014501450145012501240125012401250145014501450125014501450145012501450166018609660165016601490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa7014501860186014501650186018609460145014501450125012401250124012501450145014501250145014501450125014501660186096601650166016501660186096601650946016501450144012501240125012401250124012501450125010401e4000301e400c3004601e300250144092501a611c711e719c811c719a7114a5b539d739d02090401e400e300a300a2008200820082008200620061006200610062006100620061006200810062008200820082008200a2008300490229022902ab0acb02ec028a0a4a02280aa701a601a701a601a701c7010902ab128b0a0f4c9675346d9354d34c112c2d238b0a290a4a0a290a0902aa12ab12280aa701450186018601450165018601860946014501450145012501240125012401250145014501450125014501450145012501450166018609660165016601)});

    `else
        localparam readrow_cmd_t myled_row_basic = readrow_cmd_t'({commands_pkg::READROW, row_addr_view_t'('h04), row_data_t'('h49026b02cb0a6a02e7018701c701e801aa12d354345d5144cc1a4a02290a8b12c7016601850166016501450124012501440145014501450145014601650966016509660165014501440125012401250144010401e300040104014501c711c811a51971746c53a200c30082008200820061006200610062008200820082008300)});
    `endif
`endif
// Add tests for pixel set command
localparam brightness3_cmd_t myled_row_brightness_1 = brightness3_cmd_t'({commands_pkg::BRIGHTNESS_THREE});

localparam readbrightness_cmd_t myled_row_brightness_2 =
    readbrightness_cmd_t'({commands_pkg::READBRIGHTNESS, brightness_level_view_t'('h23)}); // "T" + \x23
localparam readbrightness_cmd_t myled_row_brightness_3 =
    readbrightness_cmd_t'({commands_pkg::READBRIGHTNESS, brightness_level_view_t'('h38)}); // "T" + \x38

localparam blankpanel_cmd_t myled_row_blankpanel = blankpanel_cmd_t'({commands_pkg::BLANKPANEL});

`ifdef USE_WATCHDOG
    localparam watchdog_cmd_t myled_row_watchdog = watchdog_cmd_t'({commands_pkg::WATCHDOG, watchdog_pattern_t'(params_pkg::WATCHDOG_SIGNATURE_PATTERN)}); // "W" + "DEADBEEFFEEBDAED"
`endif
`ifdef RGB24
    `ifdef W128
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h0078), color_t'('h132040)});
        localparam readpixel_cmd_t myled_row_pixel2 = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h0079), color_t'('h304013)});
        localparam fillrect_cmd_t myled_row_fillrect = fillrect_cmd_t'({commands_pkg::FILLRECT, col_field_t'('h0001), row_field_t'('h0A), col_field_t'('h0071), row_field_t'('h05), color_t'('hE0A932)});
    `else
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h30), color_t'('h132040)});
        localparam readpixel_cmd_t myled_row_pixel2 = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h32), color_t'('h304013)});
        localparam fillrect_cmd_t myled_row_fillrect = fillrect_cmd_t'({commands_pkg::FILLRECT, col_field_t'('h05), row_field_t'('h0A), col_field_t'('h10), row_field_t'('h05), color_t'('hE0A932)});
    `endif
    localparam fillpanel_cmd_t myled_row_fillpanel = fillpanel_cmd_t'({commands_pkg::FILLPANEL, color_t'('h314287)});
`else
    `ifdef W128
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h0078), color_t'('h1020)});
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h0079), color_t'('h3040)});
        localparam fillrect_cmd_t myled_row_fillrect = fillrect_cmd_t'({commands_pkg::FILLRECT, col_field_t'('h0001), row_field_t'('h0A), col_field_t'('h0071), row_field_t'('h05), color_t'('hE0A9)});
    `else
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h00), col_addr_view_t'('h30), color_t'('h1020)});
        localparam readpixel_cmd_t myled_row_pixel = readpixel_cmd_t'({commands_pkg::READPIXEL, row_addr_view_t'('h01), col_addr_view_t'('h32), color_t'('h3040)});
        localparam fillrect_cmd_t myled_row_fillrect = fillrect_cmd_t'({commands_pkg::FILLRECT, col_field_t'('h05), row_field_t'('h0A), col_field_t'('h10), row_field_t'('h05), color_t'('hE0A9)});
    `endif
    localparam fillpanel_cmd_t myled_row_fillpanel = fillpanel_cmd_t'({commands_pkg::FILLPANEL, color_t'('h3142)});
`endif
logic [
        ($bits(myled_row_blankpanel)
            + $bits(myled_row_fillpanel)
            + $bits(myled_row_fillrect)
            `ifdef USE_WATCHDOG
                + $bits(myled_row_watchdog)
            `endif
            `ifdef RGB24
                + $bits(myled_row_basic)
            `endif
            + $bits(myled_row_pixel)
            + $bits(myled_row_pixel2)
            + $bits(myled_row_brightness_1)
            + $bits(myled_row_brightness_2)
            + $bits(myled_row_brightness_3)
        )-1:0] myled_row = {
                                            myled_row_blankpanel,
                                            `ifdef USE_WATCHDOG
                                                myled_row_watchdog,
                                            `endif
                                            myled_row_fillpanel,
                                            myled_row_fillrect,
                                            myled_row_pixel,
                                            myled_row_pixel2,
                                            myled_row_brightness_1,
                                            myled_row_brightness_2,
                                            myled_row_brightness_3,
                                            myled_row_basic
                                        };
