# Vivado Simulation Script using project mode
#
# To run:
# 1. create a run directory (e.g. vivado_run) inside hardware/dummy_lwc: 
#    mkdir vivado_run
# 2. cd vivado_run
# 3. vivado -mode batch -source ../scripts/vivado.tcl
#

set RTL_SRC_DIR "../src_rtl/v1"
set TB_SRC_DIR "../src_tb"

set KAT_PATH "[pwd]/../KAT/v1"

set TOP_LEVEL_NAME LWC_TB

# ----------------------------------------
# Set RTL source files
set RTL_SRCS [glob -type f [subst "$RTL_SRC_DIR/*.vhd"]]
append RTL_SRCS " [glob -type f [subst "$RTL_SRC_DIR/LWC/*.vhd"]]"


# ----------------------------------------
# Set simulation source files
set TB_SRCS [glob -type f [subst "$TB_SRC_DIR/LWC/*.vhd"]]

create_project -force "prj_$TOP_LEVEL_NAME"
add_files -fileset sources_1 {*}$RTL_SRCS


add_files -fileset sim_1 {*}$TB_SRCS
set_property top $TOP_LEVEL_NAME [current_fileset]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top $TOP_LEVEL_NAME [current_fileset]

set_property generic [subst {
   G_FNAME_DO="$KAT_PATH/do.txt"
   G_FNAME_PDI="$KAT_PATH/pdi.txt"
   G_FNAME_SDI="$KAT_PATH/sdi.txt"
}] [get_filesets sim_1]

launch_simulation
run -all
