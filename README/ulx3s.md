# Default boot image
- The default image loaded to the board upon delivery starts with D18 Green, and D0 Red, D1 Orange, and D2 yellow-ish.
- It allows fujprog to push programs to the fpga, as well as allows the esp32 to be enumerated/updated via USB1
- This bitstream `https://github.com/emard/ulx3s-bin/blob/master/fpga/dfu/85f-v317/passthru41113043.bit.gz` (after decompression) appears to function identically, except all led's D0-D7 are lit.

