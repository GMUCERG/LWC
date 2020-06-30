ifeq ($(strip $(LWC_COMMON_INCLUDED)),)

ifndef LWC_ROOT
$(error LWC_ROOT must be defined in design-specific Makefile)
endif

ifndef CORE_ROOT
CORE_ROOT ?= $(PWD)
$(warning CORE_ROOT was not defined in design-specific Makefile, defaulting to)
endif

LWCSRC_DIR := $(LWC_ROOT)/LWCsrc

LWC_COMMON_INCLUDED=1
TOP ?= LWC
SOURCE_LIST_FILE ?= $(CORE_ROOT)/source_list.txt
PYTHON3_BIN ?= python3

VHDL_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.vhdl?)
VERILOG_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.s?v | egrep -v .*\.vhdl?)

# expand variables inside `source_list.txt`
$(eval  VHDL_FILES=$(VHDL_FILES))
$(eval  VERILOG_FILES=$(VERILOG_FILES))

export VHDL_FILES
export VERILOG_FILES


YOSYS_BIN := yosys
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



default: help

COM_COLOR   = \033[0;34m
OBJ_COLOR   = \033[0;36m
OK_COLOR    = \033[0;32m
ERROR_COLOR = \033[0;31m
WARN_COLOR  = \033[0;33m
NO_COLOR    = \033[m

help:
	@cat $(LWC_ROOT)/cerg.ascii
	@echo
	@echo LWC Lint, Simulation, and Synthesis Framework
	@echo
	@printf "%b" "\n $(ERROR_COLOR)Available Targets:$(NO_COLOR)\n\n";
	@printf "%b" "$(OBJ_COLOR)* Lint (checking)$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) lint-vhdl $(NO_COLOR): \t lint VHDL files using GHDL\n";
	@printf "%b" "\t - $(OK_COLOR) lint-verilog $(NO_COLOR): \t lint Verilog files using Verilator\n";
	@printf "%b" "\t - $(OK_COLOR) lint-yosys $(NO_COLOR): \t lint full design (VHDL and Verilog) using yosys and ghdl-yosys-plugin \n";
	@echo
	@printf "%b" "$(OBJ_COLOR)* Simulation$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) sim-ghdl $(NO_COLOR): \t\t simulate using GHDL (VHDL only) \n";
	@printf "%b" "\t - $(OK_COLOR) sim-vcs $(NO_COLOR): \t\t simulate using Synopsys VCS (VHDL and Verilog) \n";
	@echo
	@printf "%b" "$(OBJ_COLOR)* Synthesis$(NO_COLOR)\n";
	@printf "%b" "\t - $(OK_COLOR) synth-dc $(NO_COLOR): \t\t ASIC synthesis using Synopsys Design Compiler \n";
	@printf "%b" "\t - $(OK_COLOR) synth-yosys-x $(NO_COLOR): \t FPGA synthesis using Yosys and GHDL \n";
	@printf "%b" "\t - $(OK_COLOR) synth-vivado$(NO_COLOR): \t FPGA synthesis using Xilinx Vivado \n";

endif