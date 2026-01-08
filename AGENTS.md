<!--
SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->

# fpga_led_display

This is a systemverilog design for driving large led matricies using an SPI bus. This is one of many projects that when combined together yield a "Heads-up display" that sits below a television.

## Architecture Components

    - url: https://github.com/w531t4/ESP32-FPGA-MatrixPanel
      desc: C++ driver which interfaces over SPI with FPGA
    - url: https://github.com/w531t4/ESPHome-FPGA-MatrixPanelWrapper
      desc: ESPHome Component Wrapper for ESP32-FPGA-MatrixPanel
    - url: https://github.com/w531t4/ESPHome-display_layout
      desc: C++ wrapper for ESPHome display which organizes a collection of "widgets"
    - url: https://github.com/w531t4/ESPHome-core_load
      desc: ESPHome Component necessary for monitoring core usage
    - url: https://github.com/w531t4/twitch_thumbnails
      desc: Uses entities from HomeAssistant (twitch) app to fetch and concatenate icons of streams
    - url: https://github.com/w531t4/twitch_firetvappstate
      desc: Determines when the Twitch FireTV app is open and which streamer is being watched
    - url: https://github.com/w531t4/twitch_fetchchat
      desc: Connects anonymously to a twitch streamers chat channel and pushes messages to Homeassistant

# Configuration

    - The project is driven using compile-time arguments contained the BUILD_FLAGS variable in ./Makefile
    - ./build contains build-time artifacts
    - The environment is wired to use ccache. It improves compilation times (for simulations) by 75-80%.

# General Guidance

    - _Never_ make commits
    - Project must be REUSE compilant
    - Avoid embedding magic numbers into the code. Store constants in `params.sv`.
    - logic [$clog2(VAR)-1:0] *_index_t
    - logic [$clog2(VAR+1)-1:0] *_count_t
    - minimize spaghetti offset calculations by (re)using structures [when possible]
    - test your work (using `make`) before suggesting it be included
    - Aim to minimize the lines of code changed to accomplish a given task
    - Always incrementally improve
    - Heavily comment new code

## Linting

run `make lint`

## Simulation

run `make simulation`

## Creating Bitstream

run `make pack`

## Troubleshooting

- desc: nicely print top-n contributors to timing issues with clk_root
  path: src/scripts/analyze_clk_root.py build/nextpnr-report.json