<!--
SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# installing iverilog
- `dnf install iverilog`

# installing gtkwave (for viewing analysis)
- `dnf install gtkwave`


# compiling program
- `iverilog -o sample.vvp sample.v sample_tb.v`

# running the simulation
- `vvp sample.vvp` (which should yield sample.vcd)
- then open sample.vcd in gtkwave
# references
- https://profile.iiita.ac.in/bibhas.ghoshal/lecture_slides_coa/Icarus_Verilog_Tutorial.html