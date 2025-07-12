import serial
from uart_write import reset_state
import sys

def main():
    serial_device = "/dev/ttyAMA3"
    if len(sys.argv) == 1:
        targetfile = "../../uart/alphabet.uart"
    else:
        targetfile = "%s" % sys.argv[1]
    baudrate=244444
    ser = serial.Serial(serial_device, baudrate)
    fw = open(targetfile, 'rb').read()
    ser.write(fw)
    ser.close()

if (__name__ == "__main__"):
    main()
