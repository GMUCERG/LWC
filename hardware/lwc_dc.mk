# .EXPORT_ALL_VARIABLES:

## FIXME hardcoded in TCL
LOGS_DIR=logs
RESULTS_DIR=results
RESULTS_DIR=reports

SYNTH_FRAMEWORK_ROOT=$(realpath $(PWD)/../../scripts/synth)

# configurable variables
DC_CMD ?= dc_shell-xg-t -64bit -topographical_mode
ADK_DIR ?= $(SYNTH_FRAMEWORK_ROOT)/adk/freepdk-45nm/
CLOCK_PERIOD ?= 2.0


##################

DC_START_TCL=$(SYNTH_FRAMEWORK_ROOT)/tools/dc/dc-start.tcl


export design_name=$(TOP)
export clock_period=$(CLOCK_PERIOD)
export high_effort_area_opt=True
export topographical=True
export flatten_effort=3
export saif_instance=undefined
export nthreads=8
export gate_clock=True
export uniquify_with_design_name=True
export adk_dir=$(realpath $(ADK_DIR))

$(LOGS_DIR):
	mkdir -p $@

$(RESULTS_DIR):
	mkdir -p $@

$(REPORTS_DIR):
	mkdir -p $@

synth-dc: $(LOGS_DIR) $(RESULTS_DIR) $(REPORTS_DIR) $(VERILOG_FILES) $(VHDL_FILES)
	$(DC_CMD) -f $(DC_START_TCL) -output_log_file $(LOGS_DIR)/dc.log
