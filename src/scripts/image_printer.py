from pathlib import Path
from io import BytesIO
from typing import List, Dict, Self, Optional
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
        difference_side = int((width - self.width)/2)
        assert width == (self.width + (difference_side * 2))
        new_data = BytesIO()
        me = BytesIO(self.data)
        for _ in range(0, self.height):
            # print(f"read orig_row = {self.width*self.depth}")
            temp = me.read(self.width*self.depth)
            # print(f"add half side = {len(b'0'*difference_side*self.depth)}")
            new_data.write(b'\x00'*difference_side*self.depth)
            new_data.write(temp)
            # print(f"add half side = {len(b'0'*difference_side*self.depth)}")
            new_data.write(b'\x00'*difference_side*self.depth)
        return self.__class__(width=width,
                              height=self.height,
                              depth=self.depth,
                              data=new_data.getvalue())

    def transform_duplicate(self, width) -> Self:
        new_data = BytesIO()
        me = BytesIO(self.data)
        for _ in range(0, self.height):
            # print(f"read orig_row = {self.width*self.depth}")
            temp = me.read(self.width*self.depth)
            # print(f"add half side = {len(b'0'*difference_side*self.depth)}")
            new_data.write(temp)
            new_data.write(temp)
        return self.__class__(width=width,
                              height=self.height,
                              depth=self.depth,
                              data=new_data.getvalue())

    @classmethod
    def from_uartfile(cls, path: Path, width: int, height: int, depth: int) -> Self:
        data = BytesIO(path.read_bytes())
        data.seek(0)
        to_save = BytesIO()
        for i in range(0, height):
            context = data.read(2)
            # print(f"skipping load/row data={context}")
            data_read = data.read(depth*width)
            # print(f"read_data row={i} data={data_read}")
            to_save.write(data_read)
        return cls(width=width, height=height, depth=depth, data=to_save.getvalue())

    @staticmethod
    def encode_row(row: int) -> bytes:
        return bytes((row,))

    def assemble(self) -> bytes:
        data = BytesIO()
        mydata = BytesIO(self.data)
        for row in range(0, self.height):
            data.write(b"L")
            data.write(self.encode_row(row))
            # for _ in range(0, self.width + 1):
            data.write(mydata.read(self.width*self.depth))
        return data.getvalue()

    def assemble_row(self, row_num: int) -> bytes:
        """
        @row_num: base0 row#
        """
        out = BytesIO()
        out.write(b"L")
        out.write(self.encode_row(row_num))
        data = BytesIO(self.data)
        data.seek(self.width*row_num*self.depth)
        out.write(data.read(self.width*self.depth))
        return out.getvalue()

    def render(self, device: Path, baudrate: int) -> None:
        ser = serial.Serial(str(device), baudrate)
        data = self.assemble()
        print(f"writing count={len(data)} bytes to {device} at baud={baudrate}")
        # Path("uart/alphabet128_middle.uart").write_bytes(data)
        ser.write(data)
        ser.close()

    def render_row(self, row_num: int, device: Path, baudrate: int) -> None:
        ser = serial.Serial(str(device), baudrate)
        data = self.assemble_row(row_num)
        ser.write(data)
        print(f"render row#{row_num} data={data}")
        ser.close()

def main(target: Path,
         target_freq: int,
         source: Path,
         target_width: int,
         target_height: int,
         transform_type: Optional[str] = None,
         only_row: Optional[int] = None,
         source_width: Optional[int] = None,
         source_height: Optional[int] = None,
         source_depth: Optional[int] = None,
         ) -> None:
    obj = None
    if source and source.suffix == ".uart":
        if not all(map(lambda x: x is not None, [source_width, source_height, source_depth])):
            print("must provide source_width, source_height, source_depth when using .uart as source")
            sys.exit(1)
        obj = UARTImage.from_uartfile(path=source, width=source_width, height=source_height, depth=source_depth)
    if obj:
        if target_width and target_width != source_width:
            print("transforming!")
            if transform_type == "duplicate":
                obj = obj.transform_duplicate(width=target_width)
            elif transform_type == "middle":
                obj = obj.transform_middle(width=target_width)
            else:
                obj = obj.transform_duplicate(width=target_width)
        if only_row:
            obj.render_row(only_row, device=target, baudrate=target_freq)
        else:
            obj.render(device=target, baudrate=target_freq)
        # for i in range(0, 32):
        #     obj.render_row(row_num=i, device=target, baudrate=target_freq)
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
                        type=Path,
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
    PARSER.add_argument("--transform-type",
                        dest="transform_type",
                        action="store",
                        default="duplicate",
                        choices=["middle", "duplicate"],
                        help="transform mechanism to use")
    PARSER.add_argument("--only-row",
                        dest="only_row",
                        action="store",
                        type=int,
                        help="only emit row x")
    ARGS = PARSER.parse_args()

    main(**vars(ARGS))
