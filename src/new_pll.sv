// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
// diamond 3.7 accepts this PLL
// diamond 3.8-3.9 is untested
// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
// cause of this could be from wrong CPHASE/FPHASE parameters

`ifdef SIM
`timescale 1ns / 10ps
`endif

// SDRAM device-clock phase (SPEED 2 / 80 MHz CLKOS), as ECP5 PLL CPHASE/FPHASE.
// Default 4/6 == +90 deg, the LiteX ULX3S known-good SDR relationship that made
// the display correct. One FPHASE step ~= 6.4 deg (360/CLKOS_DIV/8, CLKOS_DIV=7);
// CPHASE+1 == +51.4 deg. Reads are clean at 90 deg but writes are marginal (some
// pixels persist wrong), so the optimum write/read compromise may be a few FPHASE
// steps off 90. Override per-build to sweep the SDRAM clock phase WITHOUT editing
// source, e.g. EXTRA_BUILD_FLAGS="... -DSDRAM_CLK_FPHASE=4" (~77 deg) or
// "-DSDRAM_CLK_CPHASE=5 -DSDRAM_CLK_FPHASE=0" (~103 deg). Sweep grid around 90:
//   77: C4 F4 | 84: C4 F5 | 90: C4 F6 | 96: C4 F7 | 103: C5 F0 | 109: C5 F1
// Default depends on the active clock (different CLKOS_DIV -> different CPHASE for
// 90 deg): 50MHz (SPEED 1, CLKOS_DIV=12) = 8/0; 80MHz (SPEED 2, CLKOS_DIV=7) = 4/6.
// One FPHASE step ~= 360/CLKOS_DIV/8 (3.75 deg at 50MHz, 6.4 deg at 80MHz); CPHASE+1
// = 360/CLKOS_DIV. Override to sweep the SDRAM-clock (= write/read sample) phase on
// hardware against the litedram_bist error LED, e.g. at 50MHz:
//   C7 F4 ~= 76 | C8 F0 = 90 | C8 F4 ~= 105 | C9 F0 = 120 | C9 F4 ~= 135 deg
`ifndef SDRAM_CLK_CPHASE
 `ifdef CLK_50
  `define SDRAM_CLK_CPHASE 8
 `else
  `define SDRAM_CLK_CPHASE 4
 `endif
`endif
`ifndef SDRAM_CLK_FPHASE
 `ifdef CLK_50
  `define SDRAM_CLK_FPHASE 0
 `else
  `define SDRAM_CLK_FPHASE 6
 `endif
`endif

module new_pll #(
    parameter integer unsigned SPEED = 0,  // 0 - 16mhz, 1 - 50mhz, 2 - 80mhz 3 - 90mhz, 4 - 100mhz, 5 - 110mhz - else use the incoming 25mhz clock
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  clock_in,      // 25 MHz, 0 deg
    output clock_out,     // system clock, depends on SPEED
    // Same frequency as clock_out but +90 deg, for the SDRAM device clock (the
    // ULX3S/LiteX known-good SDR relationship -- see PLAN2.md). Only the SPEED 2
    // (80 MHz) branch produces a true 90 deg shift today; other speeds tie it to
    // clock_out (they are not the active SDRAM build).
    output clock_shifted,
    output locked
);
`ifdef SIM
    assign clock_out = clock_in;
    assign clock_shifted = clock_in;
    assign locked = 1'b1;
`else
    wire clkfb;
    if (SPEED == 0) begin : g_speed0
        assign clock_shifted = clock_out;  // no SDRAM 90deg output at this speed
        // oss-cad-suite/bin/ecppll --clkin_name clock_in --clkout0_name clock_out -i 25 -o 16 -n pll --highres --file abc
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOS="16" *)
        (* ICP_CURRENT="12" *)
        (* LPF_RESISTOR="8" *)
        (* MFG_ENABLE_FILTEROPAMP="1" *)
        (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(5),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(56),
            .CLKOP_CPHASE(9),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(35),
            .CLKOS_CPHASE(0),
            .CLKOS_FPHASE(0),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(2)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clkfb),
            .CLKOS(clock_out),
            .CLKFB(clkfb),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 1) begin : g_speed1
        // ecppll: -i 25 --clkout0 50 --clkout1 50 --phase1 90 (no --highres).
        // CLKOP = clock_out (50 MHz, 0 deg, also the feedback); CLKOS =
        // clock_shifted (50 MHz, +90 deg) for the SDRAM device clock. 50 MHz
        // widens the SDR write/cmd/read timing windows ~60% vs 80 MHz -- the LiteX
        // ULX3S known-good SDRAM rate. CLKOS_DIV=12 so one VCO cycle = 30 deg;
        // CLKOS_CPHASE=8 vs CLKOP_CPHASE=5 == +3 cycles == +90 deg.
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOP="50" *)
        (* FREQUENCY_PIN_CLKOS="50" *)
        (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(1),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(12),
            .CLKOP_CPHASE(5),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(12),
            .CLKOS_CPHASE(`SDRAM_CLK_CPHASE),
            .CLKOS_FPHASE(`SDRAM_CLK_FPHASE),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(2)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clock_out),
            .CLKOS(clock_shifted),
            .CLKFB(clock_out),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 2) begin : g_speed2
        // ecppll: -i 25 --clkout0 80 --clkout1 80 --phase1 90  (no --highres).
        // CLKOP = clock_out (80 MHz, 0 deg, also the feedback); CLKOS =
        // clock_shifted (80 MHz, +90 deg) for the SDRAM device clock. This also
        // replaces the previous out-of-range CLKOS CPHASE/FPHASE constants.
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOP="80" *)
        (* FREQUENCY_PIN_CLKOS="80" *)
        (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(5),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(7),
            .CLKOP_CPHASE(3),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(7),
            .CLKOS_CPHASE(`SDRAM_CLK_CPHASE),
            .CLKOS_FPHASE(`SDRAM_CLK_FPHASE),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(16)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clock_out),
            .CLKOS(clock_shifted),
            .CLKFB(clock_out),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 3) begin : g_speed3
        assign clock_shifted = clock_out;  // no SDRAM 90deg output at this speed
        // oss-cad-suite/bin/ecppll --clkin_name clock_in --clkout0_name clock_out -i 25 -o 90 -n pll --highres --file abc
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOS="90" *)
        (* ICP_CURRENT="12" *)
        (* LPF_RESISTOR="8" *)
        (* MFG_ENABLE_FILTEROPAMP="1" *)
        (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(5),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(63),
            .CLKOP_CPHASE(9),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(7),
            .CLKOS_CPHASE(0),
            .CLKOS_FPHASE(0),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(2)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clkfb),
            .CLKOS(clock_out),
            .CLKFB(clkfb),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 4) begin : g_speed4
        assign clock_shifted = clock_out;  // no SDRAM 90deg output at this speed
        // oss-cad-suite/bin/ecppll --clkin_name clock_in --clkout0_name clock_out -i 25 -o 100 -n pll --highres --file abc
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOS="100" *)
        (* ICP_CURRENT="12" *)
        (* LPF_RESISTOR="8" *)
        (* MFG_ENABLE_FILTEROPAMP="1" *)
        (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(1),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(24),
            .CLKOP_CPHASE(9),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(6),
            .CLKOS_CPHASE(0),
            .CLKOS_FPHASE(0),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(1)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clkfb),
            .CLKOS(clock_out),
            .CLKFB(clkfb),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 5) begin : g_speed5
        assign clock_shifted = clock_out;  // no SDRAM 90deg output at this speed
        (* FREQUENCY_PIN_CLKI="25" *)
            (* FREQUENCY_PIN_CLKOS="110" *)
            (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(1),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(22),
            .CLKOP_CPHASE(9),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(5),
            .CLKOS_CPHASE(343706368),
            .CLKOS_FPHASE(32767),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(1)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clkfb),
            .CLKOS(clock_out),
            .CLKFB(clkfb),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else if (SPEED == 6) begin : g_speed6
        // CLK_40: ecppll -i 25 --clkout0 40 --clkout1 40 --phase1 90. CLKOP = clock_out
        // (40 MHz, 0 deg, also the feedback); CLKOS = clock_shifted (40 MHz, +90 deg)
        // for the SDRAM device clock. 40 MHz is the highest rate the grade-6 ECP5
        // (LFE5U-85F-6) closes clk_root timing at (critical path ~25 ns through the
        // LiteDRAM bank machines + arbiter + copyframe); it also widens the SDR
        // read/write sampling windows vs 50 MHz. VCO=600 (CLKOP_DIV=15); 90 deg =
        // +3.75 VCO cycles -> CLKOS_CPHASE 10 + CLKOS_FPHASE 6. (LiteDRAM regen'd at
        // 40e6 so refresh/timing counts match -- ulx3s_sdram.yml sys_clk_freq.)
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOP="40" *)
        (* FREQUENCY_PIN_CLKOS="40" *)
        (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
        EHXPLLL #(
            .PLLRST_ENA("DISABLED"),
            .INTFB_WAKE("DISABLED"),
            .STDBY_ENABLE("DISABLED"),
            .DPHASE_SOURCE("DISABLED"),
            .OUTDIVIDER_MUXA("DIVA"),
            .OUTDIVIDER_MUXB("DIVB"),
            .OUTDIVIDER_MUXC("DIVC"),
            .OUTDIVIDER_MUXD("DIVD"),
            .CLKI_DIV(5),
            .CLKOP_ENABLE("ENABLED"),
            .CLKOP_DIV(15),
            .CLKOP_CPHASE(7),
            .CLKOP_FPHASE(0),
            .CLKOS_ENABLE("ENABLED"),
            .CLKOS_DIV(15),
            .CLKOS_CPHASE(10),
            .CLKOS_FPHASE(6),
            .FEEDBK_PATH("CLKOP"),
            .CLKFB_DIV(8)
        ) pll_i (
            .RST(1'b0),
            .STDBY(1'b0),
            .CLKI(clock_in),
            .CLKOP(clock_out),
            .CLKOS(clock_shifted),
            .CLKFB(clock_out),
            .CLKINTFB(),
            .PHASESEL0(1'b0),
            .PHASESEL1(1'b0),
            .PHASEDIR(1'b1),
            .PHASESTEP(1'b1),
            .PHASELOADREG(1'b1),
            .PLLWAKESYNC(1'b0),
            .ENCLKOP(1'b0),
            .LOCK(locked)
        );
    end else begin : g_speedelse
        assign clock_out = clock_in;
        assign clock_shifted = clock_in;
    end
`endif
    logic _unused_ok = &{1'b0, 1'(SPEED), 1'b0};
endmodule
