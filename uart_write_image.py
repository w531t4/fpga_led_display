import serial
from uart_write import reset_state

def main():
    serial_device = "/dev/ttyAMA0"
    targetfile = "../mem/alphabet.mem"
    baudrate=2444444
    ser = serial.Serial(serial_device, baudrate)
    fw = open(targetfile, 'rb').read().split("\n")
    while True:
        current_row = 0
        while current_row < 32:
            ser.write(b"L" + b"".join(fw[(current_row*64):(current_row*64) + 64]))
            current_row += 1
    ser.close()

if (__name__ == "__main__"):
    main()
