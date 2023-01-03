
#Begin clock constraint
define_clock -name {main|pin3_clk_16mhz} {p:main|pin3_clk_16mhz} -period 14.600 -clockgroup Autoconstr_clkgroup_0 -rise 0.000 -fall 7.300 -route 0.000 
#End clock constraint

#Begin clock constraint
define_clock -name {main|clk_root_logic_derived_clock} {n:main|clk_root_logic_derived_clock} -period 14.600 -clockgroup Autoconstr_clkgroup_0 -rise 0.000 -fall 7.300 -route 0.000 
#End clock constraint

#Begin clock constraint
define_clock -name {clock_divider_2s_3s|clk_out_derived_clock} {n:clock_divider_2s_3s|clk_out_derived_clock} -period 14.600 -clockgroup Autoconstr_clkgroup_0 -rise 0.000 -fall 7.300 -route 0.000 
#End clock constraint

#Begin clock constraint
define_clock -name {timeout_2s_1|un68_running_inferred_clock} {n:timeout_2s_1|un68_running_inferred_clock} -period 3000.000 -clockgroup Autoconstr_clkgroup_2 -rise 0.000 -fall 1500.000 -route 0.000 
#End clock constraint

#Begin clock constraint
define_clock -name {matrix_scan|row_latch_inferred_clock} {n:matrix_scan|row_latch_inferred_clock} -period 5.738 -clockgroup Autoconstr_clkgroup_3 -rise 0.000 -fall 2.869 -route 0.000 
#End clock constraint

#Begin clock constraint
define_clock -name {matrix_scan|row_latch_inferred_clock_1} {n:matrix_scan|row_latch_inferred_clock_1} -period 5.738 -clockgroup Autoconstr_clkgroup_4 -rise 0.000 -fall 2.869 -route 0.000 
#End clock constraint
