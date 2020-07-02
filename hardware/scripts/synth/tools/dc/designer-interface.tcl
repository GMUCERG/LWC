#=========================================================================
# designer-interface.tcl
#=========================================================================
# The designer-interface.tcl file is the first script run by Design
# Compiler. It is the interface that connects the synthesis scripts with
# the following:
#
# - Build system parameters
# - Build system inputs
# - ASIC design kit
#
# Author : Christopher Torng
# Date   : April 8, 2018

#-------------------------------------------------------------------------
# Parameters
#-------------------------------------------------------------------------

set dc_design_name                $::env(DESIGN_NAME)
set dc_clock_period               $::env(CLOCK_PERIOD)
set dc_saif_instance              $::env(SAIF_INSTANCE)
set dc_flatten_effort             $::env(FLATTEN_EFFORT)
set dc_topographical              $::env(TOPOGRAPHICAL)
set dc_num_cores                  $::env(NTHREADS)
set dc_high_effort_area_opt       $::env(HIGH_EFFORT_AREA_OPT)
set dc_gate_clock                 $::env(GATE_CLOCK)
set dc_uniquify_with_design_name  $::env(UNIQUIFY_WITH_DESIGN_NAME)

#-------------------------------------------------------------------------
# Inputs
#-------------------------------------------------------------------------

set adk_dir                     $::env(ADK_DIR)

# Extra libraries
#
# The glob below will capture any libraries collected by the build system
# (e.g., SRAM libraries) generated from steps that synthesis depends on.
#
# To add more link libraries (e.g., IO cells, hierarchical blocks), append
# to the "dc_extra_link_libraries" variable in the pre-synthesis plugin
# like this:
#
#   set dc_extra_link_libraries  [join "
#                                  $dc_extra_link_libraries
#                                  extra1.db
#                                  extra2.db
#                                  extra3.db
#                                "]

set dc_extra_link_libraries     [join "
                                    [glob -nocomplain inputs/*.db]
                                    [glob -nocomplain inputs/adk/*.db]
                                "]

#-------------------------------------------------------------------------
# Interface to the ASIC design kit
#-------------------------------------------------------------------------

set dc_milkyway_ref_libraries   $adk_dir/stdcells.mwlib
set dc_milkyway_tf              $adk_dir/rtk-tech.tf
set dc_tluplus_map              $adk_dir/rtk-tluplus.map
set dc_tluplus_max              $adk_dir/rtk-max.tluplus
set dc_tluplus_min              $adk_dir/rtk-min.tluplus
set dc_adk_tcl                  $adk_dir/adk.tcl
set dc_target_libraries         stdcells.db

# Extra libraries

set dc_additional_search_path   $adk_dir

#-------------------------------------------------------------------------
# Directories
#-------------------------------------------------------------------------

set dc_reports_dir              $::env(DC_REPORTS_DIR)
set dc_results_dir              $::env(DC_RESULTS_DIR)
set dc_alib_dir                 $::env(DC_ALIB_DIR)
