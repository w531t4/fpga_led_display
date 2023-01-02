# Pinout table

|description            |subdesc   |TinyFPGA BX|HUB75 pin|RPI PIN     |Icecube pin|IC PIN|Waveforms|tempmove|
|-----------------------|----------|-----------|---------|------------|------|---------|--------|
|                       |          |GND        |4,8,16   |6           |
|baudrate_reset         |          |1          |         |            |           |A2
|timeout_word           |          |2          |         |            |           |A1    |
|A row_address_active[0]|rx_data[2]|3          |9        |            |pin3       |B1    |0
|B row_address_active[1]|          |4          |10       |            |pin4       |C2    |1
|C row_address_active[2]|          |5          |11       |            |pin5       |C1    |2
|D row_address_active[3]|          |6          |12       |            |pin6       |D2    |3
|uart rx                |          |7          |         |8 (UART TX) |pin7       |D1    |4
|row latch              |          |8          |14       |            |pin8       |E2    |5
|~output_enable         |          |9          |15       |            |pin9       |E1    |6
|clk_pixel              |          |10         |13       |            |pin10      |G2    |7
|uartclk                |          |11         |         |            |pin11      |H1    |         |14
|Red 1 Rgb1[0]          |          |12         |1        |            |pin12      |J1    |8
|Green 1 Rgb1[1]        |          |13         |2        |            |pin13      |H2    |9
|                       |rx_data[4]|14         |         |            |           |H9    |
|                       |rx_data[5]|15         |         |            |           |D9    |
|                       |rx_data[6]|16         |         |            |           |D8    |
|                       |rx_data[7]|17         |         |            |           |C9    |
|Blue 1 Rgb1[2]         |          |18         |3        |            |pin18      |A9    |10
|Red 2 Rgb2[0]          |          |19         |5        |            |pin19      |B8    |11
|Green 2 Rgb2[1]        |          |20         |6        |            |pin20      |A8    |12
|Blue 2 Rgb2[2]         |          |21         |7        |            |pin21      |B7    |13
|rx_running             |          |22         |         |            |pin22      |A7    |         |15
|out_tx                 |rx_data[0]|23         |         |10 (UART RX)|           |pin23      |B6    |
|rx_invalid             |rx_data[1]|24         |         |            |pin24      |A6    |
|                       |          |3.3v
|                       |          |GND
|                       |          |Vin(5v)

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


