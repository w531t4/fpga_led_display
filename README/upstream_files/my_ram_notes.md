file:///home/awhite/Downloads/MemoryUsageGuideforiCE40Devices%20(7).pdf
https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/MO/MemoryUsageGuideforiCE40Devices.ashx?document_id=47775

EBR - embedded block ram on ice40 are nodes in 4kbit in size -- so 512Bytes each.

attie implementation uses 	4 bits data x 2048bits addressing - 8kbit size each
11 bits (2048) by 4 bits = 8096 bits x 4 modules = 32768 bits == 4KB
12 bits (4096) by 2 bits = 8096 bits x 4 modules = 32768 bits == 4KB

ice40 has
- 256x16     - addr8/data16
- 512x8      - addr9/data8
- 1024x4     - addr10/data4
- 2048x2     - addd11/data2

i'd assume we do 8x 2048x2 = 32kbit.  SB_RAM2048x2
- i think we can keep most of everything, w/ exception of the 12th bit.

ours will be 11 bit address (2048) x 2 bits of data out (2) * 8 modules
each pixel is 16 bits in length ("565) (16x64 = 1024bits per row = 128B/row)
this means it'll take us 128 clocks to pull the top/bottom display from mem
each half display is 128B * 16 = 2KB per 16x32 chunk -- across 4 components is 512Bytes = 2048bits
BLOCK0                          [ Z0, Z0, Z0, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK1                          [ Z0, Z0, Z1, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK2                          [ Z0, Z1, Z0, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK3                          [ Z0, Z1, Z1, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK4                          [ Z1, Z0, Z0, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK5                          [ Z1, Z0, Z1, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK6                          [ Z1, Z1, Z0, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK7                          [ Z1, Z1, Z1, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]

BLOCK0                          [ 0, X  , X  , b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK1                          [ 0, X  , b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK2                          [ 0, b10, X  , b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK3                          [ 0, b10  b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK4                          [ 1, X  , X  , b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK5                          [ 1, X  , b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK6                          [ 1, b10, X  , b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
BLOCK7                          [ 1, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]


DATA [ b15, b14, b13, b12, b11, b10, b09, b08, b07, b06, b05, b04, b03, b02, b01, b00 ]
A
Mod0
Mod1
Mod2
Mod3
Mod4
Mod5
Mod6
Mod7
