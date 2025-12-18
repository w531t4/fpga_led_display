# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
"""
A wrapper for uart_write_rawdata, to easily test the output of commands.
"""
from uart_write_rawdata import main
import argparse
from pathlib import Path
import sys


if (__name__ == "__main__"):
    PARSER = argparse.ArgumentParser(prog="fpga_cmds",
                                     description="easy command tester")
    PARSER.add_argument("--blank-panel",
                        dest="blank_panel",
                        action="store_true",
                        help="issue blank panel command")
    PARSER.add_argument("--fill-panel",
                        dest="fill_panel",
                        action="store_true",
                        help="issue fill panel command")
    PARSER.add_argument("--fill-rect",
                        dest="fill_rect",
                        action="store_true",
                        help="issue fill rect command")
    PARSER.add_argument("--set-pixel",
                        dest="set_pixel",
                        action="store_true",
                        help="issue set pixel command")
    PARSER.add_argument("--rgb24",
                        dest="use_rgb24",
                        action="store_true",
                        help="use rgb24")
    PARSER.add_argument("--raw",
                        dest="raw",
                        action="store",
                        type=str,
                        help="send raw hex")
    PARSER.add_argument("--set-brightness",
                        nargs=1,
                        dest="set_brightness",
                        action="store",
                        type=int,
                        help="issue set brightness command 0-255")
    PARSER.add_argument("--show-smiley",
                        dest="show_smiley",
                        action="store_true",
                        help="show smiley face")
    ARGS = PARSER.parse_args()
    args = vars(ARGS)

    connectivity_args = {"baudrate": 44444,
                         "device": Path("1,0"),
                         "use_spi": True,
                         }
    instring_args = {"infile": Path(),
                     "convert_from_hex": True}
    instring_args.update(connectivity_args)


    baudrate = 44444
    device = Path("1,0")

    if "blank_panel" in args and args["blank_panel"]:
        if args["use_rgb24"]:
            outstring = "5a"
        else:
            outstring = "5a"
        main(**instring_args,
             instring=outstring)
    elif "fill_panel" in args and args["fill_panel"]:
        if args["use_rgb24"]:
            outstring = "46_314233"
        else:
            outstring = "46_3142"
        main(**instring_args,
             instring=outstring)
    elif "fill_rect" in args and args["fill_rect"]:
        if args["use_rgb24"]:
            outstring = "66_05_0A_10_05_E0A903"
        else:
            outstring = "66_05_0A_10_05_E0A9"
        main(**instring_args,
             instring=outstring)
    elif "set_pixel" in args and args["set_pixel"]:
        if args["use_rgb24"]:
            outstring = "50_08_30_102030"
        else:
            outstring = "50_08_30_1020"
        main(**instring_args,
             instring=outstring)
    elif "set_brightness" in args and args["set_brightness"]:
        if int(args["set_brightness"][0]) > 255 or int(args["set_brightness"][0]) < 0:
            print(f"brightness value={int(args['set_brightness'][0])} is out of bounds. exiting.")
            sys.exit(1)
        main(**instring_args,
             instring="54" + hex(int(args["set_brightness"][0]))[2:].zfill(2))
    elif "show_smiley" in args and args["show_smiley"]:
        if args["use_rgb24"]:
            print("no rgb24 smiley exists")
        else:
            main(**connectivity_args,
                 infile=Path("../../uart/w64_rgb565_smiley.uart"),
                 convert_from_hex=True,
                 instring=None,
                 )
    elif "raw" in args and args["raw"]:
        main(**instring_args,
             instring=args["raw"])
