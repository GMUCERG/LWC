
SYNTH_FRAMEWORK_ROOT=$(realpath $(LWC_ROOT)/scripts/synth)

VIVADO_RUN_TCL=$(SYNTH_FRAMEWORK_ROOT)/tools/vivado/run.tcl

################################################################################
# User configurable variables
################################################################################
FPGA_PART ?= xc7a100tcsg324-1
SYNTH_OPTIONS ?= -assert -flatten_hierarchy rebuilt -retiming -directive AreaOptimized_medium
OPT_OPTIONS ?= -directive ExploreWithRemap # extra optimization pass
PLACE_OPTIONS ?= -directive Default
ROUTE_OPTIONS ?= -directive Default
PYS_OPT_OPTIONS ?= -directive Default
VIVADO_BIN ?= vivado
################################################################################

.PHONY: synth-vivado clean-vivado help-vivado $(FPGA_PART) $(SYNTH_OPTIONS) $(CLOCK_PERIOD) $(TOOL_RUN_DIR)/docker.env

VIVADO_CMD=$(VIVADO_BIN) -mode batch -nojournal -notrace -source $(VIVADO_RUN_TCL)

VIVADO_OUTPUT_DIR=vivado

$(TOOL_RUN_DIR)/docker.env : $(TOOL_RUN_DIR) $(VERILOG_FILES) $(VHDL_FILES) $(FPGA_PART) $(SYNTH_OPTIONS) $(CLOCK_PERIOD) config-vars
	@echo OUTPUT_DIR=$(VIVADO_OUTPUT_DIR) > $@
	@echo FPGA_PART=$(FPGA_PART) >> $@
	@echo SYNTH_OPTIONS=$(SYNTH_OPTIONS) >> $@
	@echo OPT_OPTIONS=$(OPT_OPTIONS) >> $@
	@echo PLACE_OPTIONS=$(PLACE_OPTIONS) >> $@
	@echo ROUTE_OPTIONS=$(ROUTE_OPTIONS) >> $@
	@echo PYS_OPT_OPTIONS=$(PYS_OPT_OPTIONS) >> $@
	@echo VERILOG_FILES=$(VERILOG_FILES) >> $@
	@echo VHDL_FILES=$(VHDL_FILES) >> $@
	@echo DESIGN_NAME=$(TOP) >> $@
	@echo CLOCK_PERIOD=$(CLOCK_PERIOD) >> $@

synth-vivado: $(TOOL_RUN_DIR)/docker.env $(VERILOG_FILES) $(VHDL_FILES) $(TOOL_RUN_DIR)/docker.env
	cd $(TOOL_RUN_DIR) && $(VIVADO_CMD)

help-vivado:
	@printf "%b" "$(CYAN)synth-vivado variables$(NO_COLOR):\n";
	@printf "%b" "FPGA_PART \t Target FPGA part identifier \n";
	@printf "%b" "CLOCK_PERIOD \t Target clock period in 'ns' \n";
	@printf "%b" "SYNTH_OPTIONS \t Synthesis options \n";
	@printf "%b" "OPT_OPTIONS \t Optimization options \n";
	@printf "%b" "PYS_OPT_OPTIONS  Physical optimization options \n";
	@printf "%b" "PLACE_OPTIONS \t Placing options \n";
	@printf "%b" "ROUTE_OPTIONS \t Routing options \n";
	@echo

clean-vivado:
	@rm -rf $(TOOL_RUN_DIR)/$(VIVADO_OUTPUT_DIR)/reports $(TOOL_RUN_DIR)/$(VIVADO_OUTPUT_DIR)/results $(TOOL_RUN_DIR)/$(VIVADO_OUTPUT_DIR)/checkpoints_dir 