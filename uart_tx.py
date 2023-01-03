#!/usr/bin/python
import serial
import time
import sys
def reset_state(ser):
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" "*32)
    #	time.sleep(.1)
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" RGB9")
def main():

    #	serial_device = "/dev/ttyUSB0"
    serial_device = "/dev/ttyAMA0"
    targetfile = "images/blah565.raw"
    chunksize = 128
    f = open(targetfile, 'rb')
    fw = f.read()
    index = 0
    row = 0
    total = ""
    #baudrate=2620000
    print "len(sys.argv)=", len(sys.argv)
    if (len(sys.argv) > 1):
        scan = False
        baudrate = int(sys.argv[1])
    else:
        scan = True
        baudrate=2300000
    ser = serial.Serial(serial_device, baudrate)
    iteration = 0
    s = ""
    reset_state(ser)
    reset_state(ser)
    while baudrate < 2900000:
        #baudrate=2650000
        #	print "baudrate=", baudrate, "row=", row
        #	ser.write("RGB ")
        if (index >= len(fw)):
            print "iteration=", iteration/32, "baudrate=", baudrate
            time.sleep(.0001)
            reset_state(ser)
            ser.write(s)
            s = ""
            index=0
            row=0
        if (scan == True and (iteration % 10 == 0)):
            ser = serial.Serial(serial_device, baudrate)
            baudrate += 500
        #           s = "L" +  chr(int(row)) + "ABCD"*32
        #	    s = "L"+chr(int(row)) + fw[index:index+chunksize]
        s = s + "L"+chr(int(row)) + fw[index:index+chunksize]

        #	    reset_state(ser)
        #	    ser.write(" "+ s[0])
        #	    ser.write(s[1])

        #	    for each in  s[2:]:
        #		print each, bin(ord(each))
        #	        ser.write(each)
        #		time.sleep(.0001)
        #	    ser.write(s[2:])
        index += chunksize
        row += 1
        iteration += 1
    ser.close()

if (__name__ == "__main__"):
    main()
