import serial
import time
import sys
serial_device = "/dev/ttyUSB0"
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
    baudrate=2300000
#baudrate=2720000
ser = serial.Serial(serial_device, baudrate)
#ser.write("rGb1 "*1024)
iteration = 0
#s = "L"
s = ""
while baudrate < 2900000:
    #baudrate=2650000
    #    print "baudrate=", baudrate, "row=", row
    #    ser.write("RGB ")
    if (index >= len(fw)):
        print "iteration=", iteration/32, "baudrate=", baudrate
        s = ""
        index=0
        row=0
    if (scan == True and (iteration % 3 == 0)):
        ser = serial.Serial(serial_device, baudrate)
        baudrate += 1000
    #    row_n = bin(int(row))[2:]
    #    if (len(row_n) < 8):
    #        row_n = '0'*(8-len(row_n)) + row_n
    #    l_oper = bin(ord('L'))[2:]
    #    if (len(l_oper) < 8):
    #        l_oper = '0'*(8-len(l_oper)) + l_oper
    #    o = row_n + l_oper
    #    for c in fw[index:index+chunksize]:
    #        n = bin(ord(c))[2:]
    #        if (len(n) < 8):
    #            n = '0'*(8-len(n)) + n
    #        o = n + o
    #    s = "L" +  chr(int(row)) + "A*E0z"*32
    #    s = "L" +  chr(int(row)) + "ABC "*32
    s = "L" +  chr(int(row)) + "BCdE"*32
    #    s = "L"+chr(int(row)) + fw[index:index+chunksize]
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" "*32)
    #    time.sleep(.1)
    ser.write(" "*32)
    ser.write(" "*32)
    ser.write(" RGB9")
    ser.write(" "+ s[0])
    #    print "done printing '           L'"
    #    time.sleep(1)
    ser.write(s[1])
    #    time.sleep(1)
    for each in  s[2:]:
        #        print each, bin(ord(each))
        ser.write(each)
    #        time.sleep(.1)
    #        time.sleep(2)


    #    for each in "L" +  chr(int(row)) + "ABcD"*32:
    #        print "each=", each
    #        ser.write(each)
    #        time.sleep(.5)
    #    total = o + total
    index += chunksize
    row += 1
    iteration += 1
ser.close()

