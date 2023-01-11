import serial
import sys
import binascii
import time
from typing import IO, Dict, List, Union
BAUDRATE = 2464444

def reset_state(ser: IO[bytes]) -> None:
    ser.write(b" "*64)
    ser.write(b" "*64)
    ser.write(b"9"*64)

def build_raw_row(data: Dict[str, Union[str, int]], padding_amount: int = 0, padding_char: str = " ", override_row_num: int = None) -> bytes:
    output = b""
    if padding_amount != 0:
        output += (padding_char * padding_amount).encode("utf-8")

    if "preargs" in list(data.keys()):
        output += data['preargs'].encode("utf-8")

    output += b"L"
    if "hex" in list(data.keys()):
        if override_row_num is not None:
            row_raw = bytes((override_row_num,))
        else:
            row_raw = bytes((data['row'],))
        # print("row_raw=%s" % row_raw)
        output += row_raw
        d = binascii.unhexlify(data['hex'])
        assert len(d) == 128, "len(d)==%s" % len(d)
        output += d
        # print("d=%s" % d)
    else:
        raise NotImplementedError
    # print("padding_amount=%s" % padding_amount)
    # print("padding=%s" % (padding_char * padding_amount).encode("utf-8"))
    # print("output=%s" % output)
    return output

def replace_last_byte(data: bytes, new_byte: bytes) -> bytes:
    return data[:-1] + new_byte

def main() -> None:
    serial_device = "/dev/ttyAMA0"
    targetfile = "images/blah565.raw"
    f = open(targetfile, 'rb')
    tdata = [
                dict(row=10,
                     hex="3737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313130",
                     preargs="BrG9",
                ),
                dict(row=42,
                     hex="3737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313838373736363535343433333232313138383737363635353434333332323131383837373636353534343333323231313130",
                     preargs="BrG9",
                ),
             ]
    if (len(sys.argv) < 2):
        MAX_ITERATIONS = 0
    else:
        MAX_ITERATIONS = int(sys.argv[1])

    print("len(sys.argv)={argv_length}".format(argv_length=len(sys.argv)))
    ser = serial.Serial(serial_device, BAUDRATE, timeout=None)
    loop_number = 0
    while True:
        d = build_raw_row(tdata[0], padding_amount=0, override_row_num=(loop_number % 32))
        d = replace_last_byte(d, chr((loop_number % 32)).encode("utf-8"))
        #print("ln:%s writing row=%s alldata=%s" % (loop_number, tdata[0]['row'], d))
        ser.write(d)
        loop_number += 1
        if MAX_ITERATIONS != 0:
            if loop_number > MAX_ITERATIONS+2:
                break
        time.sleep(.2)
        #ser.flush()
    print("done")
    ser.close()

if (__name__ == "__main__"):
    main()
