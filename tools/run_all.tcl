# ============================================================
# run_all.tcl — sweep all benchmarks × all configs.
#
# Invoke from the project root in Vivado Tcl console:
#     source tools/run_all.tcl
# Or batch mode:
#     vivado -mode batch -source tools/run_all.tcl hpca_riscv.xpr
#
# Prerequisites:
#   - All benchmarks built: tools\build_all.bat
#   - results.csv may exist; new rows are appended.
#
# What it does, per (config × benchmark):
#   1. Sets the simulation top + USE_BTB generic.
#   2. Copies tests\<bench>.{instructions,data}.hex to working dir.
#   3. Launches xsim, runs to $finish, closes.
#   4. The TB appends one row to results.csv.
#
# Total: 3 configs × 9 benchmarks = 27 runs (~5–10 minutes).
# ============================================================

set benchmarks {
    fib_20
    dotprod_16
    dotprod_16_nocustom
    matmul_8x8
    matmul_8x8_nocustom
    relu_32
    relu_32_nocustom
    grad_descent
    grad_descent_nocustom
}

# {label, top_module, generic_string_or_empty}
set configs {
    {single_cycle    tb_cpu_top_sc_rdcyc    {}}
    {pipeline_btb    tb_cpu_top_mext_rdcyc  {USE_BTB=1}}
    {pipeline_nobtb  tb_cpu_top_mext_rdcyc  {USE_BTB=0}}
}

# Sim working directory (where instructions.hex/data.hex are read from
# and where results.csv lands). Vivado's default xsim launch dir is:
#   <project>.sim/sim_1/behav/xsim
# We resolve it dynamically below.
set sim_dir [get_property DIRECTORY [current_project]]
set xsim_dir [file join $sim_dir [get_property NAME [current_project]].sim sim_1 behav xsim]

puts "================================================================"
puts " run_all.tcl — sim working dir: $xsim_dir"
puts "================================================================"

foreach cfg $configs {
    lassign $cfg cfg_name top_mod generic

    puts ""
    puts "================================================================"
    puts " CONFIG: $cfg_name  (top=$top_mod  generic=$generic)"
    puts "================================================================"

    set_property top $top_mod [get_filesets sim_1]
    if {$generic ne ""} {
        set_property -name {xsim.elaborate.xelab.more_options} \
                     -value "-generic_top \"$generic\"" \
                     -objects [get_filesets sim_1]
    } else {
        set_property -name {xsim.elaborate.xelab.more_options} \
                     -value {} \
                     -objects [get_filesets sim_1]
    }

    foreach bench $benchmarks {
        puts ""
        puts "---- $cfg_name / $bench ----"

        # Make sure xsim dir exists (first launch creates it)
        file mkdir $xsim_dir

        set src_i [file join tests "$bench.instructions.hex"]
        set src_d [file join tests "$bench.data.hex"]
        set dst_i [file join $xsim_dir "instructions.hex"]
        set dst_d [file join $xsim_dir "data.hex"]

        if {![file exists $src_i]} {
            puts "SKIP: $src_i not found (run tools\\build_all.bat first)"
            continue
        }
        file copy -force $src_i $dst_i
        if {[file exists $src_d]} { file copy -force $src_d $dst_d }

        # Launch (or relaunch) the simulator
        if {[catch {close_sim -quiet}]} {}
        launch_simulation
        run all
        close_sim -quiet
    }
}

puts ""
puts "================================================================"
puts " DONE. Results appended to: $xsim_dir/results.csv"
puts "================================================================"
