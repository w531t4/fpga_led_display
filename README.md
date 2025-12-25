<!--
SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# fpga_led_display
A recipe driving a chain of LED matricies with a FPGA
![LED matrix static demo](.github/images/display_picture.jpeg)
![LED matrix video demo](.github/videos/active_display.gif)

NOTE: Displaying widgets on the display (as shown above) is out of scope for this project. For more information on how that's done, please see:
- A c++ interface capable of issuing compatible commands (via SPI) to FPGA (https://github.com/w531t4/ESP32-FPGA-MatrixPanel)
- A ESPHome module which uses the above C++ interface to allow it to write content to the display (https://github.com/w531t4/ESPHome-FPGA-MatrixPanelWrapper)
- A manager for widgets to be displayed on the display (i'm working on releasing this code)

## Features
- Supports chained topologies - n-bit width by 8-bit height
- RGB24/RGB565 color
- FPGA UART debugger (TX) + UART python debugger console (RX)
- Feed FPGA data with UART or SPI
- Gamma adjustment
- Testbenches for main + many submodules
- Uses logic that both simulates and synthesizes well with the open source toolchain (YosysHQ/oss-cad-quite-build) [see below]

## Getting Started
1. Clone the project.
1. Launch devcontainer in vscode
1. Adjust compile parameters in `Makefile` (for instance, enabling the debugger '-DDEBUGGER')
1. Run `make` (this will produce simulations and render them in build/simulations)
1. Run `make pack` (will build, route, and pack a bitstream. bitstream is wrriten as build/ulx3s.bit)
1. Connect the ULX3s to the computer using USB [use the connector on the upper left of the board]
1. Run `make memprog` (will write build/ulx3s.bit to the ULX3s, but it will NOT persist a powercycle of the FPGA)

## Writing to ULX3s from RPI (raspi-os)
1. `sudo usermod -aG plugdev,dialout <user>`
1. Get idProduct and idVendor from lsubsb - `sudo lsusb | grep "Future Technology Devices International, Ltd Bridge"`
    - Will print something like this `Bus 001 Device 002: ID 0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)`
1. `printf '%s\n' 'SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", GROUP="plugdev", MODE="0660"' | sudo tee /etc/udev/rules.d/99-ulx3s.rules`
1. `sudo udevadm control --reload-rules`
1. `sudo udevadm trigger`
1.  Note, in above output of `lsusb`.. `Bus 001 Device 002:`
    - Verify `ls -fl /dev/bus/usb/001/002` (replace bus/device with appropriate figures) has ownership of root:plugdev

## Persisting bitstream to execute at startup
The ULX3s has write-protected flash that prevents `fujproj` from writing to a location that will persist across powercycles.
A different command (from the open source toolchain) must be used with a flag for unprotecting the flash contents.
`oss-cad-suite/bin/openFPGALoader -b ulx3s --unprotect-flash -f build/ulx3s.bit`

## Restoring the "original"/preloaded bitstream
The original bitstream that is loaded to the ULX3s at shipping time convieniently allows the user to both:
1. Write new images to the FPGA over USB
1. Write content to the ESP32 over USB

At times (when working with the ESP32), it was very helpful to be able to return back to this image so i could monitor its serial output (or recover from a broken esp32 image).

To restore, run `make restore`.

# Performance
- When clk_root is set to 90mhz, the design can sustain 64x32 x12 refresh rate using rgb24 at 156hz.
- When clk_root is set to 100mhz, the design can sustain 64x32 x12 refresh rate using rgb24 at 188hz
- When clk_root is set to 110mhz (and using 12 64x32 panels, it's clear that we start to see timing issues at the rear-end of the chain)

# Acknowledgements

This project is based on and incorporates code from:

- **Driving an LED Matrix with a TinyFPGA** by Attie Grande <attie@attie.co.uk>
  - https://github.com/attie/led_matrix_tinyfpga_a2
  - License: MIT
  - Significant modifications and extensions have been made.
- **Basic UART TX/RX module for FPGA** by Matt Alencar
  - https://github.com/matt-alencar/fpga-uart-tx-rx
  - License: MIT
- **spi_verilog_master_slave** by Santhosh G <santhg@opencores.org>
  - https://opencores.org/projects/spi_verilog_master_slave
  - License: LGPL-2.1-or-later
- **Homeassistant Core** by Homeassistant Authors
  - https://github.com/home-assistant/core
  - License: Apache-2.0

# Third-party Components

This project includes the following third-party components as git submodules:

- **yosys_ecp5_infer_bram_outreg** by Rowan Goemans <goemansrowan@gmail.com>
  - https://github.com/rowanG077/yosys_ecp5_infer_bram_outreg
  - License: MIT
