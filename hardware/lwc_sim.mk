ifeq ($(strip $(LWC_SIM_INCLUDED)),)
LWC_SIM_INCLUDED=1
include $(LWC_ROOT)/lwc_common.mk
include $(LWC_ROOT)/lwc_ghdl.mk
include $(LWC_ROOT)/lwc_vcs.mk

endif