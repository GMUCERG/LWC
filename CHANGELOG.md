# Changelog

All notable changes to this  will be documented in this file.


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
- [LWC_TB](hardware/LWCsrc/LWC_TB.vhd):  Changed default value of `G_TEST_MODE` from `1` to `0`.
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
  
[unreleased]: https://github.com/GMUCERG/LWC/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/GMUCERG/LWC/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/GMUCERG/LWC/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/GMUCERG/LWC/releases/tag/v1.0.0

[guide]: https://cryptography.gmu.edu/athena/LWC/LWC_HW_Implementers_Guide.pdf
