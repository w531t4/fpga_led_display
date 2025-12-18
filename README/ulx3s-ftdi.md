<!--
SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
SPDX-License-Identifier: MIT
-->
# Compiling ftx_prog
- `git clone https://github.com/richardeoin/ftx-prog.git`
```
CFLAGS="-I/usr/include/libftdi1" USE_LIBFTDI1=1 make
```
# ftx info
```
~/Documents/Projects/upstream/ftx-prog$ ./ftx_prog --dump

ftx_prog: version 0.4
Modified for the FT-X series by Richard Meadows

Based upon:
ft232r_prog: version 1.23, by Mark Lord.
        Battery Charge Detect (BCD) Enabled = False
        Force Power Enable Signal on CBUS = False
        Deactivate Sleep in Battery Charge Mode = False
        External Oscillator Enabled = False
        External Oscillator Feedback Resistor Enabled = False
        CBUS pin allocated to VBUS Sense Mode = False
        Load Virtual COM Port (VCP) Drivers = True
        Vendor ID (VID) = 0x0403
        Product ID (PID) = 0x6015
        USB Version = USB16.0
        Remote Wakeup by something other than USB = True
        Self Powered = False
        Maximum Current Supported from USB = 500mA
        Pins Pulled Down on USB Suspend = False
        Indicate USB Serial Number Available = True
 FT1248
-------
        FT1248 Clock Polarity = Active Low
        FT1248 Bit Order = MSB to LSB
        FT1248 Flow Control Enabled = False
 RS232
-------
        Invert TXD = False
        Invert RXD = False
        Invert RTS = False
        Invert CTS = False
        Invert DTR = False
        Invert DSR = False
        Invert DCD = False
        Invert RI = False
 RS485
-------
        RS485 Echo Suppression Enabled = False
        DBUS Drive Strength = 4mA
        DBUS Slow Slew Mode = 0
        DBUS Schmitt Trigger = 0
        CBUS Drive Strength = 4mA
        CBUS Slow Slew Mode = 0
        CBUS Schmitt Trigger = 0
        Manufacturer = FER-RADIONA-EMARD
        Product = ULX3S FPGA 85K v3.0.8
        Serial Number = D00723
  I2C
-------
        I2C Slave Address = 0
        I2C Device ID = 0
        I2C Schmitt Triggers Disabled = False
  CBUS
-------
        CBUS0 = TXDEN
        CBUS1 = RxLED
        CBUS2 = TxRxLED
        CBUS3 = SLEEP
        CBUS4 = Tristate
        CBUS5 = Tristate
        CBUS6 = Tristate
No change from existing eeprom contents
```