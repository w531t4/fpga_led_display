import serial
from pathlib import Path
import argparse

def main(device: Path,
         baudrate: int,
         infile: Path,
         ):
    ser = serial.Serial(str(device), baudrate)
    ser.write(infile.read_bytes())
    ser.close()

if (__name__ == "__main__"):
    PARSER = argparse.ArgumentParser(prog="uart_write_rawdata",
                                     description="i write uart data to fpga")

    PARSER.add_argument("-b",
                        "--baudrate",
                        dest="baudrate",
                        action="store",
                        default=244444,
                        type=int,
                        help="communications baudrate")
    PARSER.add_argument("-d",
                        "--device",
                        dest="device",
                        action="store",
                        default=Path("/dev/ttyAMA3"),
                        type=Path,
                        help="target serial port device")
    PARSER.add_argument("-i",
                        "--infile",
                        dest="infile",
                        action="store",
                        required=True,
                        type=Path,
                        help="uart file to read")
    # PARSER.add_argument("--debug",
    #                     dest="enable_debug",
    #                     action="store_true",
    #                     help="turn on debug")
    # PARSER.add_argument("--spi",
    #                     dest="use_spi",
    #                     action="store_true",
    #                     help="use spi")
    ARGS = PARSER.parse_args()

    try:
        main(**vars(ARGS))
    except KeyboardInterrupt:
        pass
