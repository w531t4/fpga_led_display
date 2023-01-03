# ##############################################################################

# iCEcube SDC

# Version:            2017.08.27940

# File Generated:     Mar 18 2019 13:15:42

# ##############################################################################

####---- CreateClock list ----1
create_clock  -period 62.50 -name {pin3_clk_16mhz} [get_ports {pin3_clk_16mhz}] 
#derive_pll_clocks
#derive_clock_uncertainty
####---- CreateGenClock list ----2  {main|clk_root_derived_clock}]
#create_generated_clock -name {U0|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
#    -source [get_pins {U0|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|vco0ph[0]}]
#    -duty_cycle 50.000 -multiply_by 1 -divide_by 10
#    -master_clock {U0|pll|altera_pll_i|general[0].gpll~FRACTIONAL_PLL|vcoph[0]}
#    [get_pins {U0|pll|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
#create_generated_clock -name {myclk_debug} -source [get_nets {clk_root}] -divide_by 67000000 -master_clock [get_ports {pin3_clk_16mhz}]  [get_nets {mydebug.clk_debug}]
#create_generated_clock -name {myclk_uart_rx} -source [get_nets {clk_root}] -divide_by 25 -master_clock [get_ports {pin3_clk_16mhz}]  [get_nets {ctrl.urx.clkdiv_baudrate.clk_out}]
#create_generated_clock -name {myclk_matrix} -source [get_nets {clk_root}] -divide_by 3 -master_clock [get_ports {pin3_clk_16mhz}]  [get_nets {clkdiv_matrix.clk_out}]
#n:ctrl.timeout_cmd_line_write.un68_running
