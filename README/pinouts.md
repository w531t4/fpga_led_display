<!--
SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->

# Pinout table

| description | Optional/Required | ULXS3               | RPI5                | HUB75 pin     | USB UART | notes              |
| ----------- | ----------------- | ------------------- | ------------------- | ------------- | -------- | ------------------ |
| gnd         | Required          |                     |                     | 16            |          |                    |
| clk_pixel   | Required          | GP11                |                     | 13            |          |                    |
| row latch   | Required          | GP12                |                     | 14            |          |                    |
| ~oe         | Required          | GP13                |                     | 15            |          |                    |
| RAA[3:0]    | Required          | GP10, GP9, GP8, GP7 |                     | 12, 11, 10, 9 |          |                    |
| RGB1[2:0]   | Required          | GP2, GP1, GP0       |                     | 3, 2, 1       |          |                    |
| RGB2[2:0]   | Required          | GP5, GP4, GP3       |                     | 7, 6, 5       |          |                    |
| debug_txout |                   | GP16                | UART2 GPIO5 #29     |               | RX       | -DDEBUGGER         |
| debug_rxin  |                   | GP15                | UART2 GPIO4 #7      |               | TX       | -DDEBUGGER         |
| uart rx     |                   | GP14                | UART3 GPIO8 #24     |               |          | -USPI -USPI_ESP32  |
| MISO        |                   | GN17                | SPI1 GPIO19 MISO#35 |               |          | -DSPI -UDSPI_ESP32 |
| MOSI        |                   | GN18                | SPI1 GPIO20 MOSI#38 |               |          | -DSPI -UDSPI_ESP32 |
| SCLK        |                   | GN19                | SPI1 GPIO21 SCLK#40 |               |          | -DSPI -UDSPI_ESP32 |
| CS          |                   | GN20                | SPI1 GPIO18 CE0 #12 |               |          | -DSPI -UDSPI_ESP32 |

# HUB75

```
   !   P   R   R    B   R   B   R
   O   X   W   W    L   D   L   D
   E   C   2   0    2   2   1   1
|----------------   --------------|
|  15  13  11   9   7   5   3   1 | (image shows male hub75 socket on 64x32 board)
|  16  14  12  10   8   6   4   2 |
|---------------------------------|
   G   R   R   R    G   G   G   G
   N   W   W   W    N   N   N   N
   D   L   3   1    D   2   D   1
```

Attie has a way better diagram of HUB75 layout here https://github.com/attie/led_matrix_tinyfpga_a2/blob/master/doc/rgb_led_matrix_pinout.svg

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

https://pinout.xyz/

# New SPI Wiring (HSPI)

This combination of ESP32 pins are capable of transmit-only at 80mhz

| signal | ULX3S net           | ESP32  |
| ------ | ------------------- | ------ |
| SCLK   | sd_clk              | gpio14 |
| MOSI   | sd_d[3]/wifi_gpio13 | gpio13 |
| CS/CE  | wifi_gpio21         | gpio21 |

# Previous SPI Wiring

This combination of ESP32 pins are capable of transmit-only at 80mhz

| signal | ULX3S net | ESP32  | notes              |
| ------ | --------- | ------ | ------------------ |
| SCLK   | sd_clk    | gpio14 |                    |
| MOSI   | sd_d[0]   | gpio2  | esp32 strap-up pin |
| CS/CE  | sd_cmd    | gpio15 | esp32 strap-up pin |

# Wiring for an alternate, low-speed SPI config

| signal    | ULX3S net   | ESP32  | notes            |
| --------- | ----------- | ------ | ---------------- |
| SCLK      | wifi_gpio22 | gpio22 |                  |
| MOSI      | wifi_gpio25 | gpio25 |                  |
| CS/CE     | wifi_gpio26 | gpio26 |                  |
| MISO      | wifi_gpio35 | gpio35 | esp32 input only |
| MISO(alt) | wifi_gpio27 | gpio27 | esp32 bi-dir     |

# Alternate ULX3s <=> ESP32 IO

| ULX3S net   | ESP32  | notes        |
| ----------- | ------ | ------------ |
| wifi_gpio19 | gpio19 | esp32 bi-dir |

# references

-   raspberry pi pinout -

# pi5

For example, UART1 can be enabled on GPIO pins 0 & 1.
UART2 on GPIO pins 4 & 5.
UART3 on GPIO pins 8 & 9.
UART4 on GPIO pins 12 & 13.
