"/home/awhite/lscc/iCEcube2.2020.12/sbt_backend/bin/linux/opt/sbtplacer" --des-lib "/home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/netlist/oadb-main" --outdir "/home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/outputs/placer" --device-file "/home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ICE40P08.dev" --package CM81 --deviceMarketName iCE40LP8K --sdc-file "/home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/Temp/sbt_temp.sdc" --lib-file "/home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ice40LP8K.lib" --effort_level std --out-sdc-file "/home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/outputs/placer/main_pl.sdc"
Executing : /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/bin/linux/opt/sbtplacer --des-lib /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/netlist/oadb-main --outdir /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/outputs/placer --device-file /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ICE40P08.dev --package CM81 --deviceMarketName iCE40LP8K --sdc-file /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/Temp/sbt_temp.sdc --lib-file /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ice40LP8K.lib --effort_level std --out-sdc-file /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/outputs/placer/main_pl.sdc
Lattice Semiconductor Corporation  Placer
Release:        2020.12.27943
Build Date:     Dec 10 2020 17:43:13
I2004: Option and Settings Summary
=============================================================
Device file          - /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ICE40P08.dev
Package              - CM81
Design database      - /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/netlist/oadb-main
SDC file             - /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/Temp/sbt_temp.sdc
Output directory     - /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/outputs/placer
Timing library       - /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ice40LP8K.lib
Effort level         - std
I2050: Starting reading inputs for placer
=============================================================
I2100: Reading design library: /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/sbt/netlist/oadb-main/BFPGA_DESIGN_ep
I2065: Reading device file : /home/awhite/lscc/iCEcube2.2020.12/sbt_backend/devices/ICE40P08.dev
I2051: Reading of inputs for placer completed successfully
I2053: Starting placement of the design
=============================================================
Input Design Statistics
    Number of LUTs      	:	674
    Number of DFFs      	:	513
    Number of DFFs packed to IO	:	0
    Number of Carrys    	:	116
    Number of RAMs      	:	24
    Number of ROMs      	:	0
    Number of IOs       	:	26
    Number of GBIOs     	:	0
    Number of GBs       	:	6
    Number of WarmBoot  	:	0
    Number of PLLs      	:	1
Phase 1
I2077: Start design legalization
Design Legalization Statistics
    Number of feedthru LUTs inserted to legalize input of DFFs     	:	231
    Number of feedthru LUTs inserted for LUTs driving multiple DFFs	:	0
    Number of LUTs replicated for LUTs driving multiple DFFs       	:	36
    Number of feedthru LUTs inserted to legalize output of CARRYs  	:	44
    Number of feedthru LUTs inserted to legalize global signals    	:	0
    Number of feedthru CARRYs inserted to legalize input of CARRYs 	:	0
    Number of inserted LUTs to Legalize IOs with PIN_TYPE= 01xxxx  	:	0
    Number of inserted LUTs to Legalize IOs with PIN_TYPE= 10xxxx  	:	0
    Number of inserted LUTs to Legalize IOs with PIN_TYPE= 11xxxx  	:	0
    Total LUTs inserted                                            	:	311
    Total CARRYs inserted                                          	:	0
I2078: Design legalization is completed successfully
I2088: Phase 1, elapsed time : 0.0 (sec)
Phase 2
I2088: Phase 2, elapsed time : 0.0 (sec)
Phase 3
Info-1404: Inferred PLL generated clock at new_pll_inst.uut/PLLOUTCORE
Info-1404: Inferred PLL generated clock at new_pll_inst.uut/PLLOUTGLOBAL
Design Statistics after Packing
    Number of LUTs      	:	986
    Number of DFFs      	:	513
    Number of DFFs packed to IO	:	0
    Number of Carrys    	:	120
Device Utilization Summary after Packing
    Sequential LogicCells
        LUT and DFF      	:	481
        LUT, DFF and CARRY	:	32
    Combinational LogicCells
        Only LUT         	:	429
        CARRY Only       	:	44
        LUT with CARRY   	:	44
    LogicCells                  :	1030/7680
    PLBs                        :	143/960
    BRAMs                       :	24/32
    IOs and GBIOs               :	26/63
    PLLs                        :	1/1
I2088: Phase 3, elapsed time : 1.4 (sec)
Phase 4
I2088: Phase 4, elapsed time : 0.2 (sec)
Phase 5
I2088: Phase 5, elapsed time : 4.2 (sec)
Phase 6
I2088: Phase 6, elapsed time : 58.9 (sec)
Final Design Statistics
    Number of LUTs      	:	986
    Number of DFFs      	:	513
    Number of DFFs packed to IO	:	0
    Number of Carrys    	:	120
    Number of RAMs      	:	24
    Number of ROMs      	:	0
    Number of IOs       	:	26
    Number of GBIOs     	:	0
    Number of GBs       	:	6
    Number of WarmBoot  	:	0
    Number of PLLs      	:	1
Device Utilization Summary
    LogicCells                  :	1030/7680
    PLBs                        :	236/960
    BRAMs                       :	24/32
    IOs and GBIOs               :	26/63
    PLLs                        :	1/1
#####################################################################
Placement Timing Summary
The timing summary is based on estimated routing delays after
placement. For final timing report, please carry out the timing
analysis after routing.
=====================================================================
#####################################################################
                     Clock Summary
=====================================================================
Number of clocks: 3
Clock: my16mhzclk | Frequency: N/A | Target: 16.00 MHz
Clock: new_pll_inst.uut/PLLOUTCORE | Frequency: 40.54 MHz | Target: 132.00 MHz
Clock: new_pll_inst.uut/PLLOUTGLOBAL | Frequency: N/A | Target: 132.00 MHz
=====================================================================
                     End of Clock Summary
#####################################################################
I2054: Placement of design completed successfully
I2076: Placer run-time: 65.4 sec.