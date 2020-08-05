ifndef LWC_ROOT
$(error LWC_ROOT must be defined in design-specific Makefile)
endif

LWC_ROOT := $(realpath $(LWC_ROOT))
HW_DIR := $(LWC_ROOT)/hardware

include $(HW_DIR)/makefiles/lwc_common.mk
include $(HW_DIR)/makefiles/lwc_ghdl.mk
include $(HW_DIR)/makefiles/lwc_lint.mk
include $(HW_DIR)/makefiles/lwc_yosys_fpga.mk
include $(HW_DIR)/makefiles/lwc_vcs.mk
include $(HW_DIR)/makefiles/lwc_dc.mk
include $(HW_DIR)/makefiles/lwc_vivado.mk
