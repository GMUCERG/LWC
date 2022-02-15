# Steps required for the transition from v1.1.0 to v1.2.0:
## Synthesis 
- Replace LWC package source files with corresponding updated versions in [hardware/LWC_rtl](hardware/LWC_rtl). Note that [`NIST_LWAPI_pkg.vhd`](./hardware/LWC_rtl/NIST_LWAPI_pkg.vhd) should now be used without modification. LWC API configuration should be set in a user-provided `LWC_config` package. Please see the provided [template](./hardware/LWC_config_template.vhd) and examples: [LWC_config_32.vhd](./hardware/dummy_lwc/src_rtl/LWC_config_32.vhd), [LWC_config_8.vhd](./hardware/dummy_lwc/src_rtl/LWC_config_8.vhd).
- The list of synthesis source files has slightly changed:
  - The file containing the `LWC_config` VHDL package (e.g., `LWC_config.vhd`) usually needs to go at the top of source compilation list, following with `NIST_LWAPI_pkg.vhd` and the file containing the `design_pkg` package (e.g., `design_pkg.vhd`). The source files for user's implementation of CryptoCore or CryptoCore_SCA need to be added next, following by the package implementation source files: `data_sipo.vhd`, `data_piso.vhd`, `key_piso.vhd`, `FIFO.vhd`, `PreProcessor.vhd`, `PostProcessor.vhd`, and `LWC.vhd` (or `LWC_SCA.vhd` for protected implementations).
  - The implementation for the FIFO has been optimized and the entity and the source file have been renamed to `FIFO` and `FIFO.vhd`.

## Simulation
- For SCA protected implementations use: [LWC_TB_SCA.vhd](hardware/LWC_tb/LWC_TB_SCA.vhd)


# Steps required for the transition from v1.0.3 to v1.1.0:

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
