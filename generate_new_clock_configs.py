from typing import Union, Tuple
from math import log, ceil
from subprocess import Popen, PIPE
from pathlib import Path

ICEPLL_PATH = Path("/home/awhite/Documents/Projects/ice40_toolchain/icestorm/icepll/icepll")
BASE_CLOCK_MHZ = 16
PRIMARY_CLOCK_HZ = 50000000
PRIMARY_CLOCK_MHZ = int(PRIMARY_CLOCK_HZ/1000000)
TARGET_DATA_BAUD = 2444444
TARGET_DEBUG_BAUD = 115200
TARGET_DEBUG_MSG_HZ = 22

def float_ticks_from_freq_divide(src_hz: float, tgt_hz: float) -> Tuple[Union[float, int]]:
    ticks = src_hz / tgt_hz
    ticks_bitwidth = ceil(log(ticks+1, 2))
    closest_approx_ticks = find_closest_approx_to_tgt(src_hz=src_hz, tgt_hz=tgt_hz, result_ticks=ticks)
    closest_approx_bitwidth = ceil(log(closest_approx_ticks, 2))
    return (ticks, ticks_bitwidth, closest_approx_ticks, closest_approx_bitwidth)

def int_and_size_to_verilog(val: int, size: int) -> str:
    return "{size}'d{value}".format(size=size, value=val)

def find_closest_approx_to_tgt(src_hz: float,
                               tgt_hz: float,
                               result_ticks: float,
                            ) -> int:
    """ If we have to round up or round down,
        which value (ceil or floor) gives us the
        closest approx to tgt_hz?
    """
    ticks_floor = int(result_ticks)
    ticks_ceil = ceil(result_ticks)
    if result_ticks == int(result_ticks):
        return result_ticks
    else:
        lower_delta = abs((src_hz / ticks_floor) - tgt_hz)
        upper_delta = abs((src_hz / ticks_ceil) - tgt_hz)
        if lower_delta < upper_delta:
            return ticks_floor
        return ticks_ceil

def describe_parameter(name: str,
                       val_ticks: int,
                       val_width: int = None,
                       unit: str = "TICKS_PER_BIT",
                       ) -> None:
    if val_width is None:
        rendered_value = val_ticks
    else:
        rendered_value = int_and_size_to_verilog(val=val_ticks, size=val_width)
    print("parameter {name}_{unit} = {val};".format(name=name,
                                                    unit=unit,
                                                    val=rendered_value))
def summarize(src_hz: float,
              tgt_hz: float,
              tick_calc: Tuple[Union[float, int]],
              context: str = "") -> None:
    print("// context: {context}".format(context=context))
    print("// {src_hz}hz / {tgt_hz}hz = {result:.4f} ticks width={bits}".format(src_hz=src_hz,
                                                                                tgt_hz=tgt_hz,
                                                                                result=tick_calc[0],
                                                                                bits=tick_calc[1],
                                                                                ))
    actual_tgt = src_hz / tick_calc[2]
    expected_tgt = tgt_hz
    variation = ((actual_tgt - expected_tgt) / expected_tgt) * 100
    print("// tgt_hz variation (after rounding): {var:.2f}%".format(var=variation))
    print("// {src_hz}hz / {tgt_hz:.0f}hz = {result:.0f} ticks width={bits}".format(src_hz=src_hz,
                                                                                    tgt_hz=actual_tgt,
                                                                                    result=tick_calc[2],
                                                                                    bits=tick_calc[3],
                                                                                    ))
def get_period(hz: int) -> float:
    return float(1/hz)


def get_clock_scaler(in_mhz: int, out_mhz: int, path: Path) -> None:
    icepll_action = Popen(args=[str(path), "-i", str(in_mhz), "-o", str(out_mhz), "-m"],
                        stdout=PIPE)
    icepll_result = icepll_action.stdout.read().decode("utf-8")
    icepll_output_lines = str(icepll_result).split("\n")

    keep_lines = ["Given input frequency:",
                  "Requested output frequency:",
                  "Achieved output frequency:",
                  "FEEDBACK_PATH",
                  "DIVR(",
                  "DIVF(",
                  "DIVQ(",
                  "FILTER_RANGE(",
                  ]
    print("===")
    print("PLL config")
    print("---")
    for stdout_line in icepll_output_lines:
        for match_content in keep_lines:
            if match_content in stdout_line:
                pass
                print(stdout_line)

# The baudrate at which the controller receives image data
#	parameter CTRLR_CLK_TICKS_PER_BIT
#	parameter CTRLR_CLK_TICKS_WIDTH
name_label = "CTRLR_CLK"
tgt_hz = TARGET_DATA_BAUD
tick_calc = float_ticks_from_freq_divide(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz)
summarize(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz, tick_calc=tick_calc, context="RX DATA baud")
describe_parameter(name=name_label, val_ticks=tick_calc[2], val_width=tick_calc[3])
describe_parameter(name=name_label, val_ticks=tick_calc[3], val_width=ceil(log(tick_calc[3]+1, 2)), unit="TICKS_WIDTH")
print("\n")
#

# The baudrate at which the debugger will communicate messages upstream
#	parameter DEBUG_TX_UART_TICKS_PER_BIT
#	parameter DEBUG_TX_UART_TICKS_PER_BIT_WIDTH
name_label = "DEBUG_TX_UART"
tgt_hz = TARGET_DEBUG_BAUD
tick_calc = float_ticks_from_freq_divide(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz)
summarize(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz, tick_calc=tick_calc, context="TX DEBUG baud")
describe_parameter(name=name_label, val_ticks=tick_calc[2], val_width=tick_calc[3])
describe_parameter(name=name_label, val_ticks=tick_calc[3], val_width=ceil(log(tick_calc[3]+1, 2)), unit="TICKS_PER_BIT_WIDTH")
print("\n")

# The frequency in which variables are captured from the system and
# sent to the debugging target. Used by debugger.v module.
#	parameter DEBUG_MSGS_PER_SEC_TICKS_SIM
#	parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM
name_label = "DEBUG_MSGS"
tgt_hz = TARGET_DEBUG_MSG_HZ
tick_calc = float_ticks_from_freq_divide(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz)
summarize(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz, tick_calc=tick_calc, context="Debug msg rate")
describe_parameter(name=name_label, val_ticks=tick_calc[2], val_width=tick_calc[3], unit="PER_SEC_TICKS")
describe_parameter(name=name_label, val_ticks=tick_calc[3], val_width=ceil(log(tick_calc[3]+1, 2)), unit="PER_SEC_TICKS_WIDTH")
print("\n")

# The frequency in which variables are captured from the system and
# sent to the debugging target. Used by debugger.v module.
# ** NOTE ** this is an override for testbenches only with static values
#            that ensure we don't simulate into infinity
#	parameter DEBUG_MSGS_PER_SEC_TICKS_SIM
#	parameter DEBUG_MSGS_PER_SEC_TICKS_WIDTH_SIM
name_label = "DEBUG_MSGS"
tgt_hz = TARGET_DEBUG_MSG_HZ
tick_calc = float_ticks_from_freq_divide(src_hz=PRIMARY_CLOCK_HZ, tgt_hz=tgt_hz)
print("`ifdef SIM")
print("// use smaller value in testbench so we don't infinitely sim")
describe_parameter(name=name_label, val_ticks=15, val_width=4, unit="PER_SEC_TICKS_SIM")
describe_parameter(name=name_label, val_ticks=4, val_width=ceil(log(4+1, 2)), unit="PER_SEC_TICKS_WIDTH_SIM")
print("\n")

# The number of nanoseconds in a half period. Used by test benches to define
# the clock value
#    parameter SIM_HALF_PERIOD_NS;
precision = 5
val = "{half_period:.0{precision}f}".format(half_period=(get_period(PRIMARY_CLOCK_HZ)*1000000000)/2,
                                            precision=5,
                                            )
print("// period = (1 / {clock}hz) / 2 = {val}".format(clock=PRIMARY_CLOCK_HZ,
                                                       val=val,
                                                       ))
describe_parameter(name="SIM_HALF_PERIOD", val_ticks=val, unit="NS")
print("`endif")
print("\n")

# The config needed to scale the core clock to the desired clock using ICE40 PLL
get_clock_scaler(in_mhz=BASE_CLOCK_MHZ, out_mhz=PRIMARY_CLOCK_MHZ, path=ICEPLL_PATH)


