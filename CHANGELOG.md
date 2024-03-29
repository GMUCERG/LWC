# Changelog

All notable changes to this project will be documented in this file.

<!-- add changes before release under [unreleased]: -->
<!-- ## [unreleased] -->


## [1.2.0]
### Added
- Support for SCA-protected (masked) implementations. Please see the updated _Implementers' Guide_ for more details.
  - LWC top entity: [LWC_SCA.vhd](./hardware/LWC_rtl/LWC_SCA.vhd)
  - Testbench: [LWC_TB_SCA.vhd](./hardware/LWC_tb/LWC_TB_SCA.vhd)
  - Script for generation of shared testvectors: [gen_shared.py](./software/scripts/gen_shared.py)
  - New LWC parameters for SCA-protected implementations:
    - `PDI_SHARES`: number of shares for PDI input and DO output. It's set to `1` for unprotected implementations.
    - `SDI_SHARES`: number of shares for SDI (key) input. It's set to `1` for unprotected implementations.
    - `RW`: bit-width of random data input (RDI). It's set to `0` for unprotected implementations.
### Changed
- LWC package parameters are now set in the user-provided [`LWC_config`](hardware/LWC_config_template.vhd) VHDL package and [`NIST_LWAPI_pkg.vhd`](./hardware/LWC_rtl/NIST_LWAPI_pkg.vhd) should not be directly modified.
- Simplification, fixes, and cleanup for PreProcessor and PostProcessor.
  - Can work in SCA-protected implementations ([LWC_SCA](./hardware/LWC_rtl/LWC_SCA.vhd)).
  - Cleaner, more efficient code in fewer source lines of code (SLOC):
    |   Source File     | v1.0.3  | v1.1.1  | v1.2.0 |
    | ----------------- |:-------:|:-------:|:------:|
    |`PreProcessor.vhd` |1273 SLOC|1352 SLOC|351 SLOC|
    |`PostProcessor.vhd`|801  SLOC|838  SLOC|308 SLOC|
  - Improvements in synthesis result.
    - Approximate utilization in Xilinx Series-7 FPGAs (LUTs, FFs)
      |   Design               | v1.0.3  | v1.1.1  | v1.2.0 |
      | ---------------------- |:-------:|:-------:|:------:|
      | dummy_lwc (CCW=8,W=8)  | 440, 195|491, 227 |379, 210|
      | dummy_lwc (CCW=32,W=32)| 534, 177|547, 261 |518, 221|
- The FIFO implementation has been renamed to `FIFO` (file renamed to [`FIFO.vhd`](./hardware/LWC_rtl/FIFO.vhd)) and now contains 3 different implementations, selected based on the generic parameters.

## [1.1.0]
### Added
- Support for configurable asynchronous active-low reset (`ASYNC_RSTN`) in the LWC package and testbench.
- Measurement Mode in LWC_TB testbench

### Changed
- Fixes to LWC package and testbench:
  - Enhanced compatibility with VHDL Standards IEEE 1076-1993, IEEE 1076-2002, and IEEE 1076-2008.
  - Enhanced compatibility with multiple simulation and synthesis tools including: Xilinx Vivado, Intel Quartus Prime, Lattice Diamond, Synplify Pro, Synopsys VCS, Synopsys Design Compiler, and GHDL.
- Reorganization of `dummy_core` source code
- Compatibility fixes for `dummy_core`
- Fixes and enhancements to `cryptotvgen`:
  - Added a simpler and more robust binary preparation functionality within `cryptotvgen` (deprecating `prepare_src` scripts).
  - Fixed installation issues and adopted a simpler interface (Please see the [documentation](software/cryptotvgen/README.md))
  - Fixed incorrect EOI flag when a hash message is empty ([#32](https://github.com/GMUCERG/LWC/pull/33))
- Updated sample Vivado and Modelsim simulation scripts

If upgrading from an earlier version of the package, please also see the [upgrade guide](UPGRADE_GUIDE.md)

## [1.0.3]
### Notes
This release adds templates for designers of implementations and basic documentation for the dummy_lwc implementation.

### Added
- Templates [CryptoCore_template.vhd](hardware/CryptoCore_template.vhd) and [design_pkg_template.vhd](hardware/design_pkg_template.vhd)
- [assumptions.txt](hardware/dummy_lwc/docs/assumptions.txt) and [variants.txt](hardware/dummy_lwc/docs/variants.txt) for dummy_lwc.
- [source_list.txt](hardware/dummy_lwc/src_rtl/source_list.txt) that specifies the compile hierarchy.

### Changed
- Structure of [design_pkg.vhd](hardware/dummy_lwc/src_rtl/design_pkg.vhd) to match with our [template](hardware/CryptoCore_template.vhd).
- Default variant of dummy_lwc to 32 bit in [design_pkg.vhd](hardware/dummy_lwc/src_rtl/design_pkg.vhd)
- [LWC_TB](hardware/LWCsrc/LWC_TB.vhd): Changed severity of `report "---------Started verifying message number "` from `error` to `note`.

### Removed
- Unused `decrypt_out` signal from [CryptoCore.vhd](hardware/dummy_lwc/src_rtl/CryptoCore.vhd)
- Deprecated option `-novopt` from [modelsim.tcl](dummy_lwc/scripts/modelsim.tcl) as suggested in [Issue #2](https://github.com/GMUCERG/LWC/issues/2). Thanks [@Rishub](https://github.com/shrub77).
- Non ascii character "--" (Em dash) from all comments.

## [1.0.2]
### Added
- Support for hash in Cryptotvgen's `--gen_single` option.
- [vivado.tcl](hardware/dummy_lwc/scripts/vivado.tcl) to support simulations using vivado. Thanks [@kammoh](https://github.com/kammoh).

### Changed
- Fixed potential stall in the handshaking of the [PreProcessor's](hardware/LWCsrc/PreProcessor.vhd) cmd interface.

### Removed
- Unused IEEE library statement. This should increase compatiblity with Intel Quartus

## [1.0.1]
### Notes
This release fixes several small bugs and enhances usability.
We want to thank [Patrick Karl]() for the proposed bugfixes.
### Added

- [CHANGELOG.md](CHANGELOG.md)
### Changed

- Replaced the [Header Fifo](hardware/LWCsrc/fwft_fifo.vhd) with a new version to avoid routing and timing problems.
- [LWC_TB](hardware/LWCsrc/LWC_TB.vhd): Changed default value of `G_TEST_MODE` from `1` to `0`.
- [LWC_TB](hardware/LWCsrc/LWC_TB.vhd): Improved assertion handling.
- [PostProcessor](hardware/LWCsrc/PostProcessor.vhd): Changed default value of `do_data` from `Z`to`0` and made it configurable in [NIST_LWAPI_pkg.](hardware/LWCsrc/NIST_LWAPI_pkg.vhd)
- [PreProcessor](hardware/LWCsrc/PreProcessor.vhd): Fixed a stall, if the empty hash is the very first input.
- [PostProcessor](hardware/LWCsrc/PostProcessor.vhd): Fixed a stall for very short messages.
- Fixed the path of [design_pkg](hardware/dummy_lwc/src_rtl/design_pkg.vhd) in the [Implementer's Guide][guide]:
The file is placed in `hardware/<cipher_name>/` because it contains cipher specific information.
Nevertheless, it is also read by the [Pre-](hardware/LWCsrc/PreProcessor.vhd) and [PostProcessor](hardware/LWCsrc/PostProcessor.vhd).
- [Cryptotvgen Examples](software/cryptotvgen/examples/): Fixed values of parameters`--gen-single` and `--gen_custom`.
- dummy_lwc: Improved signal grouping in [modelsitm.tcl](hardware/dummy_lwc/scripts/modelsim.tcl)
- Harmonized signal names in the [Pre-](hardware/LWCsrc/PreProcessor.vhd) and [PostProcessor](hardware/LWCsrc/PostProcessor.vhd) for different bus widths.

### Removed
- Nothing.

## [1.0.0] 
Initial release.

[unreleased]: https://github.com/GMUCERG/LWC/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/GMUCERG/LWC/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/GMUCERG/LWC/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/GMUCERG/LWC/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/GMUCERG/LWC/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/GMUCERG/LWC/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/GMUCERG/LWC/releases/tag/v1.0.0

[guide]: https://cryptography.gmu.edu/athena/LWC/LWC_HW_Implementers_Guide.pdf
