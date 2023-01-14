# Pinout table

|description            |new      |subdesc   |TinyFPGA BX|newhub75 |HUB75 pin|RPI PIN     |USB UART  |Icecube pin|IC PIN|new wf   |Waveforms|tempmove|
|-----------------------|---------|----------|-----------|---------|---------|------------|----------|-----------|------|---------|---------|--------|
|                       |gnd      |          |GND        |16       |4,8,16   |6           |          |           |      |         |         |        |
|baudrate_reset         |clk_pixel|          |1          |13       |         |            |          |           |A2    |2        |
|timeout_word           |row latch|          |2          |14       |         |            |          |           |A1    |3        |
|A row_address_active[0]|~oe      |rx_data[2]|3          |15       |9        |            |          |pin3       |B1    |1        |4
|B row_address_active[1]|RAA[0]   |          |4          |9        |10       |            |          |pin4       |C2    |4        |5
|C row_address_active[2]|RAA[1]   |          |5          |10       |11       |            |          |pin5       |C1    |5        |6
|D row_address_active[3]|RAA[2]   |          |6          |11       |12       |            |          |pin6       |D2    |6        |7
|uart rx                |RAA[3]   |          |7          |12       |         |            |          |pin7       |D1    |7        |13
|row latch              |RGB1[0]  |          |8          |1        |14       |            |          |pin8       |E2    |0        |3
|~output_enable         |RGB1[1]  |          |9          |2        |15       |            |          |pin9       |E1    |8        |1
|clk_pixel              |RGB1[2]  |          |10         |3        |13       |            |          |pin10      |G2    |9        |2
|uartclk                |         |          |11         |         |         |            |          |pin11      |H1    |undef    |14         |14
|Red 1 Rgb1[0]          |undef    |          |12         |undef    |1        |            |          |pin12      |J1    |undef    |0
|Green 1 Rgb1[1]        |undef    |          |13         |undef    |2        |            |          |           |H2    |undef    |8
|                       |         |rx_data[4]|14         |         |         |            |          |           |H9    |         |
|                       |         |rx_data[5]|15         |         |         |            |          |           |D9    |         |
|                       |         |rx_data[6]|16         |         |         |            |          |           |D8    |         |
|                       |         |rx_data[7]|17         |         |         |            |          |           |C9    |         |
|Blue 1 Rgb1[2]         |undef    |          |18         |undef    |3        |            |          |pin18      |A9    |undef    |9
|Red 2 Rgb2[0]          |         |          |19         |         |5        |            |          |pin19      |B8    |         |10
|Green 2 Rgb2[1]        |         |          |20         |         |6        |            |          |pin20      |A8    |         |11
|Blue 2 Rgb2[2]         |         |          |21         |         |7        |            |          |pin21      |B7    |         |12
|rx_running             |uart rx  |          |22         |undef    |         |8 (UART TX) |          |pin22      |A7    |undef    |15          |15
|out_tx                 |         |rx_data[0]|23         |         |         |            |RX        |pin23      |B6    |         |
|rx_invalid             |         |rx_data[1]|24         |         |         |            |TX        |pin24      |A6    |         |
|                       |         |          |3.3v         |
|                       |         |          |GND         |
|                       |         |          |Vin(5v)         |
         |
unassigned waveforms - pin13, pin14, pin15,
- rx_data is an effort to expose what is being received at the fpga on its uart_rx pin (7)

# HUB75
```
   !   P   R   R    B   R   B   R
   O   X   W   W    L   D   L   D
   E   C   2   0    2   2   1   1
|----------------   --------------|
|  15  13  11   9   7   5   3   1 |
|  16  14  12  10   8   6   4   2 |
|---------------------------------|
   G   R   R   R    G   G   G   G
   N   W   W   W    N   N   N   N
   D   L   3   1    D   2   D   1
```

# raspberry pi

```
|--------------------------------------------------------------------------------|
|                                                                                |
|   2  4  6  8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40                   |
|   1  3  5  7  9 11 13 15 17 19 21 23 25 27 29 31 33 35 37 39                   |
|                                                                                |
|                                                                                |
|                                                                                |
|S                                                                              |
|D                                                                               |
|C                                                                               |
|A                                                                               |
|R                                                                               |
|D                                                                               |
....                                                                             |
|--------------------------------------------------------------------------------|
```

# references
- Attie has a way better diagram of HUB75 layour here https://github.com/attie/led_matrix_tinyfpga_a2/blob/master/doc/rgb_led_matrix_pinout.svg

- raspberry pi pinout - https://pinout.xyz/


