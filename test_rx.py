import serial
import time
BAUDRATE=115200
def main():
#    serial_device = "/dev/ttyAMA0"
    serial_device = "/dev/ttyUSB0"
    baudrate=BAUDRATE
    ser = serial.Serial(serial_device, baudrate, timeout=None)
    expected_bitsize = 192
    expected_bytes = 0
    while True:
        bytestring = ""
        binstring = ""
        hexstring = ""
        if ((expected_bitsize % 8) == 0):
                expected_bytes = expected_bitsize/8
        else:
                expected_bytes = expected_bitsize/8 + 1
        while (len(bytestring) < expected_bytes):
                bytestring = ser.read_until()
#                hexstring = ""
 #               binstring = ""
                for each in bytestring:
                        hexstring = hexstring + format(ord(each), '02x')
                        binstring = binstring + format(ord(each), '08b')
		print hexstring + " " + str(len(binstring))

	if len(binstring) != expected_bitsize:
		continue
	else:
		print hexstring, " blah"
main()
