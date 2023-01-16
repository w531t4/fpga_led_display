# Pinout table

|description  |TinyFPGA BX|HUB75 pin|RPI PIN    |USB UART|Adafruit Hat|Icecube pin|IC PIN|Waveforms|
|-------------|-----------|---------|-----------|--------|------------|-----------|------|---------|
|gnd          |GND        |16       |6          |        |            |           |      |         |
|clk_pixel    |1          |13       |           |        |GPIO#17     |pin1       |A2    |2        |
|row latch    |2          |14       |           |        |GPIO#21     |pin2       |A1    |3        |
|~oe          |3          |15       |           |        |GPIO#04     |pin3       |B1    |1        |
|RAA[0]       |4          |9        |           |        |GPIO#22     |pin4       |C2    |4        |
|RAA[1]       |5          |10       |           |        |GPIO#26     |pin5       |C1    |5        |
|RAA[2]       |6          |11       |           |        |GPIO#27     |pin6       |D2    |6        |
|RAA[3]       |7          |12       |           |        |GPIO#20     |pin7       |D1    |7        |
|RGB1[0]      |8          |1        |           |        |GPIO#05     |pin8       |E2    |0        |
|RGB1[1]      |9          |2        |           |        |GPIO#06     |pin9       |E1    |8        |
|RGB1[2]      |10         |3        |           |        |GPIO#13     |pin10      |G2    |9        |
|DEAD         |11         |5        |           |        |            |pin11      |H1    |10       |
|DEAD         |12         |6        |           |        |            |pin12      |J1    |undef    |
|RGB2[2]      |13         |7        |           |        |GPIO#16     |           |H2    |undef    |
|             |14         |         |           |        |            |           |H9    |         |
|             |15         |         |           |        |            |           |D9    |         |
|             |16         |         |           |        |            |           |D8    |         |
|             |17         |         |           |        |            |           |C9    |         |
|undef        |18         |undef    |           |        |            |pin18      |A9    |13       |
|RGB2[0]      |19         |undef    |           |        |GPIO#12     |pin19      |B8    |11       |
|RGB2[1]      |20         |undef    |           |        |GPIO#23     |pin20      |A8    |12       |
|undef        |21         |undef    |           |        |            |pin21      |B7    |undef    |
|uart rx      |22         |undef    |8 (UART TX)|        |            |pin22      |A7    |undef    |
|debug_txout  |23         |         |           |RX      |            |pin23      |B6    |         |
|debug_rxin   |24         |         |           |TX      |            |pin24      |A6    |         |
|             |3.3v       |                              |3.3v
|             |GND        |                              |GND
|             |Vin(5v)    |                              |5v
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


