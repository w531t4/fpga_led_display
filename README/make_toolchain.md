Instructions from https://mjoldfield.com/atelier/2018/02/ice40-toolchain.html

# install dependencies
`yum install libftdi-devel`

# Install icestorm
- `git clone https://github.com/cliffordwolf/icestorm.git icestorm`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make -j12`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make install -j12`

# install arachne-pnr
- `git clone https://github.com/cseed/arachne-pnr.git arachne-pnr`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make -j12`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make install -j12`

# install Yosys
- `git clone https://github.com/cliffordwolf/yosys.git yosys`
- `sudo yum install tcl-devel readline-devel -y`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make -j12`
- `PREFIX=/home/awhite/Documents/Projects/ice40_toolchain make install -j12`