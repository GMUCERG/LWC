set output_dir          $::env(OUTPUT_DIR)
set part                $::env(FPGA_PART)
set top_module_name     $::env(DESIGN_NAME)
set synth_options       [split $::env(SYNTH_OPTIONS)]
set opt_options         [split $::env(OPT_OPTIONS)]
set place_options       [split $::env(PLACE_OPTIONS)]
set route_options       [split $::env(ROUTE_OPTIONS)]
set phys_opt_options    [split $::env(PYS_OPT_OPTIONS)]

set verilog_files       $::env(VERILOG_FILES)
set vhdl_files          $::env(VHDL_FILES)
set clock_period        $::env(CLOCK_PERIOD)


set reports_dir         ${output_dir}/reports
set results_dir         ${output_dir}/reports
set checkpoints_dir     ${output_dir}/checkpoints