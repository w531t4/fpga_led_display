<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# Observed Display Faults

A running log of display faults **exactly as observed in photos**. Each entry records
where it was seen, what we **see**, and what we **expect**. Root-cause / justification is
intentionally deferred — the `Justification` fields are placeholders to fill in later.

## References

- **`test_pattern.jpg`** — clean capture of the built-in test pattern (`run_test_graphic`), from commit 47bf8af33961abb41b9f5a9869a362e8dd97b440
  used as the "the panel + pipeline *can* render cleanly" reference. It shows: a solid
  **yellow** vertical bar flush to the **left** edge, a solid **white** vertical bar flush
  to the **right** edge, full-width thin **red** (top) / **cyan** (middle) / **green**
  (bottom) horizontal lines, and a centered multicolor **gradient rectangle**. All elements
  crisp, solid, full-width, and edge-flush.
- **Panel geometry:** 768 × 32 px (12 × 64-wide HUB75 panels; 2 subpanels of 16 rows).
- test_pattern.jpg was captured while hardware was running firmware from a commit at the beginning of the current branch. it contains NO SDRAM code.

---

## F1 — Mixed-RGB pixel corruption across bottom of strip — ⛔ CLOSED (stale)

- **Observed in:** `IMG_0161.JPG` (live chat/overlay scene; on-screen clock reads JUN 25, 17:32)
- **What we see:**
  - **Mixed, randomly-colored (RGB) pixels** (not forming coherent content) overlaid on the display across the bottom ~15 rows
    - Present **across the entire width** of the strip and over **every element** — the left avatar thumbnails, the center chat region, **and** underneath the right-hand weather icon, date, temperatures, and hour/minute clock.
    - **different densities**
      - Most dense across avatars and twitch chat sections. density is consistent.
      - Less dense, more sparse/scattered across right-hand side items (like: weather, temps, hours, minutes)
    - Legible content (chat lines, clock digits) still **shows through** where the stray-pixel density is low.
  - The upper left hand corner has 2-3 pixels that are green and shouldn't be.
    - Outside of the 2-3 pixels cited above, the top-most ~16-17 rows of the display are perfect
- **What we expect:** The whole strip renders cleanly with **no** random pixels anywhere — every element (avatars, chat, weather, date, clock) crisp
- **Justification:** _Not investigated — see Status._
- **Status:** **CLOSED (STALE)** (per Aaron, 2026-06-27). The capture (`IMG_0161.JPG`,
  JUN 25) predates the F2 fix and subsequent framebuffer work and no longer reflects current
  hardware behavior. Reopen with a fresh capture if bottom-row corruption recurs.

---

## F2 — Test pattern: red top band dashes on the right (F2.a) + magenta bar ~8 cols short of the right edge (F2.b) — ✅ FIXED (commit `9c3e75d`)

- **Observed in:** `IMG_0175.JPG` (built-in test pattern / `run_test_graphic` scene)
- **What we see (by `run_test_graphic` object; from native-resolution 22 MP crops):**
  - incorrect:
    - a) **Red top band (`drawRowRGB888`):** solid/continuous for the **left ~3/5** of the board (yellow bar → ~3/5 of the way across), then degrades into a **regularly-spaced dashed line of short red segments** (periodic gaps, at a roughly constant height — **not** drifting/scattered) across the **right ~2/5**. **This is the fault — and it is the only band affected.**

    - b) **Magenta right accent bar (`drawColumnRGB888`) is ~8 LED columns SHORT of the right edge:** the box's rightmost ~8 columns are missing, so the red/blue/green bands (drawn full-width underneath it) **show through and continue past the box's right edge** out to the panel's true right edge in those final ~8 columns. The bands reach the edge; the box does not. **This is a second fault** (matches the earlier "magenta offset ~5–8px" report). Measured: box edge ≈ x5420, bands end ≈ x5470 (~50 px ≈ ~8 LED columns at ~5.8 px/col).
      - each time i enter demo-mode, the magenta bar appears to offset from its desired location (all the way on the right) by a varying number of pixels (usually between 5-8)
  - correct:
    - **Blue/cyan center band (`fillRect`):** solid, continuous, **full width** (confirmed through and past the gradient rectangle, out to the magenta bar) — correct.
    - **Green bottom band (`fillRect`):** solid, continuous, full width — correct.
    -  **Yellow left accent bar (`drawColumnRGB888`):** solid — correct. The **orange diagonal** (`drawPixelRGB888`, from top-left) is clearly visible running through it — present/correct.
    - **White diagonal (`drawPixelRGB888`, from top-right):** **present** (visible by eye on the panel; washed out by the magenta bar's brightness in this camera exposure, so not separable in the photo crop).
    - **Center gradient rectangle (`drawRectRGB888`):** correct — looks odd in the photo but is the intended gradient (ignore).
- **What we expect (per `test_pattern.jpg`):**
  - The **red top band** renders as a single solid line spanning the **full width**, exactly
    like the blue and green bands below it.
  - The **magenta right bar** reaches the **true right edge** (covers its full ~48 columns,
    cols 720–767), so the bands do **not** show through past it — its right edge is flush with
    the panel edge.
- **Justification:**
  - **F2.a (red top-band dashing):** now renders as a solid full-width line (confirmed by
    eye — the whole test pattern looks correct). Attributed to the **same** `busy`-fix as
    F2.b: `drawRowRGB888` is the same class of host-streamed line primitive driven through
    the same worker-queue / off-chip `busy` path, so once `busy` stopped lingering on each
    write's SDRAM commit, the host stopped dropping the row's right-hand segments. Not
    independently instrumented like F2.b, but resolved by the same change and visually clean.
  - **F2.b (magenta bar short):** the host's `drawColumnRGB888` worker queue (34-deep,
    drop-on-full enqueue) overflowed and silently dropped the **rightmost** columns,
    because the FPGA held its off-chip `busy` line high until each column's SDRAM writes
    fully **committed** (slow row-miss writes, 32 px down 32 rows). The unchanged host —
    which renders this flush on the BRAM build, where `busy` clears instantly — couldn't
    keep up, so the tail columns were dropped **on the host side**, varying 5–8 px
    run-to-run. Not an analog/mapping offset; a `busy`-timing-induced host-queue overflow.
- **Fix attempts:**
  - **T1 — raise system/SDRAM clock 50 → 70 MHz** (more SDRAM bandwidth; added `CLK_70` /
    `new_pll` SPEED 6 with a 90° SDRAM clock, regenerated the LiteDRAM core at 70e6).
    **Result: NO change** — neither F2.a (red dashing) nor F2.b (magenta short) improved,
    and **no new issues** appeared. **Reverted to CLK_50.** Takeaway: a ~40% bandwidth
    increase changing *nothing* argues F2 is **deterministic/structural**, not
    bandwidth-/contention-bound. (Note F2.b varies 5–8px run-to-run → a race/timing tail,
    not a fixed mapping offset.)
  - **T2 — fix F2.b (DONE):** clear `busy` on write-FIFO **space** instead of full drain
    (defer only the frame *swap* until `sdram_write_drained`, so no tearing) + deepen the
    write FIFO to 8192 (block-RAM) so the whole 48-col / 4608-write burst is absorbed and
    `busy` clears fast for every column. **Result: F2.b FIXED** (commit `9c3e75d` — note its
    "- fail" message was premature; the fix is intact in the current tree:
    `control_module.sv:460,511`, `sdram_write_client.sv:15`). Measured in sim: busy-hold per
    drawColumn 29370 → 3234 cy (= SPI-transfer floor, BRAM-equivalent); within-command write
    drops 2079 → 0; no swap while a write is in flight. (Deep-FIFO **alone** had made it
    WORSE — `busy` then waited on the deeper drain — so the two changes are needed together.)
- **Status:** **FIXED** — both F2.a and F2.b, confirmed by eye 2026-06-27 (full test pattern
  renders clean). Root fix: commit `9c3e75d` (`busy` clears on write-FIFO space + deferred
  swap + 8192 write FIFO). F2.b independently sim-instrumented; F2.a attributed to the same
  fix.

---

## F3 — Test pattern: yellow left accent bar width is unstable (too wide, flexing) — ✅ FIXED (commit `9c3e75d`)

- **Observed in:** live demo mode (`run_test_graphic`), observed directly by eye (intermittent — not yet captured in a still)
- **What we see:**
  - **Yellow left accent bar (`drawColumnRGB888`, cols 0–47):** the **left edge is always correctly flush to the left** of the window, but the bar's **width is at times LARGER than it should be** (its right edge extends past the intended column), and the width visibly **flexes** — it changes over time / frame-to-frame rather than holding a fixed width.
- **What we expect (per `test_pattern.jpg`):** a solid yellow bar at its intended width (~48 columns, cols 0–47) with a **stable** right edge — no over-width, no flexing.
- **Justification:** same root cause as **F2.b** — `drawColumnRGB888` is host-streamed
  through the same worker-queue / off-chip `busy` path; while `busy` lingered on each write's
  SDRAM commit, the host dropped/over-ran the bar's right-edge columns so its width flexed
  frame-to-frame. The `busy`-fix (commit `9c3e75d`) cleared it.
- **Relation:** same fault class as **F2.b** — both `drawColumnRGB888` bars with
  frame-to-frame-unstable width (yellow trended **wider**, magenta trended **shorter**);
  both fixed by commit `9c3e75d`.
- **Status:** **FIXED** (commit `9c3e75d`; same `busy`-fix as F2.b). Confirmed by eye 2026-06-27
  — full test pattern renders clean, yellow bar holds a stable width.

---

<!--
Template for new entries:

## F# — <short title>

- **Observed in:** `<image filename>` (<scene / timestamp shown>)
- **What we see:** <observation only>
- **What we expect:** <expected rendering; reference test_pattern.jpg where useful>
- **Justification:** _TBD._
- **Status:** OPEN | FIXED | WON'T-FIX
-->
