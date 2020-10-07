# Steps required for the transition from v1.0.3 to v1.1.0 for the purpose of:

## Synthesis 
- Replace the files previously stored in hardware/LWCsrc by the files from the folder [hardware/LWC_rtl](hardware/LWC_rtl)

## Simulation
- Replace LWC_TB.vhd, previously provided in the folder hardware/LWCsrc, with the two files from the folder [hardware/LWC_tb](hardware/LWC_tb)
- Modify values of the top-level testbench generics by revising [LWC_TB.vhd](hardware/LWC_tb/LWC_TB.vhd) or by overriding values of generics using options of the simulator

## Generation of test vectors
- Follow the instructions described in the [README file of cryptotvgen](software/cryptotvgen/README.md).

## Timing measurements and verification of formulas
- Generate KATs using cryptotvgen
- Set the generic `G_TEST_MODE` in LWC_TB to `4`
- Run simulation
- Review the files timing.csv and timing.txt generated in the same folder as other log files
