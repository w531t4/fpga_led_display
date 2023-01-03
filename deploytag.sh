#!/bin/bash

NAME="$(/home/awhite/Documents/Projects/fpga_led_display/maketag.sh)"
ssh fpga "mkdir -p /root/bitmaps"
scp ${NAME} fpga:/root/bitmaps
BASE=$(basename ${NAME})
ssh fpga "/root/venv/bin/tinyprog --program /root/bitmaps/${BASE}"

