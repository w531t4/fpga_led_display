#!/usr/bin/python
import serial
import time
import sys
def reset_state(ser):
    ser.write(" "*64)
#    time.sleep(.2)
    ser.write(" "*64)
#    time.sleep(.2)
    ser.write("9"*64)
#    time.sleep(.5)
#    ser.write("R")
#    time.sleep(.5)
#    ser.write("G")
#    time.sleep(.5)
#    ser.write("B")
#    time.sleep(.5)
#    ser.write("2")
#    time.sleep(1)
def main():

#	serial_device = "/dev/ttyUSB0"
	serial_device = "/dev/ttyAMA0"
	targetfile = "blah565.raw"
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
	    baudrate=2670000
	ser = serial.Serial(serial_device, baudrate)
	iteration = 0
	s = ""
#        reset_state(ser)
#        reset_state(ser)
	while baudrate < 2800000:
	    #baudrate=2650000
	    #	print "baudrate=", baudrate, "row=", row
	    #	ser.write("RGB ")
	    if (index >= len(fw)):
	        print "iteration=", iteration/32, "baudrate=", baudrate
#		reset_state(ser)
		ser.write(s)
		#time.sleep(0.5) # note - 0.5 was in mainroom py file, 1 was in myroom file
#		time.sleep(1)
	        s = "BRG9L"
	        index=0
	        row=0
	    if (scan == True and (iteration % 800 == 0)):
	        ser = serial.Serial(serial_device, baudrate)
	        baudrate += 100
#	    s = "L" +  chr(int(row)) + "ABCD"*32
#	    reset_state(ser)
	    s = s+ "L"+chr(int(row)) + fw[index:index+chunksize]
#	    s = s + "rgB1L"+chr(int(row)) + fw[index:index+chunksize] + "      "

#	    for each in  s[2:]:
#		print "ord(each)=" + str(ord(each)) + " ", each
#	        ser.write(each)
#		time.sleep(2)
#	    ser.write(s)
	    index += chunksize
	    row += 1
	    iteration += 1
	ser.close()

if (__name__ == "__main__"):
	main()
