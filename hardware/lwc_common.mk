ifndef LWC_ROOT
$(error LWC_ROOT must be defined in design-specific Makefile)
endif

ifndef CORE_ROOT
CORE_ROOT ?= $(PWD)
$(warning CORE_ROOT was not defined in design-specific Makefile, defaulting to)
endif

LWCSRC_DIR := $(LWC_ROOT)/LWCsrc

ifeq ($(strip $(LWC_COMMON_INCLUDED)),)
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


ifeq ($(strip $(VERILOG_FILES)),)
YOSYS_READ_VERILOG_CMD := 
else
YOSYS_READ_VERILOG_CMD := read_verilog $(VERILOG_FILES);
endif

LWC_TB = $(LWCSRC_DIR)/LWC_TB.vhd
VHDL_ADDITIONS = $(LWCSRC_DIR)/std_logic_1164_additions.vhd

endif