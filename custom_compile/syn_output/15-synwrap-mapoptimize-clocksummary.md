@S |Clock Optimization Summary
#### START OF CLOCK OPTIMIZATION REPORT #####[
0 non-gated/non-generated clock tree(s) driving 0 clock pin(s) of sequential element(s)
2 gated/generated clock tree(s) driving 561 clock pin(s) of sequential element(s)
0 instances converted, 561 sequential instances remain driven by gated/generated clocks
================================================================================================================================ Gated/Generated Clocks ================================================================================================================================
Clock Tree ID     Driving Element      Drive Element Type     Fanout     Sample Instance                                                                  Explanation
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
@K:CKID0001       fb.clk_a_and_0       SB_LUT4                48         fb.mpram_ins_p2.genblk1.mrram_ins.RPORTrpi[0].dpram_i.dpram_inst.mem_mem_1_3     No gated clock conversion method for cell cell:sb_ice.SB_RAM2048x2
@K:CKID0002       new_pll_inst.uut     SB_PLL40_CORE          513        sync_fifo[0]                                                                     Gating structure creates improper gating logic. See the Gated Clocks description in the user guide for conversion requirements
========================================================================================================================================================================================================================================================================================
##### END OF CLOCK OPTIMIZATION REPORT ######]
Start Writing Netlists (Real Time elapsed 0h:00m:03s; CPU Time elapsed 0h:00m:03s; Memory used current: 132MB peak: 162MB)
Writing Analyst data base /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/synwork/template_m.srm
Finished Writing Netlist Databases (Real Time elapsed 0h:00m:03s; CPU Time elapsed 0h:00m:03s; Memory used current: 159MB peak: 162MB)
Writing EDIF Netlist and constraint files
@N: BW103 |The default time unit for the Synopsys Constraint File (SDC or FDC) is 1ns.
@N: BW107 |Synopsys Constraint File capacitance units using default value of 1pF
@W: BW156 :"/home/awhite/Documents/Projects/fpga_led_display/template_syn_1.fdc":20:0:20:0|Option "-name" of set_clock_groups cannot be forward-annotated; there is no equivalent option in your place-and-route tool.
@N: FX1056 |Writing EDF file: /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/template.edf
L-2016.09L+ice40
Finished Writing EDIF Netlist and constraint files (Real Time elapsed 0h:00m:04s; CPU Time elapsed 0h:00m:04s; Memory used current: 160MB peak: 163MB)
Start final timing analysis (Real Time elapsed 0h:00m:04s; CPU Time elapsed 0h:00m:04s; Memory used current: 158MB peak: 163MB)
@N: MT615 |Found clock my16mhzclk with period 62.50ns
@N: MT615 |Found clock pll|clock_out_derived_clock with period 7.58ns