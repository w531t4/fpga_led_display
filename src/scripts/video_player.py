""" Script to display videos over serial port """
from pathlib import Path
from typing import Optional
import serial
import argparse
import time

def main(height: int,
         width: int,
         depth: int,
         source: Path,
         baudrate: int,
         device: Path,
         status_freq: int,
         start_frame: Optional[int] = None,
         ) -> None:
    row_size = width * depth
    ser = serial.Serial(str(device), baudrate)
    frame_count = 0
    start_time = time.time()
    last_print_time = start_time
    with source.open('rb') as f:
        while True:
            if start_frame and isinstance(start_frame, int) and start_frame > 0:
                print(f"seeking to frame {start_frame}, skipping {row_size*start_frame} bytes...")
                f.seek(row_size*start_frame)
            if frame_count > 0:
                if (time.time() - last_print_time) > status_freq:
                    print(f"printing frame={frame_count} "
                        f"frame_rate={frame_count/(time.time()-start_time):.3f} "
                        f"bit_rate={(f.tell()/(time.time()-start_time))/1024:.3f}KBps")
                    last_print_time = time.time()
            for row in range(0, height):
                ser.write(b"L" + bytes([row]) + f.read(row_size))
            frame_count += 1

if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(prog="video_player",
                                     description="i play pixel videos")

    PARSER.add_argument("--height",
                        dest="height",
                        action="store",
                        default=32,
                        type=Path,
                        help="height (in pixels)")
    PARSER.add_argument("--width",
                        dest="width",
                        action="store",
                        default=64,
                        type=int,
                        help="width (in pixels)")
    PARSER.add_argument("--depth",
                        dest="depth",
                        action="store",
                        default=2,
                        type=int,
                        help="depth (in bytes)")
    PARSER.add_argument("-s",
                        "--src",
                        "--source",
                        dest="source",
                        action="store",
                        required=True,
                        type=Path,
                        help="path to source file")
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
    PARSER.add_argument("--start-frame",
                        dest="start_frame",
                        action="store",
                        type=int,
                        help="skip to video frame x")
    PARSER.add_argument("-f",
                        "--status-freq",
                        dest="status_freq",
                        action="store",
                        type=int,
                        default=5,
                        help="display status every x secs")
    ARGS = PARSER.parse_args()

    try:
        main(**vars(ARGS))
    except KeyboardInterrupt:
        pass
