CORE_ROOT := $(PWD)

LWCSRC_DIR := $(HW_DIR)/LWCsrc
SCRIPTS_DIR := $(HW_DIR)/scripts

ifeq ($(strip $(USE_DOCKER)),1)
# docker pull ghdl/synth:beta
$(info Using docker for Python3, GHDL, Yosys, and Verilator)
WINPTY := $(shell command -v winpty)

#FIXME this can't be changed now. Mostly due to GHDL (and other simulators?) getting relative path of testvector files
TOOL_RUN_DIR := $(PWD)

DOCKER_CMD = $(WINPTY) docker run --rm -it -v /$(CORE_ROOT):/$(CORE_ROOT) -v /$(LWC_ROOT):/$(LWC_ROOT) -w $(TOOL_RUN_DIR) --security-opt label=disable


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

PYTHON3_BIN = $(DOCKER_CMD) ghdl/synth:beta python3
GHDL_BIN = $(DOCKER_CMD) ghdl/synth:beta ghdl
YOSYS_BIN = $(DOCKER_CMD) ghdl/synth:beta yosys
VERILATOR_BIN = $(DOCKER_CMD) verilator/verilator:4.036
VIVADO_BIN = $(DOCKER_CMD) -e PATH="/opt/Xilinx/Vivado/2019.2/bin:/usr/bin:/bin" --env-file=$(TOOL_RUN_DIR)/docker.env kammoh/vivado vivado
endif

TOP ?= LWC
SOURCE_LIST_FILE ?= $(CORE_ROOT)/source_list.txt
PYTHON3_BIN ?= python3
CONFIG_LOC ?= $(CORE_ROOT)/config.ini


default: help

.DEFAULT: help

.PHONY: FORCE test-config-parser config-vars

## test config parser:
test-config-parser:
	@[ $(shell $(PYTHON3_BIN) $(SCRIPTS_DIR)/config_parser.py test $(CONFIG_LOC)) = OK ] || (echo "Running config_parser.py with python3 failed"; exit 1)


## test config parser:
TEST_CONFIG_PARSER_OK=$(shell $(PYTHON3_BIN) $(SCRIPTS_DIR)/config_parser.py test $(CONFIG_LOC))
ifneq ($(TEST_CONFIG_PARSER_OK),OK)
$(error Running config_parser.py using python3 failed: $(TEST_CONFIG_PARSER_OK))
endif
#######################


# VARS:=$(shell $(PYTHON3_BIN) $(SCRIPTS_DIR)/config_parser.py vars $(CONFIG_LOC)')

## reset
VARS :=

.PHONY: .env

config-vars: test-config-parser FORCE
	$(eval VARS := $(shell $(PYTHON3_BIN) $(SCRIPTS_DIR)/config_parser.py vars $(CONFIG_LOC)))
	#@echo Variables from config.ini:
	#$(file >env,$(VARS))
	@$(foreach v,$(VARS),$(eval $(v)))

.env: config-vars
	@echo "" > $@
	@$(foreach O,$(VARS),echo $O >> $@;)

VHDL_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.vhdl?)
VERILOG_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.s?v | egrep -v .*\.vhdl?)

# expand variables inside `source_list.txt`
$(eval  VHDL_FILES=$(VHDL_FILES))
$(eval  VERILOG_FILES=$(VERILOG_FILES))

VHDL_FILES:=$(realpath $(VHDL_FILES))
VERILOG_FILES:=$(realpath $(VERILOG_FILES))

export VHDL_FILES
export VERILOG_FILES

YOSYS_GHDL_MODULE := -m ghdl

VHDL_STD ?= 93
WORK_LIB ?= work

SIM_TOP = LWC_TB

LWC_TB = $(LWCSRC_DIR)/LWC_TB.vhd
VHDL_ADDITIONS = $(LWCSRC_DIR)/std_logic_1164_additions.vhd

SIM_ONLY_VHDL_FILES := $(VHDL_ADDITIONS) $(LWC_TB) 
SIM_VHDL_FILES = $(VHDL_FILES) $(SIM_ONLY_VHDL_FILES)

ifeq ($(strip $(VERILOG_FILES)),)
YOSYS_READ_VERILOG_CMD := 
else
YOSYS_READ_VERILOG_CMD := read_verilog $(VERILOG_FILES);
endif


# common tool exports
export CLOCK_PERIOD ?= 20.0
export NTHREADS=$(shell nproc)

ifdef REBUILD
FORCE_REBUILD=force_rebuild
endif


force_rebuild:
	@echo "Forcing Rebuild"

.PHONY: force_rebuild default help help-common help-docker

LIGHT_RED = \033[0;31m
GREEN     = \033[0;32m
BROWN     = \033[0;33m
BLUE      = \033[0;34m
PURPLE    = \033[0;35m
CYAN      = \033[0;36m
NO_COLOR  = \033[m

help: help-top help-common help-ghdl help-yosys help-vivado

help-common:
	@printf "%b" "$(CYAN)common variables$(NO_COLOR):\n";
	@echo "set USE_DOCKER=1 to automatically run tools using Docker"
	@echo "\tA functional installation of Docker is required (https://docs.docker.com/config-docker/)"
	@echo "\tDocker deamon needs to be running and the 'docker' executable should be in the PATH"
	@echo "\tTools supported to run under Docker include: Python3, GHDL, Yosys, Verilator, and Vivado"
	@echo
	@echo "set REBUILD=1 to force the rebuild of any tarconfig"
	@echo

help-top:
	@printf "%b" "\n $(PURPLE) \n";
	@cat $(HW_DIR)/makefiles/cerg.ascii
	@printf "%b" "$(NO_COLOR)\n";
	@echo
	@echo LWC Lint, Simulation, and Synthesis Framework
	@echo
	@echo
	@printf "%b" "\n$(LIGHT_RED) Available Tarconfigs:$(NO_COLOR)\n\n";
	@printf "%b" "$(BLUE)* Lint (checking)$(NO_COLOR)\n";
	@printf "%b" "\t - $(GREEN) lint-vhdl $(NO_COLOR) \t\t lint VHDL files using GHDL\n";
	@printf "%b" "\t - $(GREEN) lint-vhdl-synth $(NO_COLOR) \t lint VHDL files using GHDL in synthesis mode\n";
	@printf "%b" "\t - $(GREEN) lint-verilog $(NO_COLOR) \t lint Verilog files using Verilator\n";
	@printf "%b" "\t - $(GREEN) lint-yosys $(NO_COLOR) \t lint full design (VHDL and Verilog) using yosys and ghdl-yosys-plugin \n";
	@printf "%b" "\t - $(GREEN) lint $(NO_COLOR) \t\t lint full design (VHDL and Verilog) using all available linters \n";
	@echo
	@printf "%b" "$(CYAN)* Simulation$(NO_COLOR)\n";
	@printf "%b" "\t - $(GREEN) sim-ghdl $(NO_COLOR) \t\t simulate using GHDL (VHDL only) \n";
	@printf "%b" "\t - $(GREEN) sim-vcs $(NO_COLOR) \t\t simulate using Synopsys VCS (VHDL and Verilog) \n";
	@echo
	@printf "%b" "$(CYAN)* Synthesis$(NO_COLOR)\n";
	@printf "%b" "\t - $(GREEN) synth-dc $(NO_COLOR) \t\t ASIC synthesis using Synopsys Design Compiler \n";
	@printf "%b" "\t - $(GREEN) synth-vivado $(NO_COLOR) \t FPGA synthesis using Xilinx Vivado Design Suite\n";
	@printf "%b" "\t - $(GREEN) synth-yosys-fpga $(NO_COLOR) \t FPGA synthesis using Yosys and GHDL. \n";
	@echo
	@echo

FORCE:  ; 
