![Main Test](https://github.com/GMUCERG/LWC/workflows/Main%20Test/badge.svg?branch=dev)
# LWC Hardware API Development Package
This is a development package for GMU's [Hardware API for Lightweight Cryptography](https://cryptography.gmu.edu/athena/index.php?id=LWC). Please refer to the latest [LWC Hardware API](https://cryptography.gmu.edu/athena/LWC/LWC_HW_API.pdf) and [LWC Hardware API Implementer’s Guide](https://cryptography.gmu.edu/athena/LWC/LWC_HW_Implementers_Guide.pdf) for further details.

This package is divided into two primary parts: **Hardware** and **Software**
## Hardware
The [hardware](./hardware) subdirectory contains implementation of the LWC package and testbench, example `dummy_lwc` implementation, as well as `CryptoCore_template.vhd` and `design_pkg_template.vhd` template files.

Available subfolders:
* `LWCsrc`: VHDL sources for `LWC` RTL development package and the `LWC_TB` testbench ([LWC_TB](hardware/LWCsrc/LWC_TB.vhd) and [compatibility package](hardware/LWCsrc/lwc_std_logic_1164_additions.vhd)).

* `dummy_lwc`: Example compliant `CryptoCore` implementation of a dummy authenticated cipher and hash function. Available subfolders:
    * `src_rtl`: RTL code of the dummy_core implementation in VHDL.
    * `KAT`: Known-Answer-Test files folder. The subfolders include test-vectors for different sets of testvectors for 3 variants of dummy_core with different configurations of the external bus-with (W).
        * `KAT_v{1,2,3}`: Known-Answer-Test files for three variants of dummy_lwc with 32-bit external bus width W=32. The test-vectors are the same for three variants (v1,v2,v3 corresponding to CCW={32,16,8}) of the core and presented as symlinks to the v1 subfolder.
        * `KAT/v2_W16`: Known-Answer-Test files for W=16 and CCW=16.
        * `KAT/v3_W8`: Known-Answer-Test files for W=8 and CCW=8.
        * `KAT_MS_W{32,16,8}`: Known-Answer-Test files with multiple segments for plaintext, ciphertext, associated data and hash message with external bus with W={32,16,8}
    * `scripts`: Sample Vivado and ModelSim simulation scripts.

### LWC Package Configuration Options

#### `design_pkg.vhd` constants
Definition and initialization of these constants _MUST_ be present in the user-provided `design_pkg.vhd` file. Please refer to [dummy core's design_pkg](hardware/dummy_lwc/src_rtl/design_pkg.vhd) for an example.
- `CCW`: Specifies the bus width (in bits) of `CryptoCore`'s PDI data and can be 8, 16, or 32. 
- `CCSW`: Specifies the bus width (in bits) of `CryptoCore`'s SDI data and is expected to be equal to `CCW`.
- `CCWdiv8`: Needs to be set equal to `CCW / 8`.
- `TAG_SIZE`: specifies the tag size in bits.
- `HASH_VALUE_SIZE`: specifies the hash size in bits. Only used in hash mode.
 
#### `NIST_LWAPI_pkg.vhd` configurable constants
- `W` (integer *default=32*): Controls the width of the external bus for PDI data bits. The width of SDI data (`SW`) is set equal to this value. Valid values are 8, 16, 32.
  Supported combinations of (`W`, `CCW`) are (32, 32), (32, 16), (32, 8), (16, 16), or (8, 8).
- `ASYNC_RSTN` (boolean *default=false*): When `True` an asynchronous active-low reset is used instead of a synchronous active-high reset throughout the LWC package and the testbench. `ASYNC_RSTN` can be set to `true` _only if_ the `CryptoCore` provides support for using active-low asyncronous resets for all of its resettable registers. Please see the provided `dummy_core` as an example.

### Testbench Parameters
Testbench parameters are exposed as VHDL generics for `LWC_TB` testbench top-level entity.
Some notable generics include:
- `G_MAX_FAILURES`: number of maximum failure before stopping the simulation. (default: 100)
- `G_TEST_MODE`(integer): see "Test Mode"below. (default: 0)
- `G_PERIOD`(time): simulation clock period (default: 10 ns)
- `G_FNAME_PDI`, `G_FNAME_SDI`, `G_FNAME_DO`(string): Paths to testvector input and expected output files.
- `G_FNAME_LOG`(string): Path to testbench generated log file.
- `G_FNAME_FAILED_TVS`(string): Path to testbench generated file containing all failed test-vectors. It will be an empty file if all testvectors passed. (default: "failed_test_vectors.txt")

Please see [LWC_TB.vhd](hardware/LWCsrc/LWC_TB.vhd) for the full list of testbench generics.

Note: Commercial and open-source simulators provide mechanisms for overriding the value of top-level testbench generics without the need to manually change the VHDL file.

#### Measurement Mode
- The `LWC_TB` now includes an experimental measurement mode intended to aid designers with verification of derived formulas for execution and latency times. To activate this mode, set `G_TEST_MODE` to 4. Measurement Mode yields results in simulator reports and two file formats: `txt` and `csv`, whose output files can be specified by the `G_FNAME_TIMING` and `G_FNAME_TIMING_CSV` generics respectively. Run this mode with `dummy_lwc` example for a sample of the output. Note, this mode is still being actively developed and may have outstanding issues.

## Software
The software include `cryptotvgen` test-vector generation utility as well as C reference implementation for the provided `dummy_lwc` example core.
* [`cryptotvgen`](software/cryptotvgen): Python utility and library for the cryptographic hardware test-vector generation.
  `cryptotvgen` can prepare and build software implementations of LWC candidates from user-provided `C` reference code or a [SUPERCOP](https://bench.cr.yp.to/supercop.html) release and generate testvectors for various testing scenarios. The reference software implementation needs to be organized according to `SUPERCOP` package structure with the `C` reference code residing inside the `ref` subfolder of `crypto_aead` and `crypto_hash` directories. Please see [cryptotvgen's documentation](software/cryptotvgen/README.md) for updated installation and usage instructions.

* [dummy_lwc_ref](software/dummy_lwc_ref): `dummy_lwc` AEAD and hash C reference implementation. Folder follows SUPERCOP package structure.

