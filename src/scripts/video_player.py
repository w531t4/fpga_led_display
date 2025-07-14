from pathlib import Path
from io import BytesIO
import serial
import sys
import time

def main() -> None:
    width = 64
    height = 32
    depth = 2
    frame_size = width*height*depth
    row_size = width * depth
    ser = serial.Serial(str("/dev/ttyAMA3"), 244444)
    frame_count = 0
    start_time = time.time()
    with Path(sys.argv[1]).open('rb') as f:
        while True:
            if frame_count > 0:
                print(f"printing frame={frame_count} frame_rate={(time.time()-start_time)/frame_count:.1f} bit_rate={f.tell()/(time.time()-start_time)}")
            start_time = time.time()
            for row in range(0, height):
                ser.write(b"L" + bytes([row]) + f.read(row_size))
            frame_count += 1

if __name__ == "__main__":
    main()