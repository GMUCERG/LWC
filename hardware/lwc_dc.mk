
SYNTH_FRAMEWORK_ROOT=$(realpath $(LWC_ROOT)/scripts/synth)


DC_CMD ?= dc_shell-xg-t -64bit -topographical_mode
DC_START_TCL=$(SYNTH_FRAMEWORK_ROOT)/tools/dc/dc-start.tcl


# configurable variables
# see hardware/scripts/synth/tools/dc/compile-options.tcl
# .EXPORT_ALL_VARIABLES:
export ADK_DIR ?= $(SYNTH_FRAMEWORK_ROOT)/adk/freepdk-45nm/
$(info ADK_DIR=$(ADK_DIR))
export CLOCK_PERIOD ?= 2.0
$(info Target frequency: $(shell echo 1000.0/${CLOCK_PERIOD} | bc) MHz)
export HIGH_EFFORT_AREA_OPT ?= True
$(info HIGH_EFFORT_AREA_OPT=$(HIGH_EFFORT_AREA_OPT))
export FLATTEN_EFFORT ?= 3
$(info FLATTEN_EFFORT=$(FLATTEN_EFFORT))
export GATE_CLOCK ?= True
$(info GATE_CLOCK=$(GATE_CLOCK))

DC_LOGS_DIR ?= logs
$(info Logs will be written to "$(DC_RESULTS_DIR)")
export DC_RESULTS_DIR ?= $(CORE_ROOT)/results
$(info Synthesis artefacts will be stored in "$(DC_RESULTS_DIR)")
export DC_REPORTS_DIR ?= $(CORE_ROOT)/reports
$(info Reports will be stored in "$(DC_REPORTS_DIR)")
export DC_ALIB_DIR ?= $(CORE_ROOT)/alib
$(info ALIB directory is "$(DC_ALIB_DIR)")

########################################

export TOPOGRAPHICAL=True
export UNIQUIFY_WITH_DESIGN_NAME=True
export DESIGN_NAME=$(TOP)
export SAIF_INSTANCE=undefined
export NTHREADS=$(shell nproc)

$(DC_LOGS_DIR):
	mkdir -p $@

$(DC_RESULTS_DIR):
	mkdir -p $@

$(DC_REPORTS_DIR):
	mkdir -p $@

synth-dc: $(DC_LOGS_DIR) $(DC_RESULTS_DIR) $(DC_REPORTS_DIR) $(VERILOG_FILES) $(VHDL_FILES)
	$(DC_CMD) -f $(DC_START_TCL) -output_log_file $(DC_LOGS_DIR)/dc.log

clean-dc:
	@rm -rf $(DC_LOGS_DIR) $(DC_RESULTS_DIR) $(DC_REPORTS_DIR) $(DC_ALIB_DIR)