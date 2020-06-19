ifeq ($(strip $(LWC_COMMON_INCLUDED)),)
include $(LWC_ROOT)/lwc_common.mk
endif

yosys_synth_xc7.json: $(WORK_LIB)-obj$(VHDL_STD).cf $(VERILOG_FILES) Makefile
	$(YOSYS_BIN) $(YOSYS_GHDL_MODULE) -p "$(YOSYS_READ_VHDL_CMD) $(YOSYS_READ_VERILOG_CMD) synth_xilinx -widemux 6 -flatten -nobram -arch xc7; write_json $@ ; check -assert; stat"


synth-xilinx-yosys-xc7: yosys_synth_xc7.json