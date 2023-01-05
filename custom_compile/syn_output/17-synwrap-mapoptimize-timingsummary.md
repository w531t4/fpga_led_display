##### START OF TIMING REPORT #####[
# Timing Report written on Wed Jan  4 09:33:01 2023
#
Top view:               main
Requested Frequency:    16.0 MHz
Wire load mode:         top
Paths requested:        1
Constraint File(s):    /home/awhite/Documents/Projects/fpga_led_display/template_syn_1.fdc

@N: MT320 |This timing report is an estimate of place and route data. For final timing results, use the FPGA vendor place and route report.
@N: MT322 |Clock constraints include only register-to-register paths associated with each individual clock.
Performance Summary
*******************
Worst slack in design: -6.934
                                Requested     Estimated     Requested     Estimated                 Clock                         Clock
Starting Clock                  Frequency     Frequency     Period        Period        Slack       Type                          Group
--------------------------------------------------------------------------------------------------------------------------------------------
my16mhzclk                      16.0 MHz      NA            62.500        NA            DCM/PLL     declared                      my_c_other
pll|clock_out_derived_clock     132.0 MHz     48.8 MHz      7.575         20.476        -6.934      derived (from my16mhzclk)     my_c_other
============================================================================================================================================
@N: MT582 |Estimated period and frequency not reported for given clock unless the clock has at least one timing path which is not a false or a max delay path and that does not have excessive slack
@W: MT548 :"/home/awhite/Documents/Projects/fpga_led_display/template_syn_1.fdc":18:0:18:0|Source for clock myclk_root not found in netlist. Run the constraint checker to verify if constraints are applied correctly.
@W: MT548 :"/home/awhite/Documents/Projects/fpga_led_display/template_syn_1.fdc":24:0:24:0|Source for clock myclk_matrix not found in netlist. Run the constraint checker to verify if constraints are applied correctly.
@W: MT548 :"/home/awhite/Documents/Projects/fpga_led_display/template_syn_1.fdc":25:0:25:0|Source for clock myclk_debug not found in netlist. Run the constraint checker to verify if constraints are applied correctly.
Clock Relationships
*******************
Clocks                                                    |    rise  to  rise    |    fall  to  fall   |    rise  to  fall    |    fall  to  rise
---------------------------------------------------------------------------------------------------------------------------------------------------
Starting                     Ending                       |  constraint  slack   |  constraint  slack  |  constraint  slack   |  constraint  slack
---------------------------------------------------------------------------------------------------------------------------------------------------
pll|clock_out_derived_clock  pll|clock_out_derived_clock  |  7.575       -6.934  |  7.575       0.824  |  3.658       -6.229  |  3.917       -4.587
===================================================================================================================================================
 Note: 'No paths' indicates there are no paths in the design for that pair of clock edges.
       'Diff grp' indicates that paths exist but the starting clock and ending clock are in different clock groups.
Interface Information
*********************
No IO constraint found
====================================
Detailed Report for Clock: pll|clock_out_derived_clock
====================================
Starting Points with Worst Slack
********************************
                                Starting                                                                    Arrival
Instance                        Reference                       Type        Pin     Net                     Time        Slack
                                Clock
------------------------------------------------------------------------------------------------------------------------------
mydebug.current_position[4]     pll|clock_out_derived_clock     SB_DFFS     Q       current_position[4]     0.796       -6.934
==============================================================================================================================
Ending Points with Worst Slack
******************************
                          Starting                                                                 Required
Instance                  Reference                       Type         Pin     Net                 Time         Slack
                          Clock
----------------------------------------------------------------------------------------------------------------------
mydebug.debug_bits[4]     pll|clock_out_derived_clock     SB_DFFER     D       debug_bits_6[4]     7.420        -6.934
======================================================================================================================
Worst Path Information
***********************
Path information for path number 1:
      Requested Period:                      7.575
    - Setup time:                            0.155
    + Clock delay at ending point:           0.000 (ideal)
    = Required time:                         7.420
    - Propagation time:                      14.354
    - Clock delay at starting point:         0.000 (ideal)
    = Slack (critical) :                     -6.934
    Number of logic level(s):                6
    Starting point:                          mydebug.current_position[4] / Q
    Ending point:                            mydebug.debug_bits[4] / D
    The start point is clocked by            pll|clock_out_derived_clock [rising] on pin C
    The end   point is clocked by            pll|clock_out_derived_clock [rising] on pin C
Instance / Net                                            Pin      Pin               Arrival     No. of
Name                                         Type         Name     Dir     Delay     Time        Fan Out(s)
-----------------------------------------------------------------------------------------------------------
mydebug.current_position[4]                  SB_DFFS      Q        Out     0.796     0.796       -
current_position[4]                          Net          -        -       1.599     -           7
mydebug.current_position_fast_RNI7AGD[3]     SB_LUT4      I0       In      -         2.395       -
mydebug.current_position_fast_RNI7AGD[3]     SB_LUT4      O        Out     0.661     3.056       -
un5_N_5_mux                                  Net          -        -       1.371     -           56
mydebug.debug_bits_RNO_18[4]                 SB_LUT4      I2       In      -         4.427       -
mydebug.debug_bits_RNO_18[4]                 SB_LUT4      O        Out     0.558     4.986       -
debug_bits_RNO_18[4]                         Net          -        -       1.371     -           1
mydebug.debug_bits_RNO_10[4]                 SB_LUT4      I0       In      -         6.357       -
mydebug.debug_bits_RNO_10[4]                 SB_LUT4      O        Out     0.661     7.018       -
debug_bits_RNO_10[4]                         Net          -        -       1.371     -           1
mydebug.debug_bits_RNO_4[4]                  SB_LUT4      I0       In      -         8.389       -
mydebug.debug_bits_RNO_4[4]                  SB_LUT4      O        Out     0.569     8.957       -
debug_bits_2_67_ns_1[6]                      Net          -        -       1.371     -           1
mydebug.debug_bits_RNO_0[4]                  SB_LUT4      I2       In      -         10.329      -
mydebug.debug_bits_RNO_0[4]                  SB_LUT4      O        Out     0.558     10.887      -
N_1013                                       Net          -        -       1.371     -           1
mydebug.debug_bits_RNO[4]                    SB_LUT4      I1       In      -         12.258      -
mydebug.debug_bits_RNO[4]                    SB_LUT4      O        Out     0.589     12.847      -
debug_bits_6[4]                              Net          -        -       1.507     -           1
mydebug.debug_bits[4]                        SB_DFFER     D        In      -         14.354      -
===========================================================================================================
Total path delay (propagation time + setup) of 14.509 is 4.548(31.3%) logic and 9.961(68.7%) route.
Path delay compensated for clock skew. Clock skew is added to clock-to-out value, and is subtracted from setup time value
##### END OF TIMING REPORT #####]