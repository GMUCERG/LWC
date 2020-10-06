# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0]
### Changed
- Fixes to LWC package and testbench:
  - Enhanced compatibility with VHDL Standards IEEE 1076-1993, IEEE 1076-2002, and IEEE 1076-2008.
  - Enhanced compatibility with multiple simulation and synthesis tools including: Xilinx Vivado, Intel Quartus Prime, Lattice Diamond, Synplify Pro, Synopsys VCS, Synopsys Design Compiler, and GHDL/Yosys.
  - `LWC_TB`: Fixed issue where waiting on `success` starts the same time success is present (#35, #27)
- Reorganization of `dummy_core` source code
- Compatibility fixes for `dummy_core`
- Fixes and enhancements to `cryptotvgen`:
  - Add simpler and more robust library preparation functionality within `cryptotvgen` (deprecating `prepare_src` scripts).
  - Fix installation issues and adopt a simpler interface (Please see the [documentation](software/cryptotvgen/README.md))
  - Fixed incorrect EOI flag when a hash message is empty ([#32](https://github.com/GMUCERG/LWC/pull/33))
- Updated sample Vivado simulation script
### Added
- Support for configurable asynchronous active-low reset (`ASYNC_RSTN`) in the LWC package and testbench.
- Latency measurement mode in LWC_TB testbench

## [1.0.3]
### Notes
This release adds templates for designers of implementations and basic documentation for the dummy_lwc implementation.

### Added
- Templates [CryptoCore_template.vhd](hardware/CryptoCore_template.vhd) and [design_pkg_template.vhd](hardware/design_pkg_template.vhd)
- [assumptions.txt](hardware/dummy_lwc/docs/assumptions.txt) and [variants.txt](hardware/dummy_lwc/docs/variants.txt) for dummy_lwc.
- [source_list.txt](hardware/dummy_lwc/src_rtl/source_list.txt) that specifies the compile hirachie.

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
  
[unreleased]: https://github.com/GMUCERG/LWC/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/GMUCERG/LWC/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/GMUCERG/LWC/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/GMUCERG/LWC/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/GMUCERG/LWC/releases/tag/v1.0.0

[guide]: https://cryptography.gmu.edu/athena/LWC/LWC_HW_Implementers_Guide.pdf
