# fpga_led_display
A recipie for having an FPGA drive a 64x32 LED matrix

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