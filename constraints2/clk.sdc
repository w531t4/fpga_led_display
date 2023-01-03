# ##############################################################################

# iCEcube SDC

# Version:            2017.08.27940

# File Generated:     Feb 28 2019 21:53:35

# ##############################################################################

####---- CreateClock list ----1
create_clock  -period 62.50 -name {pin3_clk_16mhz} [get_ports {pin3_clk_16mhz}] 

####---- CreateGenClock list ----1
create_generated_clock  [get_nets {clk_root_0_g}]  -source [get_ports {pin3_clk_16mhz}]  -name {clk_root_0_g} 

