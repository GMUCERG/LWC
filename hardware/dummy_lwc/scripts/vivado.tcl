set INTERFACE_REPO "../../LWCsrc"
set CORE_SRC_DIR "../src_rtl"


set TOP_LEVEL_NAME LWC_TB

# Set implementation files
set CORE_VHDL_SRCS [glob -type f [subst "$CORE_SRC_DIR/*.vhd"]]

set INTERFACE_SRCS [subst {
    "$INTERFACE_REPO/NIST_LWAPI_pkg.vhd"
    "$INTERFACE_REPO/StepDownCountLd.vhd"
    "$INTERFACE_REPO/data_piso.vhd"
    "$INTERFACE_REPO/key_piso.vhd"
    "$INTERFACE_REPO/data_sipo.vhd"
    "$INTERFACE_REPO/PreProcessor.vhd"
    "$INTERFACE_REPO/PostProcessor.vhd"
    "$INTERFACE_REPO/fwft_fifo.vhd"
    "$INTERFACE_REPO/LWC.vhd"
}]

set VHDL_SRCS [concat $CORE_VHDL_SRCS $INTERFACE_SRCS]



# ----------------------------------------
# Set simulation files
set VHDL_TB_SRCS [subst {
    "$INTERFACE_REPO/std_logic_1164_additions.vhd"
    "$INTERFACE_REPO/$TOP_LEVEL_NAME.vhd"
}]

create_project -force "prj_$TOP_LEVEL_NAME"
add_files -fileset sources_1 {*}$VHDL_SRCS
add_files -fileset sim_1 {*}$VHDL_TB_SRCS

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
