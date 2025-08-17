# fpga_led_display
A recipe driving a chain of LED matricies with a FPGA

## Features
- Supports matrix topologies - n-pixel width by 8-bit height
- RGB24/RGB565 color
- FPGA UART debugger (TX) + UART python debugger console (RX)
- Feed FPGA data with UART or SPI
- Gamma adjustment
- No vendor IP (except use of PLL)
- Testbenches for main + many submodules
- Uses logic that both simulates and synthesizes well with the open source toolchain (YosysHQ/oss-cad-quite-build) [see below]

## Getting Started
1. Clone the project.
1. Download the latest toolchain release from https://github.com/YosysHQ/oss-cad-suite-build and extract it into the project directory
1. get netlistsvg app by issing `(cd src/scripts; sh create_npm_env.sh)`
1. Pull in submodules `git submodule sync --recursive && git submodule update --init --recursive`
1. If using the extra bram outreg yosys plugin, Install dependencies for `yosys_ecp5_infer_bram_outreg` (https://github.com/rowanG077/yosys_ecp5_infer_bram_outreg.git)
    - For debian/ubuntu - `apt install libreadline-dev tcl-dev`
    - For RHEL/fedora - `dnf install readline-devel tcl8-devel` <-- These are what are necessary, but there are still issues i haven't worked out yet between fedora libstdc++ and the one is oss-cad-suite
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

At times (when working with the ESP32), it was very helpful to be able to return back to this image so i could monitor its serial output.

The original image (at startup), LED's D18 Green, and D0 Red, D1 Orange, and D2 yellow-ish are illuminated. I wasn't able to figure out how to dump the preloaded bitstream, however the following file (https://github.com/emard/ulx3s-bin/blob/master/fpga/dfu/85f-v317/passthru41113043.bit.gz) appears to behave identically, except all led's (D0-D7) are lit.

Follow the instructions (Persisting bitstream to execute at startup) using the above file (after gunzipping it).

# Performance
- When clk_root is set to 90mhz, the design can sustain 64x32 x12 refresh rate using rgb24 at 156hz.
- When clk_root is set to 100mhz, the design can sustain 64x32 x12 refresh rate using rgb24 at 188hz
- When clk_root is set to 110mhz (and using 12 64x32 panels, it's clear that we start to see timing issues at the rear-end of the chain)

# interacting with Tiny FPGA BX via USB
Note: Following instructions from https://tinyfpga.com/bx/guide.html

- `yum install python35 python3-virtualenv -y` # rpi running way old fedberry image
- `virtualenv-3 venv`
- `. venv/bin/activate`
- `pip install tinyprog`

# visualizing verilog
Based on suggestion from https://stackoverflow.com/questions/67923728/yosys-producing-an-electronic-schematics-from-verilog
- install node
- `dnf install python3-nodeenv`
- `nodeenv --verbose nenv` (or) `nodenv --prebuilt nenv`
- `npm install -g netlistsvg`
- use json file from yosys to produce results (see Makefile)


# helpful references
- https://zipcpu.com/blog/2017/06/02/generating-timing.html


# things i'd like to look at
- https://www.youtube.com/watch?v=BcJ6UdDx1vg
- https://www.youtube.com/watch?v=P8MpZGjwgR0
- https://youtu.be/wwANKw36Mjw
- https://youtu.be/xlvqUts9H9c
- https://www.tutorialspoint.com/compile_verilog_online.php (helpful for testing snippets of verilog)
- https://zipcpu.com/fpga-hell.html
- about bram and ice40 https://tinlethax.wordpress.com/2022/05/07/ice40-bram-101-probably-the-correct-way-to-use-ice40-block-ram/
- "tasks" in testbenches https://stackoverflow.com/questions/49929065/verilog-icarus-giving-undefined-values
- gated clocks https://electronics.stackexchange.com/questions/352464/what-does-it-mean-to-gate-the-clock/352470#352470
    ```
    #### START OF CLOCK OPTIMIZATION REPORT #####[

    1 non-gated/non-generated clock tree(s) driving 515 clock pin(s) of sequential element(s)
    1 gated/generated clock tree(s) driving 20 clock pin(s) of sequential element(s)
    54 instances converted, 20 sequential instances remain driven by gated/generated clocks

    ====================================== Non-Gated/Non-Generated Clocks ======================================
    Clock Tree ID     Driving Element                 Drive Element Type              Fanout     Sample Instance
    ------------------------------------------------------------------------------------------------------------
    @K:CKID0002       new_pll_inst.clock_out_keep     clock definition on keepbuf     515        reset_cnt[0]
    ```
- a good amount of info on IPCORE SYNCORE stuff - https://www.microchip.com/content/dam/mchp/documents/FPGA/core-docs/synnplifypro-me/synplify_s202109m/fpga_reference.pdf
- memory usage guide for ice40 https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/MO/MemoryUsageGuideforiCE40Devices.ashx?document_id=47775

- more info on teh specific type of chip in use FM6126A - https://github.com/Galaxy-Man/FM6126-FM6124-LED-DMD
- https://bobdavis321.blogspot.com/2019/02/p3-64x32-hub75e-led-matrix-panels-with.html

- talks about registers, though they aren't numbered the ssame https://github.com/hzeller/rpi-rgb-led-matrix/issues/964
- seems to be like an analysis of registers for fm6126a - https://github.com/ironsheep/P2-HUB75-LED-Matrix-Driver/blob/a8b93c845d56180a9fe05f77ef0ed6c45102709d/driver/isp_hub75_rgb3bit.spin2#L341

- https://community.pixelmatix.com/t/new-p2-1-32-scan-64-64-led-panel-with-different-ic-chip-controller/281/39
- ice40lp family datasheet https://www.latticesemi.com/~/media/LatticeSemi/Documents/DataSheets/iCE/iCE40LPHXFamilyDataSheet.pdf

- RDATA/WDATA pins used in the different SB_RAM40_4K configs - http://bygone.clairexen.net/icestorm/ram_tile.html