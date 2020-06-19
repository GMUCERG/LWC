LWC_COMMON_INCLUDED=1
TOP ?= LWC
SOURCE_LIST_FILE ?= source_list.txt
VHDL_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.vhdl?)
VERILOG_FILES := $(shell cat $(SOURCE_LIST_FILE) | egrep .*\.s?v | egrep -v .*\.vhdl?)

YOSYS_BIN := yosys
YOSYS_GHDL_MODULE := -m ghdl
GHDL := ghdl

VHDL_STD ?= 93
WORK_LIB ?= work

SIM_TOP = LWC_TB
GHDL_OPT := --mb-comments -frelaxed-rules --warn-no-vital-generic -frelaxed -O3
GHDL_WARNS := -Wbinding -Wreserved -Wlibrary -Wvital-generic -Wdelayed-checks -Wbody -Wspecs -Wunused

ifeq ($(strip $(VHDL_STD)),93)
GHDL_OPT += --std=93c
else
GHDL_OPT += --std=$(VHDL_STD)
endif



ifeq ($(strip $(VERILOG_FILES)),)
YOSYS_READ_VERILOG_CMD := 
else
YOSYS_READ_VERILOG_CMD := read_verilog $(VERILOG_FILES);
endif

ifeq ($(strip $(VHDL_FILES)),)
YOSYS_READ_VHDL_CMD := 
else
YOSYS_READ_VHDL_CMD := ghdl $(GHDL_ARGS) $(TOP);
endif

### GHDL analyse
$(WORK_LIB)-obj$(VHDL_STD).cf: $(VHDL_FILES) Makefile
ifneq ($(strip $(VHDL_FILES)),)
	$(GHDL) -a $(GHDL_OPT) $(GHDL_WARNS) --warn-no-runtime-error $(VHDL_FILES)
endif

LWC_TB = ../../LWCsrc/LWC_TB.vhd
VHDL_ADDITIONS = ../../LWCsrc/std_logic_1164_additions.vhd


ghdl-run: $(WORK_LIB)-obj$(VHDL_STD).cf $(VHDL_FILES) $(LWC_TB)
	$(GHDL) -a $(GHDL_OPT) $(GHDL_WARNS) --warn-no-runtime-error $(VHDL_ADDITIONS) $(LWC_TB)
	$(GHDL) -e $(GHDL_OPT) $(GHDL_WARNS) $(SIM_TOP)
	$(GHDL) -r $(SIM_TOP) $(VCD_OPT) $(SIM_STOP_OPT)