import argparse
from typing import List, Dict, Union, NamedTuple, Union
from functools import partial
from pathlib import Path
from typing import IO, TextIO
from io import StringIO
import sys

from curses import wrapper
import serial
import spidev

class BaudContext(NamedTuple):
    state: int
    rate: int

class DataFetch(NamedTuple):
    bytestring: bytes
    binstring: str
    hexstring: str

def gen_bitstring(c: str) -> str:
    """ translate character into string represents its bits
    @c: single character
    ret: string equivalent of character containing only 1's and 0's "10001100"
    """
    r_int = ord(c)
    if len(bin(r_int)[2:]) < 8:
        bitstring = '0'*(8-len(bin(r_int)[2:])) + bin(r_int)[2:]
    else:
        bitstring = bin(r_int)[2:]
    return bitstring

def get_hexstring(bitstring: str, raw: bool = True) -> str:
    """ Generate a hexidecimal representation of bitstring
    @bitstring: python string containing only 1's and 0's (see gen_bitstring())
    @raw: toggle adding 0x to front of output
    """
    retstring = ""
    for each in [bitstring[i:i+4] for i in range(0, len(bitstring), 4)]:
        retstring += hex(int(each,2))[2:]
    if raw:
        return retstring
    else:
        return f"0x{retstring}"

def get_safe_string(c: str) -> str:
    """Given a string, produce an equivalent containing only the printable characters
    @c: string of any length
    """
    d = ""
    for each in c:
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d += each
        else:
            d += "*"
    return d

def reverse_bits_char(c: str) -> str:
    """Given a single character, reverse the bits and produce the ascii equivalent of the result
    @c: single character
    """
    a = gen_bitstring(c)[::-1]
    return chr(int(a,2))

def get_safe_string_rev(c: str) -> str:
    """Given a string, produce an equivalent containing only the printable characters, and reverse the bits of the character
    @c: string of any length
    """
    d = ""
    for each in c:
        each = reverse_bits_char(each)
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d += each
        else:
            d += "*"
    return d

def do_debug(c: str, title: str = "", titlelength: int = 24) -> str:
    """ Processes single component of debug structure
    @titlelength: add rhs padding to title of component being processed to normalize output"""
    def wrap_data(data: str) -> str:
        """ helper to wrap text in sane formatting structure"""
        return '{0: <%s}' % str(data)
    binstring = ""
    for each in c:
        binstring += gen_bitstring(each)
    hexrep = get_hexstring(binstring, raw=False)
    r_c = ""
    s = binstring
    for each in [s[i:i+8] for i in range(0, len(s), 8)]:
        if (int(each,2) > 256):
            r_c += "X"
        else:
            r_c += chr(int(each,2))
    rstring = (f"{wrap_data(str(titlelength)).format(title)}"
               f"{wrap_data(str(4+16)).format(f'0b{binstring}')}"
               f"{wrap_data(str(4+4)).format(hexrep)}"
               f"{wrap_data(str(2)).format(get_safe_string(c))}"
               f" rchr="
               f"{wrap_data(str(2)).format(get_safe_string_rev(c))}"
               )
    return rstring

def writeser(ser: IO[bytes], s: str, spi: bool = False) -> None:
    if spi:
        send_spi_bytes(s.encode("utf-8"))
    else:
        for each in s:
            ser.write(each.encode("utf-8"))

def send_spi_bytes(data: bytes) -> None:
    """ Send bytestream to SPI hardcoded target (device, port, rate)"""
    spi_dev = 1
    spi_port = 0
    spi_rate = 40000
    dev = spidev.SpiDev()
    dev.open(spi_dev, spi_port)                 # Use bus 1 (SPI1), device 0 (CE0)
    dev.max_speed_hz = spi_rate   # Set speed (10 MHz here)
    dev.mode = 0
    dev.xfer3(list(data))
    dev.close()

def testval(dev: Path, baud: int, val: str, spi: bool = False) -> None:
    if spi:
        send_spi_bytes(val.encode("utf-8"))
    else:
        ser_data = serial.Serial(str(dev), baud, timeout=None)
        ser_data.write(val.encode("utf-8"))
        ser_data.close()

def findbaud(stdscr, curval: str, cur_context: BaudContext, max_lines: int, max_baudrate: int, baudrate_increment: int) -> BaudContext:
    BAUDSET_DATA_STATE, BAUDSET_DATA = cur_context.state, cur_context.rate
    stdscr.addstr(max_lines+2,0, f"DATA_TX:BAUD:{str(BAUDSET_DATA)} STATE:{str(BAUDSET_DATA_STATE)}")
    if BAUDSET_DATA_STATE == 0 and curval == "A":
        BAUDSET_DATA_STATE = 1
    elif BAUDSET_DATA_STATE == 1 and curval == "-":
        BAUDSET_DATA_STATE = 2
    elif BAUDSET_DATA_STATE == 2 and curval == "C":
        BAUDSET_DATA_STATE = -1
    else:
        if BAUDSET_DATA > max_baudrate:
            BAUDSET_DATA_STATE = -1
        else:
            BAUDSET_DATA_STATE = 0
            BAUDSET_DATA += baudrate_increment
    return BaudContext(state=BAUDSET_DATA_STATE, rate=BAUDSET_DATA)

def build_structure() -> List[Dict[str, Union[str, int]]]:
    structure = []
    structure.append({ 'name': 'newline', 'size': 8 })
    structure.append({ 'name': 'empty', 'size': 2 })
    structure.append({ 'name': 'cmd_line_state2', 'size': 3 })
    structure.append({ 'name': 'rgb_enable', 'size': 3 })
    structure.append({ 'name': 'num_commands_processed', 'size': 8 })
    structure.append({ 'name': 'rxdata_to_controller', 'size': 8 })
    return structure

def read_debug_data(expected_bytes: Union[int, float],
                    ser: serial.Serial,
                    enable_debug: bool,
                    fw: Union[TextIO, StringIO]) -> DataFetch:
    full_bytestring = b""
    bytestring_total = 0
    binstring = ""
    hexstring = ""
    i = 0
    ser.reset_input_buffer()
    while (bytestring_total < expected_bytes):
        if enable_debug:
            fw.write(f"bytestring_total={bytestring_total} expected_bytes={expected_bytes} i={i}\n")
        # ser.read_until() returns bytes
        bytestring: bytes = bytes(ser.read_until())
        if enable_debug:
            fw.write("bytestring=%s\n" % bytestring.hex())
        bytestring_total += len(bytestring)
        for each in bytestring:
            hexstring += format(int(each), '02x')
            binstring += format(int(each), '08b')
        full_bytestring += bytestring
        # there exists
        #    hexstring
        #    binstring
        #    bytestring
        i += 1
    return DataFetch(bytestring=full_bytestring, binstring=binstring, hexstring=hexstring)

def main(stdscr,
         max_lines: int,
         rx_dev: Path,
         rx_baudrate: int,
         tx_dev: Path,
         tx_baudrate_start: int,
         tx_baudrate_max: int,
         tx_baudrate_search_increment: int,
         debug_filepath: Path,
         use_spi: bool = False,
         enable_debug: bool = False,
         ) -> None:
    BAUDSET_TESTVALS = ["A", "-", "C", "!"]
    BAUDSET_DATA_STATE = -1                  # an indexed position within BAUDSET_TESTVALS
    BAUDSET_DATA = tx_baudrate_start         # a baudrate used to send data out tx
    uart_rx_data = ""

    stdscr.clear()
    stdscr.nodelay(1)
    ser = serial.Serial(str(rx_dev), rx_baudrate, timeout=None)
    structure = build_structure()

    if enable_debug:
        fw = open(str(debug_filepath), 'w')
    else:
        fw = StringIO()
    expected_bitsize = 0
    expected_bytes = 0
    for each in [int(x['size']) for x in structure]:
        expected_bitsize += each
    if ((expected_bitsize % 8) == 0):
        expected_bytes = expected_bitsize/8
    else:
        expected_bytes = (expected_bitsize/8) + 1
    while True:
        COLUMN_SIZE = 0
        data = read_debug_data(expected_bytes=expected_bytes,
                               ser=ser,
                               enable_debug=enable_debug,
                               fw=fw,
                               )
        _, binstring, hexstring = data.bytestring, data.binstring, data.hexstring
        bytestring_total = len(data.bytestring)

        if enable_debug and ((expected_bitsize % 8) != 0):
            fw.write(f"(expected_bitsize % 8) != 0 :: expected_bitsize={expected_bitsize}\n")
        # trim any extra bits from bitstring, since we likely have padding on the end
        if ((expected_bitsize % 8) != 0):
            if enable_debug:
                fw.write(f"old_hexstring={hexstring}\n")
            offset = 8 - (expected_bitsize % 8)
            binstring = binstring[offset:]
            if enable_debug:
                fw.write(f"new_hexstring={8 - (expected_bitsize % 8)} offset={hexstring}\n")
        if enable_debug and (len(binstring) != expected_bitsize):
            fw.write(f"len(binstring) != expected_bitsize :: len(binstring)={len(binstring)} expected_bitsize={expected_bitsize}\n")
        #REVISIT THIS AARON
        # if the string is not the right size, skip it
        if (len(binstring) != expected_bitsize):
            if enable_debug:
                fw.write(f"len(binstring)={len(binstring)} != expected_bitsize={expected_bitsize} hexstring={hexstring}\n")
            stdscr.addstr(1,80, f"len(binstring)={str(len(binstring))}!= {str(expected_bitsize)}")
            continue
        else:
            stdscr.addstr(1,80, " " * 69)
            stdscr.addstr(1,0, f"{hexstring} len(c)={str(len(binstring))}bits")


        if (bytestring_total > expected_bytes):

            stdscr.addstr(0,0, f"{hexstring} ERROR: received ({str(bytestring_total)}) more than{str(expected_bytes)} bytes")
        else:
            stdscr.addstr(0,0, " " * 112)


        #reverse binstring so we can access it sanely using python list constructs
        binstring = binstring[::-1]
        stdscr.addstr(2,0, f"chars read:{str(bytestring_total)} bits:{str(len(binstring))}")
        position = 0
        error_offset = 3
        for i, variable in enumerate(structure):
            if i < max_lines:
                y_pos = i + error_offset
                x_pos = 0
            else:
                y_pos = i + error_offset - max_lines + 1
                x_pos = COLUMN_SIZE + 3
            if variable['name'] == 'newline':
                position += 8
            else:
                bits_used = int(variable['size'])
                vname = str(variable['name'])
                subsegment = binstring[position:position+bits_used]
                subsegment = subsegment[::-1]
                subsegment_bytestring = ""
                if (len(subsegment) % 8) != 0:
                    gap = 8 - len(subsegment) % 8
                    subsegment = ("0" * gap) + subsegment
                temp_array = list()
                for start_pos in range(0, len(subsegment), 8):
                    val = subsegment[start_pos:start_pos+8]
                    modval = str(chr(int(val,2)))
                    temp_array.append(modval)
                subsegment_bytestring = "".join(temp_array)
                if vname == "uart_rx_data":
                    uart_rx_data = get_safe_string(subsegment_bytestring)
                output_string  = do_debug(subsegment_bytestring, title=vname)
                if enable_debug:
                    fw.write(f"bits_used:{str(bits_used)} "
                             f"position:{str(position):<3} "
                             f"subsegment: {subsegment} "
                             f"len(subsegment)={str(len(subsegment))} "
                             f"subsegment_bytestring:{subsegment_bytestring} "
                             f"length={str(len(subsegment_bytestring))} "
                             f"title={vname} "
                             f"output_string:{output_string} "
                             f"x_pos={str(x_pos)} "
                             f"y_pos={str(y_pos)}\n")
                if ((i < max_lines) and (len(output_string) > COLUMN_SIZE)):
                    COLUMN_SIZE = len(output_string)
                stdscr.addstr(y_pos, x_pos, output_string)

                position += bits_used
            stdscr.refresh()
        k = stdscr.getch()
        literals = ['R', 'r', 'G', 'g', 'B', 'b', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'L']
        if BAUDSET_DATA_STATE != -1 and BAUDSET_DATA_STATE != 3:
            stdscr.addstr(max_lines+3,0, f"uart_rx_data:{uart_rx_data}")
            current_context = BaudContext(state=BAUDSET_DATA_STATE, rate=BAUDSET_DATA)
            context = findbaud(stdscr, uart_rx_data, cur_context=current_context, max_lines=max_lines, max_baudrate=tx_baudrate_max, baudrate_increment=tx_baudrate_search_increment)
            BAUDSET_DATA_STATE, BAUDSET_DATA = context.state, context.rate
            testval(tx_dev, BAUDSET_DATA, BAUDSET_TESTVALS[BAUDSET_DATA_STATE], spi=use_spi)
        if (k != -1):
            if (chr(k) == 'H'):
                for _ in range(0, 16):
                    writeser(ser, 'H', spi=use_spi)
            elif (chr(k) == 'P'):
                BAUDSET_DATA = tx_baudrate_start
                BAUDSET_DATA_STATE = 1
            elif (chr(k) in literals):
                testval(tx_dev, BAUDSET_DATA, chr(k), spi=use_spi)
                writeser(ser, chr(k), spi=use_spi)
            else:
                writeser(ser, chr(k), spi=use_spi)
    # TODO: fix this
    stdscr.refresh()
    stdscr.getkey()
    ser.close()

if __name__ == "__main__":
    PARSER = argparse.ArgumentParser(prog="uart_rx",
                                     description="i receive signals from fpga debugger")

    PARSER.add_argument("--debug-filepath",
                        dest="debug_filepath",
                        action="store",
                        default=Path("blah"),
                        type=Path,
                        help="If using --debug, write output to this path")
    PARSER.add_argument("--rx-dev",
                        dest="rx_dev",
                        action="store",
                        default=Path("/dev/ttyAMA2"),
                        type=Path,
                        help="UART device used to receive information from fpga debugger")
    PARSER.add_argument("--rx-baudrate",
                        dest="rx_baudrate",
                        action="store",
                        default=115200,
                        type=int,
                        help="baudrate to use for --rx-dev")
    PARSER.add_argument("--tx-dev",
                        dest="tx_dev",
                        action="store",
                        default=Path("/dev/ttyAMA3"),
                        type=Path,
                        help="UART device used to send information to the fpga debugger")
    PARSER.add_argument("--tx-baudrate-start",
                        dest="tx_baudrate_start",
                        action="store",
                        default=2444444,
                        type=int,
                        help="starting baudrate to be used to send information to the fpga debugger")
    PARSER.add_argument("--tx-baudrate-max",
                        dest="tx_baudrate_max",
                        action="store",
                        default=2900000,
                        type=int,
                        help="max baudrate to be used to send information to the fpga debugger")
    PARSER.add_argument("--tx-baudrate-search-increment",
                        dest="tx_baudrate_search_increment",
                        action="store",
                        default=500,
                        type=int,
                        help="amount to increment baudrate when searching for tx goal")
    PARSER.add_argument("--max-lines",
                        dest="max_lines",
                        action="store",
                        default=38,
                        type=int,
                        help="max lines shown")
    PARSER.add_argument("--debug",
                        dest="enable_debug",
                        action="store_true",
                        help="turn on debug")
    PARSER.add_argument("--structure-size",
                        dest="print_structure_size",
                        action="store_true",
                        help="print structure size and exit")
    PARSER.add_argument("--spi",
                        dest="use_spi",
                        action="store_true",
                        help="use spi")
    ARGS = PARSER.parse_args()
    temp_args = vars(ARGS)
    print_structure_size = temp_args.pop("print_structure_size")

    if print_structure_size:
        d = build_structure()
        print(f"structure_size={sum(map(lambda x: int(x['size']), d))} bits")
        sys.exit(0)

    try:
        wrapper(partial(main, **temp_args))
    except KeyboardInterrupt:
        pass
