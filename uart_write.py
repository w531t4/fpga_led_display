import serial
import sys
from typing import IO
def reset_state(ser: IO[bytes]) -> None:
    ser.write(" "*64)
    ser.write(" "*64)
    ser.write("9"*64)

def main() -> None:
    serial_device = "/dev/ttyAMA0"
    targetfile = "images/blah565.raw"
    chunksize = 128
    f = open(targetfile, 'rb')
    fw = f.read()
    index = 0
    row = 0
    print("len(sys.argv)={argv_length}".format(argv_length=len(sys.argv)))
    if (len(sys.argv) > 1):
        scan = False
        baudrate = int(sys.argv[1])
    else:
        scan = True
        baudrate=2670000
    ser = serial.Serial(serial_device, baudrate)
    iteration = 0
    s = ""
    while baudrate < 2800000:
        if (index >= len(fw)):
            print("iteration={iteration} baudrate={baudrate}".format(iteration=iteration/32,
                                                                     baudrate=baudrate))
            s = "BRG9L"
            index=0
            row=0
        ser.write(s)
        if (scan == True and (iteration % 800 == 0)):
            ser = serial.Serial(serial_device, baudrate)
            baudrate += 100
        s = s+ "L"+chr(int(row)) + fw[index:index+chunksize]
        index += chunksize
        row += 1
        iteration += 1
    ser.close()

if (__name__ == "__main__"):
    main()
