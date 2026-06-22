<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->

# PLAN2 — Fix the ULX3S SDRAM clock phase (90° via ODDR)

## Context

This branch migrates the framebuffer BRAM → SDRAM; SDRAM has never displayed
correctly on hardware (first-time SDR PHY bring-up). The display logic is correct
in sim and closes timing. The hardware symptom — flickering structured noise that
*changes every refresh* — is **physical read corruption from a wrong SDRAM clock
phase**, not a logic/mapping bug. The stopgap `sdram_clk = ~clk` (a crude
combinational 180°) already moved the panel from total noise → partially-recognizable
structure, confirming phase is the lever.

This is a **solved problem on ULX3S.** The upstream LiteX target
(`litex-boards/targets/radiona_ulx3s.py`, same GENSDRPHY as our `ulx3s_sdram.yml`)
drives the SDRAM clock as a **90°** phase-shifted clock
(`pll.create_clkout(cd_sys_ps, sys_clk_freq, phase=90)`) forwarded through a **DDR
output register** (`DDROutput(1, 0, sdram_clock, ClockSignal("sys_ps"))`). We
replicate that.

## The fix (the only required work)

1. **`src/new_pll.sv`** — add a 90° phase-shifted clock at the system frequency:
   enable the unused EHXPLLL **CLKOS2** output (same `CLKOS2_DIV` as CLKOS) with
   `CLKOS2_CPHASE/FPHASE` set for **90°** (step = 360°/CLKOS_DIV; verify with
   `ecppll`/the ECP5PLL formula). Add a `clock_shifted` output port.
   - Pre-req: the existing CLKOS `CPHASE/FPHASE` constants are garbage on SPEED 2
     (`:137-138`) and SPEED 5 (`:268-269`) — harmless today but must be fixed
     before relying on PLL phase.
2. **`src/litedram/ulx3s_litedram_wrapper.sv`** — replace the `~clk` assign with an
   ECP5 `ODDRX1F` forwarding `clock_shifted` to the pad (mirrors LiteX's
   `DDROutput(1, 0, ...)`): `ODDRX1F u(.SCLK(clock_shifted), .RST(1'b0), .D0(1'b1),
   .D1(1'b0), .Q(sdram_clk));`. Guard with `ifndef SIM` (ODDRX1F is synth-only, no
   Verilator model — keep a plain assign for the SIM branch, where `sdram_clk` is
   unused). `sdram_clk` is owned by the wrapper (the generated core drives no clock
   pad; plain LVCMOS33 output, `lpf:256/295`) → **no LiteDRAM regen needed.**
3. **`src/main.sv`** — thread the new `clock_shifted` from the `new_pll` instance
   into the wrapper port.

Then `make pack-until-success EXTRA_BUILD_FLAGS="-DUSE_LITEDRAM -DUSE_SDRAM_FB"`,
flash, and **compare the display to `actual_test_pattern.jpeg`.** The panel is the
test.

## Contingencies (only if 90° isn't clean — not done upfront)

- **Still some corruption:** try ±1 CPHASE step around 90° (board variation), or
  fall back to LiteX's default 50 MHz (`mk/config.mk:49` `-DCLK_80`→`-DCLK_50`,
  `ulx3s_sdram.yml:13` `80e6`→`50e6`, `make clean`; recompute CLKOS2 CPHASE for the
  new CLKOS_DIV). The SDRAM chip supports 80 MHz, so this is a margin fallback.
- **Isolate PHY from framebuffer:** make `litedram_bist.sv` a sustained loop (many
  addresses/patterns, sticky `error` → `led[4]`); pass = `led[0]`+`led[3]` on,
  `led[1/2/4]` off.
- **Reads clean but image still wrong (mapping bug surfaces):** add an end-to-end
  `tb_sdram_fb_e2e.sv` (real `sdram_write_client` → sim core → `sdram_arbiter` →
  `row_prefetch`, known pattern round-trip) — the gap `tb_row_prefetch` doesn't cover.

## Verification

- Sim green: `make simulation` and `make simulation EXTRA_BUILD_FLAGS="-DUSE_LITEDRAM -DUSE_SDRAM_FB"`.
- `pack-until-success` closes timing.
- Hardware: display matches `actual_test_pattern.jpeg`, no flicker.
