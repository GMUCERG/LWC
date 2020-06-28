set CHILD_SCRIPTS_DIR [file dirname [info script]]

source ${CHILD_SCRIPTS_DIR}/designer-interface.tcl
source ${CHILD_SCRIPTS_DIR}/setup-session.tcl
source ${CHILD_SCRIPTS_DIR}/read-design.tcl
source ${CHILD_SCRIPTS_DIR}/constraints.tcl
source ${CHILD_SCRIPTS_DIR}/make-path-groups.tcl
source ${CHILD_SCRIPTS_DIR}/compile-options.tcl
source ${CHILD_SCRIPTS_DIR}/compile.tcl
source ${CHILD_SCRIPTS_DIR}/generate-results.tcl
source ${CHILD_SCRIPTS_DIR}/reporting.tcl

exit
