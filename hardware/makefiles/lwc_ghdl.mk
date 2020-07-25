LWC_GHDL_INCLUDED=1

GHDL_BIN ?= ghdl

GHDL_OPTIMIZE ?= -O3

GHDL_OPT := -frelaxed-rules --warn-no-vital-generic -frelaxed $(GHDL_OPTIMIZE)
GHDL_WARNS ?= -Wbinding -Wreserved -Wlibrary -Wvital-generic -Wdelayed-checks -Wbody -Wspecs -Wunused --warn-no-runtime-error
GHDL_ELAB_OPTS ?= --mb-comments 
GHDL_SIM_OPTS ?=

ifeq ($(strip $(VHDL_STD)),93)
GHDL_OPT += --std=93c
else
GHDL_OPT += --std=$(VHDL_STD)
endif

ifneq ($(strip $(VCD_FILE)),)
GHDL_SIM_OPTS += --vcd=$(VCD_FILE)
endif
ifneq ($(strip $(VCDGZ_FILE)),)
GHDL_SIM_OPTS += --vcdgz=$(VCDGZ_FILE)
endif
ifneq ($(strip $(GHW_FILE)),)
GHDL_SIM_OPTS += --wave=$(GHW_FILE)
endif


### GHDL analyse
$(WORK_LIB)-obj$(VHDL_STD).cf: $(VHDL_FILES) $(FORCE_REBUILD) Makefile
ifneq ($(strip $(VHDL_FILES)),)
	$(GHDL_BIN) -a $(GHDL_OPT) $(GHDL_WARNS) $(VHDL_FILES)
endif

SIM_ONLY_VHDL_FILES := $(VHDL_ADDITIONS) $(LWC_TB) 
SIM_VHDL_FILES = $(VHDL_FILES) $(SIM_ONLY_VHDL_FILES)

GENERICS_OPTS=$(shell $(PYTHON3_BIN) $(LWC_ROOT)/hardware/scripts/config_parser.py ghdl_generics $(CONFIG_LOC))

### GHDL analyze testbench files, elaborate, and run
.PHONY: sim-ghdl help-ghdl clean-ghdl
sim-ghdl: $(WORK_LIB)-obj$(VHDL_STD).cf $(SIM_VHDL_FILES) Makefile config-vars
	$(GHDL_BIN) -a $(GHDL_OPT) $(GHDL_WARNS) $(GHDL_ELAB_OPTS) $(SIM_VHDL_FILES)
	$(GHDL_BIN) -e $(GHDL_OPT) $(GHDL_WARNS) $(GHDL_ELAB_OPTS) $(SIM_TOP) 
	$(GHDL_BIN) -r $(SIM_TOP) $(GHDL_SIM_OPTS) $(GENERICS_OPTS) $(VCD_OPT)

ifeq ($(strip $(VHDL_FILES)),)
YOSYS_READ_VHDL_CMD := 
else
YOSYS_READ_VHDL_CMD := ghdl $(GHDL_OPT) $(GHDL_WARNS) $(TOP);
endif

help-ghdl:
	@printf "%b" "$(CYAN)GHDL variables$(NO_COLOR):\n";
	@printf "%b" "VHDL_STD \t VHDL standard to use: 87, 93 (using 93c), 00, 02, 08\n";
	@echo
	@printf "%b" "$(CYAN)sim-ghdl variables$(NO_COLOR):\n";
	@printf "%b" "VCD_FILE \t filename to generate VCD wave\n";
	@printf "%b" "VCDGZ_FILE \t filename to generate VCD wave, gziped\n";
	@printf "%b" "GHW_FILE \t filename to GHW wave (better support for VHDL types)\n";
	@printf "%b" "GHDL_OPTIMIZE \t Set GHDL optimization, default: -O3\n";
	@echo

clean-ghdl:
	-@rm -f $(WORK_LIB)-obj$(VHDL_STD).cf $(SIM_TOP) e~*.o $(patsubst %.vhd,%.o,$(patsubst %.vhdl,%.o,$(notdir $(SIM_VHDL_FILES))))
