set CHILD_SCRIPTS_DIR [file dirname [info script]]

source -echo ${CHILD_SCRIPTS_DIR}/designer-interface.tcl
source -echo ${CHILD_SCRIPTS_DIR}/setup-session.tcl

# print name of loaded libraries
# foreach lib_name  [get_attribute [get_libs ] name] {
#   puts $lib_name
# }

source -echo ${CHILD_SCRIPTS_DIR}/read-design.tcl
source -echo ${CHILD_SCRIPTS_DIR}/constraints.tcl
source -echo ${CHILD_SCRIPTS_DIR}/make-path-groups.tcl
source -echo ${CHILD_SCRIPTS_DIR}/compile-options.tcl
source -echo ${CHILD_SCRIPTS_DIR}/compile.tcl
source -echo ${CHILD_SCRIPTS_DIR}/generate-results.tcl
source -echo ${CHILD_SCRIPTS_DIR}/reporting.tcl


puts "=== DC synthesis successfully completed ==="


# for computing gate-equivalent
set ADK_NAND2_AREA [get_attribute ${ADK_LIB_NAME}/${ADK_NAND2_GATE} area]
puts "Area of NAND2 gate is: $ADK_NAND2_AREA"

exit
