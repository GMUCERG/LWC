
SYNTH_FRAMEWORK_ROOT=$(realpath $(LWC_ROOT)/hardware/scripts/synth)

DC_CMD ?= dc_shell-xg-t -64bit -topographical_mode
DC_START_TCL=$(SYNTH_FRAMEWORK_ROOT)/tools/dc/run.tcl

# configurable variables
# see hardware/scripts/synth/tools/dc/compile-options.tcl
# .EXPORT_ALL_VARIABLES:
export ADK_DIR ?= $(SYNTH_FRAMEWORK_ROOT)/adk/freepdk-45nm/
export HIGH_EFFORT_AREA_OPT ?= True
export FLATTEN_EFFORT ?= 3
export GATE_CLOCK ?= True

DC_LOGS_DIR ?= logs
export DC_RESULTS_DIR ?= $(CORE_ROOT)/results
export DC_REPORTS_DIR ?= $(CORE_ROOT)/reports
export DC_ALIB_DIR ?= $(CORE_ROOT)/alib

########################################

export TOPOGRAPHICAL=True
export UNIQUIFY_WITH_DESIGN_NAME=True
export TOP
export SAIF_INSTANCE=undefined

$(DC_LOGS_DIR):
	mkdir -p $@

$(DC_RESULTS_DIR):
	mkdir -p $@

$(DC_REPORTS_DIR):
	mkdir -p $@

.PHONY: synth-dc clean-dc help-dc
synth-dc: $(DC_LOGS_DIR) $(DC_RESULTS_DIR) $(DC_REPORTS_DIR) $(VERILOG_FILES) $(VHDL_FILES)
	$(info ADK_DIR=$(ADK_DIR))
	$(info Target frequency: $(shell echo 1000.0/${CLOCK_PERIOD} | bc) MHz)
	$(info HIGH_EFFORT_AREA_OPT=$(HIGH_EFFORT_AREA_OPT))
	$(info FLATTEN_EFFORT=$(FLATTEN_EFFORT))
	$(info GATE_CLOCK=$(GATE_CLOCK))
	$(info Logs will be written to "$(DC_RESULTS_DIR)")
	$(info Synthesis artefacts will be stored in "$(DC_RESULTS_DIR)")
	$(info Reports will be stored in "$(DC_REPORTS_DIR)")
	$(info ALIB directory is "$(DC_ALIB_DIR)")
	$(DC_CMD) -f $(DC_START_TCL) -output_log_file $(DC_LOGS_DIR)/dc.log

clean-dc:
	@rm -rf $(DC_LOGS_DIR) $(DC_RESULTS_DIR) $(DC_REPORTS_DIR) $(DC_ALIB_DIR)
