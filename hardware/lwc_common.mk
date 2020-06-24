ifndef LWC_ROOT
$(error LWC_ROOT must be defined in core Makefile)
endif

ifeq ($(strip $(LWC_COMMON_INCLUDED)),)
LWC_COMMON_INCLUDED=1
TOP ?= LWC
SOURCE_LIST_FILE ?= source_list.txt
VHDL_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.vhdl?)
VERILOG_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.s?v | egrep -v .*\.vhdl?)

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

LWCSRC_DIR := $(LWC_ROOT)/LWCsrc

LWC_TB = $(LWCSRC_DIR)/LWC_TB.vhd
VHDL_ADDITIONS = $(LWCSRC_DIR)/std_logic_1164_additions.vhd

endif