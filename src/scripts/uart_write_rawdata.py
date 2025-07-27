import serial
from pathlib import Path
import spidev
import argparse

def main(device: Path,
         baudrate: int,
         infile: Path,
         use_spi: bool,
         convert_from_hex: bool,
         instring: str,
         ):
    if use_spi:
        d, p = str(device).split(",")
        spi = spidev.SpiDev()
        spi.open(int(d), int(p))                 # Use bus 1 (SPI1), device 0 (CE0)
        spi.max_speed_hz = baudrate   # Set speed (10 MHz here)
        spi.mode = 0
    else:
        ser = serial.Serial(str(device), baudrate)

    if instring:
        data_to_write = bytes.fromhex(instring.replace(" ", "").replace("\n", "").replace("_", ""))
    else:
        if convert_from_hex:
            data_to_write = bytes.fromhex(infile.read_text().replace(" ", "").replace("\n", "").replace("_", ""))
        else:
            data_to_write = infile.read_bytes()
    print(f"data_to_write={data_to_write.hex()}")
    if use_spi:
        spi.xfer3(list(data_to_write))
    else:
        ser.write(data_to_write)
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
                        type=Path,
                        help="uart file to read")
    PARSER.add_argument("--instring",
                        dest="instring",
                        action="store",
                        type=str,
                        help="a hex string")
    PARSER.add_argument("--from-hex",
                        dest="convert_from_hex",
                        action="store_true",
                        help="convert infile from hexstring")
    # PARSER.add_argument("--debug",
    #                     dest="enable_debug",
    #                     action="store_true",
    #                     help="turn on debug")
    PARSER.add_argument("--spi",
                        dest="use_spi",
                        action="store_true",
                        help="use spi")
    ARGS = PARSER.parse_args()

    try:
        main(**vars(ARGS))
    except KeyboardInterrupt:
        pass
