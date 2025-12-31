// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`define WAIT_ASSERT(CLK, COND, MAX) \
begin \
    integer __w; \
    for (__w = 0; __w < (MAX) && !(COND); __w = __w + 1) @(posedge (CLK)); \
    if (!(COND)) \
        $fatal(1, "Timeout after %0d cycles: %s not true", __w, `"COND`"); \
    else \
        $display("Condition %s met after %0d cycles", `"COND`", __w); \
end

`define STREAM_BYTES_MSB(_clk, _dst, _vec)                                           \
  for (int __i = 0; __i < ($bits(_vec)/8); __i++) begin                               \
    @(posedge _clk);                                                                  \
    _dst = _vec[($bits(_vec)-1) - (__i*8) -: 8];                                      \
  end
