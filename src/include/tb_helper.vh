`define WAIT_ASSERT(CLK, COND, MAX) \
begin \
    integer __w; \
    for (__w = 0; __w < (MAX) && !(COND); __w = __w + 1) @(posedge (CLK)); \
    if (!(COND)) \
        $fatal(1, "Timeout after %0d cycles: %s not true", __w, `"COND`"); \
    else \
        $display("Condition %s met after %0d cycles", `"COND`", __w); \
end