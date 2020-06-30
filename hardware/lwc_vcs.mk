WORK_DIR=work

VCS_SIMV=simv

$(WORK_DIR) :
	-@mkdir -p $@

synopsys_sim.setup :
	echo "WORK  > default" > $@
	echo "default : $(WORK_DIR)" >> $@
	
clean-vcs :
	-@rm -rf $(WORK_DIR) csrc ucli.key simv.daidir $(VCS_SIMV) synopsys_sim.setup

ifeq ($(strip $(VERILOG_FILES)),)
VCS_VLOGAN_CMD :=
else
VCS_VLOGAN_CMD := vlogan -full64 -nc -sverilog +v2k -work $(WORK_DIR) +warn=all  $(VERILOG_FILES)
endif

VCS_GENERICS_OPTS=$(shell $(PYTHON3_BIN) $(LWC_ROOT)/scripts/config_parser.py vcs_generics)

vcs-compile : Makefile $(WORK_DIR) $(SIM_VHDL_FILES) $(VERILOG_FILES) synopsys_sim.setup Makefile
	$(VCS_VLOGAN_CMD)
	vhdlan -full64 -nc -w WORK $(SIM_VHDL_FILES)
	vcs $(SIM_TOP) -full64 -nc -j4 -l vcs.log

sim-vcs : clean-vcs vcs-compile
	./$(VCS_SIMV) -nc -lca $(VCS_GENERICS_OPTS) -l $@


# sim-vcs : sim-vcs.log