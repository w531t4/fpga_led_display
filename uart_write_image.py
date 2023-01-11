import serial
from uart_write import reset_state

def main():
    serial_device = "/dev/ttyAMA0"
    targetfile = "../uart/alphabet.uart"
    baudrate=2444444
    ser = serial.Serial(serial_device, baudrate)
    fw = open(targetfile, 'rb').read()
    ser.write(fw)
    ser.close()

if (__name__ == "__main__"):
    main()
