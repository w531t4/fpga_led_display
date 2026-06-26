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

## F1 — Mixed-RGB pixel corruption across bottom of strip

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
- **Justification:** _TBD._
- **Status:** OPEN

---

## F2 — Test pattern: red top band dashes on the right + magenta bar ~8 cols short of the right edge

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
- **Justification:** _TBD._
- **Fix attempts:**
  - **T1 — raise system/SDRAM clock 50 → 70 MHz** (more SDRAM bandwidth; added `CLK_70` /
    `new_pll` SPEED 6 with a 90° SDRAM clock, regenerated the LiteDRAM core at 70e6).
    **Result: NO change** — neither F2.a (red dashing) nor F2.b (magenta short) improved,
    and **no new issues** appeared. **Reverted to CLK_50.** Takeaway: a ~40% bandwidth
    increase changing *nothing* argues F2 is **deterministic/structural**, not
    bandwidth-/contention-bound. (Note F2.b varies 5–8px run-to-run → a race/timing tail,
    not a fixed mapping offset.)
  - **T2 (next):** attempt to fix **F2.b** (magenta bar 5–8 cols short of the right edge)
    specifically.
- **Status:** OPEN

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
