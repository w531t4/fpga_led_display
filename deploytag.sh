#!/bin/bash

NAME=$1



#DATE=`date +%s`
#SRC_PATH=/home/awhite/CLionProjects/led_display/fpga/template_Implmnt/sbt/outputs/bitmap
#SRC_FILE=main_bitmap.bin

DEST_PATH=/home/awhite/CLionProjects/led_display/fpga/bitmaps
tinyprog --program ${DEST_PATH}/tag-${NAME}.bin
#cp -f ${SRC_PATH}/${SRC_FILE} ${DEST_PATH}/main-${DATE}.bin
#cp -f ${SRC_PATH}/${SRC_FILE} ${DEST_PATH}/tag-${NAME}.bin




