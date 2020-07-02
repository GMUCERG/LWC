ifndef LWC_ROOT
$(error LWC_ROOT must be defined in design-specific Makefile)
endif

LWC_ROOT := $(realpath $(LWC_ROOT))

CORE_ROOT := $(PWD)

LWCSRC_DIR := $(LWC_ROOT)/LWCsrc
SCRIPTS_DIR := $(LWC_ROOT)/scripts

ifneq ($(strip $(USE_DOCKER)),)
# docker pull ghdl/synth:beta
$(info Using docker for Python3, GHDL, Yosys, and Verilator)
DOCKER_CMD := $(shell command -v winpty) docker run --rm -it -v /$(CORE_ROOT):/$(CORE_ROOT) -v /$(LWC_ROOT):/$(LWC_ROOT) -v /$(PWD):/cwd -w /$(CORE_ROOT)

PYTHON3_BIN := $(DOCKER_CMD) ghdl/synth:beta python3
GHDL_BIN := $(DOCKER_CMD) ghdl/synth:beta ghdl
YOSYS_BIN := $(DOCKER_CMD) ghdl/synth:beta yosys
VERILATOR_BIN := $(DOCKER_CMD) verilator/verilator:4.036
endif

TOP ?= LWC
SOURCE_LIST_FILE ?= $(CORE_ROOT)/source_list.txt
PYTHON3_BIN ?= python3

## test config parser:
TEST_CONFIG_PARSER_OK=$(shell $(PYTHON3_BIN) $(SCRIPTS_DIR)/config_parser.py test)
ifneq ($(TEST_CONFIG_PARSER_OK),OK)
$(error config_parser.py failed: $(TEST_CONFIG_PARSER_OK))
endif
#######################


VHDL_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.vhdl?)
VERILOG_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.s?v | egrep -v .*\.vhdl?)

# expand variables inside `source_list.txt`
$(eval  VHDL_FILES=$(VHDL_FILES))
$(eval  VERILOG_FILES=$(VERILOG_FILES))

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


.PHONY: default help help-common help-docker help-ghdl	help-yosys
default: help

CERG_COLOR  = \033[0;35m
COM_COLOR   = \033[0;34m
OBJ_COLOR   = \033[0;36m
OK_COLOR    = \033[0;32m
ERROR_COLOR = \033[0;31m
WARN_COLOR  = \033[0;33m
NO_COLOR    = \033[m

help: help-common help-docker help-ghdl	help-yosys

help-docker:
	@echo
	@echo "set USE_DOCKER=1 to automatically run commands (Python3, GHDL, Yosys, Verilator) using Docker"
	@echo "Docker (https://docs.docker.com/get-docker/) needs to be installed"
	@echo
	@echo

help-common:
	@printf "%b" "\n $(CERG_COLOR) \n";
	@cat $(LWC_ROOT)/cerg.ascii
	@printf "%b" "$(NO_COLOR)\n";
	@echo
	@echo LWC Lint, Simulation, and Synthesis Framework
	@echo
	@echo
	@printf "%b" "\n $(ERROR_COLOR)Available Targets:$(NO_COLOR)\n\n";
	@printf "%b" "$(OBJ_COLOR)* Lint (checking)$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) lint-vhdl $(NO_COLOR) \t\t lint VHDL files using GHDL\n";
	@printf "%b" "\t - $(OK_COLOR) lint-vhdl-synth $(NO_COLOR) \t lint VHDL files using GHDL in synthesis mode\n";
	@printf "%b" "\t - $(OK_COLOR) lint-verilog $(NO_COLOR) \t lint Verilog files using Verilator\n";
	@printf "%b" "\t - $(OK_COLOR) lint-yosys $(NO_COLOR) \t lint full design (VHDL and Verilog) using yosys and ghdl-yosys-plugin \n";
	@printf "%b" "\t - $(OK_COLOR) lint $(NO_COLOR) \t\t lint full design (VHDL and Verilog) using all available linters \n";
	@echo
	@printf "%b" "$(OBJ_COLOR)* Simulation$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) sim-ghdl $(NO_COLOR) \t\t simulate using GHDL (VHDL only) \n";
	@printf "%b" "\t - $(OK_COLOR) sim-vcs $(NO_COLOR) \t\t simulate using Synopsys VCS (VHDL and Verilog) \n";
	@echo
	@printf "%b" "$(OBJ_COLOR)* Synthesis$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) synth-dc $(NO_COLOR) \t\t ASIC synthesis using Synopsys Design Compiler \n";
	@printf "%b" "\t - $(OK_COLOR) synth-yosys-fpga $(NO_COLOR) \t FPGA synthesis using Yosys and GHDL. \n";
	@echo
	@echo

# @printf "%b" "\t - $(OK_COLOR) synth-vivado$(NO_COLOR) \t FPGA synthesis using Xilinx Vivado \n";
