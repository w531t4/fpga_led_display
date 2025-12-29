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
module new_pll #(
    parameter SPEED = 0,  // 0 - 16mhz, 1 - 50mhz, 2 - 90mhz, 3 - 100mhz, 4 - 110mhz - else use the incoming 25mhz clock
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  clock_in,   // 25 MHz, 0 deg
    output clock_out,  // depends on SPEED
    output locked
);
`ifdef SIM
    assign clock_out = clock_in;
`else
    wire clkfb;
    if (SPEED == 0) begin
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
    end else if (SPEED == 1) begin
        // oss-cad-suite/bin/ecppll --clkin_name clock_in --clkout0_name clock_out -i 25 -o 50 -n pll --highres --file abc
        (* FREQUENCY_PIN_CLKI="25" *)
        (* FREQUENCY_PIN_CLKOS="50" *)
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
            .CLKOS_DIV(12),
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
    end else if (SPEED == 2) begin
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
    end else if (SPEED == 3) begin
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
    end else if (SPEED == 4) begin
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
    end else begin
        assign clock_out = clock_in;
    end
`endif
    logic _unused_ok = &{1'b0, 1'(SPEED), 1'b0};
endmodule
