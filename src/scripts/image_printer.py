from pathlib import Path
from io import BytesIO
from typing import List, Dict, Self
import re
import argparse
import sys

import serial


class UARTImage():
    """Handles emitting data in a format the FPGA understands"""
    def __init__(self, width: int, height: int, depth: int, data: bytes) -> None:
        assert height < 256, "only one byte is used to convey row information, thus max 255"
        self.width = width
        self.height = height
        self.depth = depth
        self.data = data
        dim_size = self.height * self.width * self.depth
        assert len(self.data) == dim_size, f"len(self.data)={len(self.data)} dim_size={dim_size}"
        self._position = 0

    def transform_middle(self, width) -> Self:
        assert width > self.width
        difference_side = (width - self.width)/2
        new_data = BytesIO()
        me = BytesIO(self.data)
        for _ in range(0, self.height+1):
            temp = me.read(self.width*self.depth)
            new_data.write(b'0'*difference_side)
            new_data.write(temp)
            new_data.write(b'0'*difference_side)
        return self.__class__(width=width,
                              height=self.height,
                              depth=self.depth,
                              data=new_data.getvalue())

    @classmethod
    def from_uartfile(cls, path: Path, width: int, height: int, depth: int) -> Self:
        data = BytesIO(path.read_bytes())
        data.seek(0)
        to_save = BytesIO()
        for _ in range(0, height+1):
            # print(f"moving from {data.tell()} to {data.tell()+2}")
            data.seek(data.tell()+2)
            # for _ in range(0, width+1):
            # print(f"reading size={depth*width} from file")
            to_save.write(data.read(depth*width))
            # print(f"data.tell={data.tell()}")
        return cls(width=width, height=height, depth=depth, data=to_save.getvalue())

    @staticmethod
    def encode_row(row: int) -> bytes:
        return bytes((row,))

    def assemble(self) -> bytes:
        data = BytesIO()
        data.write(b"L")
        mydata = BytesIO(self.data)
        for row in range(0, self.height + 1):
            data.write(self.encode_row(row))
            # for _ in range(0, self.width + 1):
            data.write(mydata.read(self.width*self.depth))
        return data.getvalue()

    def render(self, device: Path, baudrate: int) -> None:
        ser = serial.Serial(device, baudrate)
        ser.write(self.assemble())
        ser.close()

def main(target: str,
         target_freq: int,
         source: Path,
         target_width: int,
         target_height: int,
         source_width: int = None,
         source_height: int = None,
         source_depth: int = None,
         ) -> None:
    obj = None
    if source and source.suffix == ".uart":
        if not all(map(lambda x: x is not None, [source_width, source_height, source_depth])):
            print("must provide source_width, source_height, source_depth when using .uart as source")
            sys.exit(1)
        obj = UARTImage.from_uartfile(path=source, width=source_width, height=source_height, depth=source_depth)
    if obj:
        if target_width != source_width:
            obj = obj.transform_middle(width=target_width)
        obj.render(device=target, baudrate=target_freq)
    print("done")


if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(prog="image_printer",
                                     description="i print images")

    PARSER.add_argument("--src",
                        "-s",
                        dest="source",
                        action="store",
                        type=Path,
                        help="Path to source file")
    PARSER.add_argument("--src-width",
                        dest="source_width",
                        action="store",
                        type=int,
                        help="width of source file")
    PARSER.add_argument("--src-height",
                        dest="source_height",
                        action="store",
                        type=int,
                        help="height of source file")
    PARSER.add_argument("--src-depth",
                        dest="source_depth",
                        action="store",
                        type=int,
                        help="depth of source file")
    PARSER.add_argument("--target",
                        dest="target",
                        action="store",
                        type=str,
                        help="uart device path")
    PARSER.add_argument("--target-freq",
                        dest="target_freq",
                        action="store",
                        default=244444,
                        type=int,
                        help="uart tx freq")
    PARSER.add_argument("--target-width",
                        dest="target_width",
                        action="store",
                        default=64,
                        type=int,
                        help="width in pixels")
    PARSER.add_argument("--target-height",
                        dest="target_height",
                        action="store",
                        default=32,
                        type=int,
                        help="height in pixels")
    ARGS = PARSER.parse_args()

    main(**vars(ARGS))
