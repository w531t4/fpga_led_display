"/home/awhite/lscc/iCEcube2.2020.12/sbt_backend/bin/linux/opt/synpwrap/synpwrap" -prj "template_syn.prj" -log "template_Implmnt/template.srr"
Running in Lattice mode
Starting:    /home/awhite/lscc/iCEcube2.2020.12/synpbase/linux_a_64/mbin/synbatch
Install:     /home/awhite/lscc/iCEcube2.2020.12/synpbase
Hostname:    otherbarry
Date:        Wed Jan  4 09:32:54 2023
Version:     L-2016.09L+ice40
Arguments:   -product synplify_pro -batch template_syn.prj
ProductType: synplify_pro
auto_infer_blackbox is not supported in current product.
log file: "/home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/template.srr"
Running: template_Implmnt in foreground
Running template_syn|template_Implmnt
Running: compile (Compile) on template_syn|template_Implmnt
# Wed Jan  4 09:32:54 2023
Running: compile_flow (Compile Process) on template_syn|template_Implmnt
# Wed Jan  4 09:32:54 2023
Running: compiler (Compile Input) on template_syn|template_Implmnt
# Wed Jan  4 09:32:54 2023
Copied /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/synwork/template_comp.srs to /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/template.srs
compiler completed
# Wed Jan  4 09:32:56 2023
Return Code: 0
Run Time:00h:00m:02s
Running: multi_srs_gen (Multi-srs Generator) on template_syn|template_Implmnt
# Wed Jan  4 09:32:56 2023
multi_srs_gen completed
# Wed Jan  4 09:32:56 2023
Return Code: 0
Run Time:00h:00m:00s
Copied /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/synwork/template_mult.srs to /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/template.srs
Complete: Compile Process on template_syn|template_Implmnt
Running: premap (Pre-mapping) on template_syn|template_Implmnt
# Wed Jan  4 09:32:56 2023
premap completed with warnings
# Wed Jan  4 09:32:56 2023
Return Code: 1
Run Time:00h:00m:00s
Complete: Compile on template_syn|template_Implmnt
Running: map (Map) on template_syn|template_Implmnt
# Wed Jan  4 09:32:56 2023
License granted for 4 parallel jobs
Running: fpga_mapper (Map & Optimize) on template_syn|template_Implmnt
# Wed Jan  4 09:32:56 2023
Copied /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/synwork/template_m.srm to /home/awhite/Documents/Projects/fpga_led_display/template_Implmnt/template.srm
fpga_mapper completed with warnings
# Wed Jan  4 09:33:01 2023
Return Code: 1
Run Time:00h:00m:05s
Complete: Map on template_syn|template_Implmnt
Complete: Logic Synthesis on template_syn|template_Implmnt
exit status=0
exit status=0
Copyright (C) 1992-2014 Lattice Semiconductor Corporation. All rights reserved.
Child process exit with 0.
