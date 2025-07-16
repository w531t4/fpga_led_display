1. `git clone --depth=1 --branch rpi-6.6.y https://github.com/raspberrypi/linux linux-pi5`
- get overlay from https://forums.raspberrypi.com/viewtopic.php?t=361321
1. `cc -x assembler-with-cpp -E uart-speed-overlay.dts -o temp -I linux-pi5/include`
1. `dtc temp -o uart-speed.dtbo`

1. place in /boot/firmware/overlays/