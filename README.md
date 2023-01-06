# fpga_led_display
A recipie for having an FPGA drive a 64x32 LED matrix

# interacting with Tiny FPGA BX via USB
Note: Following instructions from https://tinyfpga.com/bx/guide.html

- `yum install python35 python3-virtualenv -y` # rpi running way old fedberry image
- `virtualenv-3 venv`
- `. venv/bin/activate`
- `pip install tinyprog`

# visualizing verilog
Based on suggestion from https://stackoverflow.com/questions/67923728/yosys-producing-an-electronic-schematics-from-verilog
- install node
- `dnf install python3-nodeenv`
- `nodeenv --verbose nenv` (or) `nodenv --prebuilt nenv`
- `npm install -g netlistsvg`
- use json file from yosys to produce results (see Makefile)


# helpful references
- https://zipcpu.com/blog/2017/06/02/generating-timing.html


# things i'd like to look at
- https://www.youtube.com/watch?v=BcJ6UdDx1vg
- https://www.youtube.com/watch?v=P8MpZGjwgR0
- https://youtu.be/wwANKw36Mjw
- https://youtu.be/xlvqUts9H9c
- https://www.tutorialspoint.com/compile_verilog_online.php (helpful for testing snippets of verilog)
- https://zipcpu.com/fpga-hell.html