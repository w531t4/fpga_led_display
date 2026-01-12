<!--
SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->

Add a third buffer

== THIS IS WHY WE NEED A COPY ==
Phase 0) Assume BUFFER_A BUFFER_B AND BUFFER_C are all at state 'a'
Phase 1) ESP32 writing data
FPA -- Read BUFFER_A (front) -- a
|
|------------------ BUFFER_B -- ab
|
|---------- BUFFER_C -- ab

Phase 2) SWAP BUFFER
FPGA -- Read BUFFER_B (front)-- ab
|
|------------------ BUFFER_C -- ab
|
|---------- BUFFER_A -- a

Phase 3) ESP32 writing data
FPGA -- Read BUFFER_B (front)-- ab
|
|------------------ BUFFER_C -- abc
|
|---------- BUFFER_A -- ac

== PROPOSAL ==

Phase 2.1) SWAP BUFFER
FPGA -- Read BUFFER_B (front)-- ab
|
|------------------ BUFFER_C -- ab
|
|---------- BUFFER_A -- a

Phase 2.2) COPY BUFFER_C -> BUFFER_A OVER MUCH FASTER BUS
FPGA -- Read BUFFER_B (front)-- ab
|
|------------------ BUFFER_C -- ab
|
|---------- BUFFER_A -- ab

Phase 3) ESP32 writing data
FPGA -- Read BUFFER_B (front)-- ab
|
|------------------ BUFFER_C -- abc
|
|---------- BUFFER_A -- abc

BUFFER_A, BUFFER_B Dualport ram
port A: - clk: high speed (~90mhz) - Read: Unused - Write: image data
port B: - clk: lower speed (~12mhz) - Read: image data - Write: Unused

==
Phase(0) init (a)
BUFFER_A a
....................BUFFER_B a
....................BUFFER_C []
Phase(1) ESP32 issues write (b)
BUFFER_A a
....................BUFFER_B ab
....................BUFFER_C []
Phase(2) ESP32 issues write (c)
BUFFER_A a
....................BUFFER_B abc
....................BUFFER_C [b,c]
Phase(3.0) Swap Frame
BUFFER_B abc
....................BUFFER_A a
....................BUFFER_C [b,c]
Phase(3.1) Merge differences from BUFFER_C into BUFFER_A
BUFFER_B abc
....................BUFFER_A abc
....................BUFFER_C []
Phase(4) ESP32 issues write (d)
BUFFER_B abc
....................BUFFER_A abcd
....................BUFFER_C [d]

issues: - 1. the clock rate of Port_A is roughly the speed of SPI today.
