1. `git clone --depth=1 --branch rpi-6.6.y https://github.com/raspberrypi/linux linux-pi5`
- get overlay from https://forums.raspberrypi.com/viewtopic.php?t=361321
1. `cc -x assembler-with-cpp -E uart-speed-overlay.dts -o temp -I linux-pi5/include`
1. `dtc temp -o uart-speed.dtbo`

1.`sudo cp uart-speed.dtbo /boot/firmware/overlays/`

- verify changes by looking at `cat cat /sys/kernel/debug/clk/clk_summary`


# Enabling SPI on RPI5
1. add the following `dtoverlay=spi1-3cs` to `/boot/firmware/config.txt`
