import serial
import time
from curses import wrapper
from uart_write import reset_state
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

def gen_bitstring(c):
    r_int = ord(c)
    if len(bin(r_int)[2:]) < 8:
        bitstring = '0'*(8-len(bin(r_int)[2:])) + bin(r_int)[2:]
    else:
        bitstring = bin(r_int)[2:]
#   print bitstring
    return bitstring

def get_hexstring(bitstring, raw=True):
    retstring = ""
    for each in [bitstring[i:i+4] for i in range(0, len(bitstring), 4)]:
        retstring = retstring + hex(int(each,2))[2:]
    if (raw == True):
        return retstring
    else:
        return "0x" + retstring

def get_safe_string(c):
#    d = c.replace('\n', '\\n').replace(chr(0x0c), '\\n').replace(chr(0x0b), '\\n')
    d = ""
    for each in c:
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d = d + each
        else:
            d = d + "*"
    return d
def reverse_bits_char(c):
    a = gen_bitstring(c)[::-1]
    return chr(int(a,2))
def get_safe_string_rev(c):
#    d = c.replace('\n', '\\n').replace(chr(0x0c), '\\n').replace(chr(0x0b), '\\n')
    d = ""
    for each in c:
        each = reverse_bits_char(each)
        if ((ord(each) >= 32) and (ord(each) <= 126)):
            d = d + each
        else:
            d = d + "*"
    return d
def do_debug(c, length=8, title="", titlelength=24):
    global uart_rx_data
    binstring = ""
    for each in c:
        binstring = binstring + gen_bitstring(each)
    hexrep = get_hexstring(binstring, raw=False)
#    hexrep = "0x" + ('{:0>' + str(2) + '}').format(hex(int(binstring[2:length-2],2))[2:]) #+ ('{:0>' + str(2) + '}').format(hex(int(binstring[length-2:],2))[2:])
    r_c = ""
    s = binstring
    for each in [s[i:i+8] for i in range(0, len(s), 8)]:
        if (int(each,2) > 256):
            r_c = r_c + "X"
        else:
            r_c = r_c + chr(int(each,2))
    t = get_safe_string(c)
    if title == "uart_rx_data":
        uart_rx_data = get_safe_string(c)
    rstring = (        '{0: <' + str(titlelength) + '}').format(title) \
            + ('{0: <' + str(4+16) + '}').format("0b"+binstring) \
            + ('{0: <' + str(4+4) + '}').format(hexrep) \
            + ('{0: <' + str(2) +   '}').format(get_safe_string(c)) \
            + " rchr=" +('{0: <' + str(2) +   '}').format(get_safe_string_rev(c))
#            + " rchar=" + get_safe_string_rev(c)
    return rstring
def writeser(ser, s: str):
    for each in s:
        ser.write(each.encode("utf-8"))
def findbaud(stdscr, dev, curval):
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

def testval(dev, baud, val: str):
    ser_data = serial.Serial(dev, baud, timeout=None)
    ser_data.write(val.encode("utf-8"))
    ser_data.close()
#    ser_data.close()
def main(stdscr):
    global BAUDSET_DATA
    global BAUDSET_DATA_SCALE
    global BAUDSET_DATA_STATE
    global BAUDSET_DATA_MAX
    global BAUDSET_TESTVALS
    global BAUDSET_DATA_INIT
    stdscr.clear()
    stdscr.nodelay(1)
#    serial_device = "/dev/ttyAMA0"
    serial_device = "/dev/ttyUSB0"
    targetfile = "blah565.raw"
    chunksize = 128
    #f = open(targetfile, 'rb')
    #fw = f.read()
    index = 0
    row = 0
    total = ""
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
        while (bytestring_total < expected_bytes):
#            bytestring = ser.read_until()
            # ser.read_until() returns bytes
            bytestring = bytes(ser.read_until())
            bytestring_total += len(bytestring)
#                hexstring = ""
#        binstring = ""
            for each in bytestring:
                    hexstring = hexstring + format(int(each), '02x')
                    binstring = binstring + format(int(each), '08b')
        # there exists
        #    hexstring
        #    binstring
        #    bytestring

        # trim any extra bits from bitstring, since we likely have padding on the end
        if ((expected_bitsize % 8) != 0):
            offset = 8 - (expected_bitsize % 8)
            binstring = binstring[offset:]
        #REVISIT THIS AARON
        # if the string is not the right size, skip it
        if (len(binstring) != expected_bitsize):
            stdscr.addstr(1,80, "len(binstring)=" + str(len(binstring)) + "!= " + str(expected_bitsize))
            continue
        else:
            stdscr.addstr(1,80, "                                                                     ")
            stdscr.addstr(1,0, hexstring + " len(c)=" + str(len(binstring)) + "bits")


        if (bytestring_total > expected_bytes):
            stdscr.addstr(0,0, hexstring +  " ERROR: received (" + str(bytestring_total) + ") more than" + str(expected_bytes) + " bytes")
        else:
            stdscr.addstr(0,0, "                                                                                                                ")

#           time.sleep(5)
#       else:
#           stdscr.addstr(0,0, "                                                 ")

        #reverse binstring so we can access it sanely using python list constructs
        binstring = binstring[::-1]
        stdscr.addstr(2,0, "chars read:" + str(bytestring_total) + " bits:" + str(len(binstring)))
        if False:
            continue
        else:
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
                    renderstring = ""
                    subsegment = binstring[position:position+bits_used]
                    subsegment = subsegment[::-1]
                    delta = len(subsegment) % 8
                    if delta > 0:
                        subsegment = "0"*(8-delta) + subsegment
                    subsegment_numbytes = len(subsegment)/8
                    subsegment_bytestring = ""
                    for slice in [subsegment[k:k+8] for k in range(0, len(subsegment), 8)]:
                        subsegment_bytestring = subsegment_bytestring + str(chr(int(slice,2)))
#                   subsegment_bytestring = ordint(subsegment,2), str(subsegment_numbytes) + "x")
                    #reverse the order, since things are currently c[0] c[1], we want c[1], c[0]
                    subsegment_bytestring = subsegment_bytestring[::-1]
                    output_string  = do_debug(subsegment_bytestring, length=bits_used, title=vname)
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
#                        stdscr.addstr(y_pos, x_pos, do_debug(subsegment, length=vsize, title=vname))
                    position += bits_used
    #                    stdscr.refresh()
                i += 1
                stdscr.refresh()
    #    s = ""
    #    for each in c:
    #        s = s+ format(ord(each), '02x')
    #    print s[::-1]
#        print(chr(27))
 #        print output
        #print
        k = stdscr.getch()
        literals = ['R', 'r', 'G', 'g', 'B', 'b', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'L']
        if BAUDSET_DATA_STATE != -1 and BAUDSET_DATA_STATE != 3:
            stdscr.addstr(MAX_LINES+3,0, "uart_rx_data:"+ uart_rx_data)
    #        findbaud(stdscr, "/dev/ttyUSB0", uart_rx_data)
    #        testval("/dev/ttyUSB0", BAUDSET_DATA, BAUDSET_TESTVALS[BAUDSET_DATA_STATE]*10)
            findbaud(stdscr, "/dev/ttyAMA0", uart_rx_data)
    #        time.sleep(.1)
            testval("/dev/ttyAMA0", BAUDSET_DATA, BAUDSET_TESTVALS[BAUDSET_DATA_STATE])
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
                testval("/dev/ttyAMA0", BAUDSET_DATA, chr(k))
                writeser(ser, chr(k))
            else:
                writeser(ser, chr(k))
    stdscr.refresh()
    stdscr.getkey()
    ser.close()
wrapper(main)
