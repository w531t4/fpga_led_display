import serial
import spidev
from curses import wrapper
from typing import IO
BAUDRATE = 115200
MAX_LINES=40
global COLUMN_SIZE
COLUMN_SIZE = 0
global BAUDSET_DATA
global BAUDSET_DATA_SCALE
global BAUDSET_DATA_STATE
global BAUDSET_DATA_MAX
global BAUDSET_TESTVALS
global BAUDSET_DATA_INIT
BAUDSET_TESTVALS = ["A", "-", "C", "!"]

BAUDSET_DATA_INIT=2444444
BAUDSET_DATA = BAUDSET_DATA_INIT
BAUDSET_DATA_SCALE=500
BAUDSET_DATA_STATE=-1
BAUDSET_DATA_MAX=2900000
global enable_debug
enable_debug = False
spi = False

def send_spi_bytes(data: bytes) -> None:
    spi_dev = 1
    spi_port = 0
    spi_rate = 40000
    spi = spidev.SpiDev()
    spi.open(spi_dev, spi_port)                 # Use bus 1 (SPI1), device 0 (CE0)
    spi.max_speed_hz = spi_rate   # Set speed (10 MHz here)
    spi.mode = 0
    spi.xfer3(list(data))

def gen_bitstring(c: str) -> str:
    r_int = ord(c)
    if len(bin(r_int)[2:]) < 8:
        bitstring = '0'*(8-len(bin(r_int)[2:])) + bin(r_int)[2:]
    else:
        bitstring = bin(r_int)[2:]
    return bitstring

def get_hexstring(bitstring: str, raw: bool = True) -> str:
    retstring = ""
    for each in [bitstring[i:i+4] for i in range(0, len(bitstring), 4)]:
        retstring = retstring + hex(int(each,2))[2:]
    if (raw == True):
        return retstring
    else:
        return "0x" + retstring

def get_safe_string(c: str) -> str:
    d = ""
    for each in c:
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d = d + each
        else:
            d = d + "*"
    return d

def reverse_bits_char(c: str) -> str:
    a = gen_bitstring(c)[::-1]
    return chr(int(a,2))

def get_safe_string_rev(c: str) -> str:
    d = ""
    for each in c:
        each = reverse_bits_char(each)
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d = d + each
        else:
            d = d + "*"
    return d

def do_debug(c: str, title: str = "", titlelength: int = 24) -> str:
    global uart_rx_data
    binstring = ""
    for each in c:
        binstring = binstring + gen_bitstring(each)
    hexrep = get_hexstring(binstring, raw=False)
    r_c = ""
    s = binstring
    for each in [s[i:i+8] for i in range(0, len(s), 8)]:
        if (int(each,2) > 256):
            r_c = r_c + "X"
        else:
            r_c = r_c + chr(int(each,2))
    if title == "uart_rx_data":
        uart_rx_data = get_safe_string(c)
    rstring = (        '{0: <' + str(titlelength) + '}').format(title) \
            + ('{0: <' + str(4+16) + '}').format("0b"+binstring) \
            + ('{0: <' + str(4+4) + '}').format(hexrep) \
            + ('{0: <' + str(2) +   '}').format(get_safe_string(c)) \
            + " rchr=" +('{0: <' + str(2) +   '}').format(get_safe_string_rev(c))
    return rstring

def writeser(ser: IO[bytes], s: str) -> None:
    if spi:
        send_spi_bytes(list(s.encode("utf-8")))
    else:
        for each in s:
            ser.write(each.encode("utf-8"))

def findbaud(stdscr, curval: str) -> None:
    global BAUDSET_DATA_STATE
    global BAUDSET_DATA
    global BAUDSET_DATA_MAX
    stdscr.addstr(MAX_LINES+2,0, "DATA_TX:BAUD:" + str(BAUDSET_DATA) + " STATE:" + str(BAUDSET_DATA_STATE))
    if BAUDSET_DATA_STATE == 0 and curval == "A":
        BAUDSET_DATA_STATE = 1
        return
    elif BAUDSET_DATA_STATE == 1 and curval == "-":
        BAUDSET_DATA_STATE = 2
        return
    elif BAUDSET_DATA_STATE == 2 and curval == "C":
        BAUDSET_DATA_STATE = -1
        return
    else:
        if BAUDSET_DATA > BAUDSET_DATA_MAX:
            BAUDSET_DATA_STATE = -1
        else:
            BAUDSET_DATA_STATE = 0
            BAUDSET_DATA += BAUDSET_DATA_SCALE
    return

def testval(dev: str, baud: int, val: str) -> None:
    if spi:
        send_spi_bytes(val.encode("utf-8"))
    else:
        ser_data = serial.Serial(dev, baud, timeout=None)
        ser_data.write(val.encode("utf-8"))
        ser_data.close()

def main(stdscr) -> None:
    global BAUDSET_DATA
    global BAUDSET_DATA_SCALE
    global BAUDSET_DATA_STATE
    global BAUDSET_DATA_MAX
    global BAUDSET_TESTVALS
    global BAUDSET_DATA_INIT
    stdscr.clear()
    stdscr.nodelay(1)
    serial_device = "/dev/ttyAMA2"
    baudrate=BAUDRATE
    ser = serial.Serial(serial_device, baudrate, timeout=None)
    structure = []
    structure.append({ 'name': 'newline', 'size': 8 })
    structure.append({ 'name': 'uart_rx_data', 'size': 8 })
    structure.append({ 'name': 'ram_a_data_in', 'size': 8 })
    structure.append({ 'name': 'ram_a_clk_enable', 'size': 1 })
    structure.append({ 'name': 'ram_a_address', 'size': 12 })
    structure.append({ 'name': 'ram_a_data_out', 'size': 8 })
    structure.append({ 'name': 'ram_a_write_enable', 'size': 1 })
    structure.append({ 'name': 'ram_b_data_out', 'size': 16 })
    structure.append({ 'name': 'ram_b_clk_enable', 'size': 1 })
    structure.append({ 'name': 'ram_b_address', 'size': 11 })
    structure.append({ 'name': 'row_address_active', 'size': 4 })
    structure.append({ 'name': 'row_address', 'size': 4 })
    structure.append({ 'name': 'column_address', 'size': 6 })
    structure.append({ 'name': 'rgb_enable', 'size': 3 })
    structure.append({ 'name': 'brightness_enable', 'size': 6 })
    structure.append({ 'name': 'brightness_mask', 'size': 6 })
    structure.append({ 'name': 'pixel_rgb565_bottom', 'size': 16 })
    structure.append({ 'name': 'pixel_rgb565_top', 'size': 16 })
    structure.append({ 'name': 'ram_access_start', 'size': 1 })
    structure.append({ 'name': 'ram_access_start_latch', 'size': 1 })
    structure.append({ 'name': 'uart_rx', 'size': 1 })
    structure.append({ 'name': 'cmd_line_state', 'size': 2 })
    structure.append({ 'name': 'ram_b_reset', 'size': 1 })
    structure.append({ 'name': 'row_latch_state', 'size': 2 })
    structure.append({ 'name': 'row_latch', 'size': 1 })
    structure.append({ 'name': 'rx_running', 'size': 1 })
    structure.append({ 'name': 'rgb1', 'size': 3 })
    structure.append({ 'name': 'rgb2', 'size': 3 })
    structure.append({ 'name': 'cmd_line_addr2', 'size': 12 })
    structure.append({ 'name': 'cmd_line_address_col2', 'size': 7 })
    structure.append({ 'name': 'cmd_line_address_row2', 'size': 5 })
    structure.append({ 'name': 'clk_pixel_load', 'size': 1 })
    structure.append({ 'name': 'clk_pixel_load_en', 'size': 1 })
    structure.append({ 'name': 'pixel_load_counter2', 'size': 4 })
    structure.append({ 'name': 'debug_command', 'size': 8 })
    structure.append({ 'name': 'num_commands_processed', 'size': 8 })
    structure.append({ 'name': 'whitespace', 'size': 3 })

    if enable_debug == True:
        logfile = "blah"
        fw = open(logfile, 'w')

    expected_bitsize = 0
    expected_bytes = 0
    for each in [int(x['size']) for x in structure]:
        expected_bitsize += each
    if ((expected_bitsize % 8) == 0):
        expected_bytes = expected_bitsize/8
    else:
        expected_bytes = (expected_bitsize/8) + 1
    while True:
        bytestring = ""
        bytestring_total = 0
        binstring = ""
        hexstring = ""
        i = 0
        while (bytestring_total < expected_bytes):
            if enable_debug:
                fw.write("bytestring_total=%s expected_bytes=%s i=%s\n" % (bytestring_total, expected_bytes, i))
            # ser.read_until() returns bytes
            bytestring = bytes(ser.read_until())
            if enable_debug:
                fw.write("bytestring=%s\n" % bytestring)
            bytestring_total += len(bytestring)
            for each in bytestring:
                    hexstring = hexstring + format(int(each), '02x')
                    binstring = binstring + format(int(each), '08b')
        # there exists
        #    hexstring
        #    binstring
        #    bytestring

            i += 1
        if enable_debug:
            fw.write("(expected_bitsize % 8) != 0 :: expected_bitsize={expected_bitsize}\n".format(expected_bitsize=expected_bitsize))
        # trim any extra bits from bitstring, since we likely have padding on the end
        if ((expected_bitsize % 8) != 0):
            if enable_debug:
                fw.write("old_hexstring=%s\n" % (hexstring))
            offset = 8 - (expected_bitsize % 8)
            binstring = binstring[offset:]
            if enable_debug:
                fw.write("new_hexstring=%s offset=%s\n" % (8 - (expected_bitsize % 8), hexstring))
        if enable_debug:
            fw.write("len(binstring) != expected_bitsize :: len(binstring)={len_binstring} expected_bitsize={expected_bitsize}\n".format(expected_bitsize=expected_bitsize,
                                                                                                                                     len_binstring=len(binstring)))
        #REVISIT THIS AARON
        # if the string is not the right size, skip it
        if (len(binstring) != expected_bitsize):
            if enable_debug:
                fw.write("len(binstring)=%s != expected_bitsize=%s hexstring=%s\n" % ( len(binstring), expected_bitsize, hexstring))
            stdscr.addstr(1,80, "len(binstring)=" + str(len(binstring)) + "!= " + str(expected_bitsize))
            continue
        else:
            stdscr.addstr(1,80, "                                                                     ")
            stdscr.addstr(1,0, hexstring + " len(c)=" + str(len(binstring)) + "bits")


        if (bytestring_total > expected_bytes):
            stdscr.addstr(0,0, hexstring +  " ERROR: received (" + str(bytestring_total) + ") more than" + str(expected_bytes) + " bytes")
        else:
            stdscr.addstr(0,0, "                                                                                                                ")


        #reverse binstring so we can access it sanely using python list constructs
        binstring = binstring[::-1]
        stdscr.addstr(2,0, "chars read:" + str(bytestring_total) + " bits:" + str(len(binstring)))
        position = 0
        error_offset = 3
        i = 0
        MAX_LINES = 38
        COLUMN_SIZE = 0
        for variable in structure:
            if i < MAX_LINES:
                y_pos = i + error_offset
                x_pos = 0
            else:
                y_pos = i + error_offset - MAX_LINES + 1
                x_pos = COLUMN_SIZE + 3
            if variable['name'] == 'newline':
                position += 8
            else:
                bits_used = variable['size']
                vname = variable['name']
                subsegment = binstring[position:position+bits_used]
                subsegment = subsegment[::-1]
                delta = len(subsegment) % 8
                #if delta > 0:
                #    subsegment = "0"*(8-delta) + subsegment
                # if enable_debug and (vname == "ram_a_address"):
                #     fw.write("\n====blah====\n")
                #     fw.write("bits_used=%s\n" % bits_used)
                #     fw.write("position=%s\n" % position)
                #     fw.write("delta=%s\n" % delta)
                #     fw.write("binstring[position:position+bits_used]=%s hex=%s\n" % (binstring[position:position+bits_used], hex(int(binstring[position:position+bits_used], 2))))
                #     fw.write("subsegment=%s hex=%s \n" % ((binstring[position:position+bits_used])[::-1], hex(int((binstring[position:position+bits_used])[::-1],2))))
                subsegment_numbytes = len(subsegment)/8
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
                output_string  = do_debug(subsegment_bytestring, title=vname)
                if enable_debug == True:
                    fw.write("bits_used:" + str(bits_used) + " position:" + str(position) + \
                        " subsegment: " + subsegment + " len(subsegment)=" + str(len(subsegment)) + \
                        " delta:" + str(delta) + " num_bytes:" + str(subsegment_numbytes) + \
                        " subsegment_bytestring:" + subsegment_bytestring + " length=" + \
                        str(len(subsegment_bytestring)) + " title=" + vname + \
                        " output_string:" + output_string + \
                        " x_pos=" + str(x_pos) + " y_pos=" + str(y_pos) + '\n')
                if ((i < MAX_LINES) and (len(output_string) > COLUMN_SIZE)):
                    COLUMN_SIZE = len(output_string)
                stdscr.addstr(y_pos, x_pos, output_string)

                position += bits_used
            i += 1
            stdscr.refresh()
        k = stdscr.getch()
        literals = ['R', 'r', 'G', 'g', 'B', 'b', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'L']
        if BAUDSET_DATA_STATE != -1 and BAUDSET_DATA_STATE != 3:
            stdscr.addstr(MAX_LINES+3,0, "uart_rx_data:"+ uart_rx_data)
            findbaud(stdscr, uart_rx_data)
            testval("/dev/ttyAMA3", BAUDSET_DATA, BAUDSET_TESTVALS[BAUDSET_DATA_STATE])
        if (k != -1):
            if (chr(k) == 'H'):
                writeser(ser, 'H')
                writeser(ser, 'H')
                writeser(ser, 'H')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'H')
                writeser(ser, 'H')
                writeser(ser, 'H')
                writeser(ser, 'H')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'h')
                writeser(ser, 'h')
            elif (chr(k) == 'P'):
                BAUDSET_DATA = BAUDSET_DATA_INIT
                BAUDSET_DATA_STATE = 1
            elif (chr(k) in literals):
                testval("/dev/ttyAMA3", BAUDSET_DATA, chr(k))
                writeser(ser, chr(k))
            else:
                writeser(ser, chr(k))
    # TODO: fix this
    stdscr.refresh()
    stdscr.getkey()
    ser.close()

wrapper(main)
