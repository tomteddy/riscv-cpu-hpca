# Define clk as a real clock, 100 MHz (10ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Prevent trimming of memory arrays
set_property KEEP_HIERARCHY yes [get_cells -hierarchical -filter {NAME =~ *imem* || NAME =~ *dmem*}]