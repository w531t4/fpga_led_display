#!/bin/bash

NAME=$1

DATE=`date +%s`
BASE_PATH=/home/awhite/Documents/Projects/fpga_led_display
SRC_PATH=${BASE_PATH}/template_Implmnt/sbt/outputs/bitmap
SRC_FILE=main_bitmap.bin

DEST_PATH=${BASE_PATH}/bitmaps

if [ "x$1" == "x" ]; then
    cp -f ${SRC_PATH}/${SRC_FILE} ${DEST_PATH}/${DATE}-main.bin
    echo "${DEST_PATH}/${DATE}-main.bin"
else
    cp -f ${SRC_PATH}/${SRC_FILE} ${DEST_PATH}/${DATE}-${NAME}-main.bin
    echo "${DEST_PATH}/${DATE}-${NAME}-main.bin"
fi
