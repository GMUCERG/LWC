[![Main Test](https://github.com/GMUCERG/LWC/workflows/Main%20Test/badge.svg?branch=master)](https://github.com/GMUCERG/LWC/actions)
# LWC Hardware API Development Package
This is a development package for GMU's [Hardware API for Lightweight Cryptography](https://cryptography.gmu.edu/athena/index.php?id=LWC). Please refer to the latest [LWC Hardware API](https://cryptography.gmu.edu/athena/LWC/LWC_HW_API.pdf) and [LWC Hardware API Implementer’s Guide](https://cryptography.gmu.edu/athena/LWC/LWC_HW_Implementers_Guide.pdf) for further details.

Note: if upgrading from an earlier version of the LWC package, please see our [upgrade guide](UPGRADE_GUIDE.md)

This package is divided into two primary parts: **Hardware** and **Software**
## Hardware
* RTL VHDL code of a generic PreProcessor, PostProcessor, and Header FIFO, common for all LWC candidates ([LWC_rtl](hardware/LWC_rtl))
* Universal testbench common for all the API-compliant designs ([LWC_tb](hardware/LWC_tb))
* Reference implementation of a dummy authenticated cipher with a hash functionality (AEAD+Hash) ([dummy_lwc](hardware/dummy_lwc))
* Template of the CryptoCore (CryptoCore_templete.vhd)
* Template of design_pkg.vhd (design_pkg_templete.vhd)
* `process_failures.py`: Python script for post-processing testbench-generated log of failed test-vectors ('failed_test_vectors.txt')
* `makefiles`, `scripts`, `lwc.mk`: simulation makefiles and scripts.

The subfolders of dummy_lwc include:
* `src_rtl`: RTL VHDL code of the dummy core
* `KAT`: Known-Answer Tests. The subfolders include test-vectors for 3 variants of the dummy core with different configurations of the external bus width (W).
    * `KAT_v{1,2,3}`: Known-Answer Tests for three variants of dummy_lwc with the external bus width W=32. The test-vectors are the same for three variants (v1,v2,v3 corresponding to CCW={32,16,8}) of the core and presented as symlinks to the v1 subfolder.
    * `KAT/v2_W16`: Known-Answer Tests for W=16 and CCW=16.
    * `KAT/v3_W8`:  Known-Answer Tests for W=8 and CCW=8.
    * `KAT_MS_W{32,16,8}`: Known-Answer Tests with multiple segments for plaintext, ciphertext, associated data, and hash message, with the external bus width W={32,16,8}.
* `scripts`: Sample Vivado and ModelSim simulation scripts.

### LWC Package Configuration Options

#### `design_pkg.vhd` constants
Definition and initialization of these constants _MUST_ be present in the user-provided `design_pkg.vhd` file. Please refer to [dummy_lwc design_pkg](hardware/dummy_lwc/src_rtl/v1/design_pkg.vhd) for an example.
- `CCW`: Specifies the bus width (in bits) of `CryptoCore`'s PDI data and can be 8, 16, or 32. 
- `CCSW`: Specifies the bus width (in bits) of `CryptoCore`'s SDI data and is expected to be equal to `CCW`.
- `TAG_SIZE`: specifies the tag size in bits.
- `HASH_VALUE_SIZE`: specifies the hash size in bits. Only used in hash mode.
 
#### `NIST_LWAPI_pkg.vhd` configurable constants
- `W` (integer *default=32*): Controls the width of the external bus for PDI data bits. The width of sdi_data (`SW`) is set to this value. Valid values are 8, 16, 32.
  Supported combinations of (`W`, `CCW`) are (32, 32), (32, 16), (32, 8), (16, 16), and (8, 8).
- `ASYNC_RSTN` (boolean *default=false*): When `True` an asynchronous active-low reset is used instead of a synchronous active-high reset throughout the LWC package and the testbench. `ASYNC_RSTN` can be set to `true` _only if_ the `CryptoCore` provides support for using active-low asyncronous resets for all of its resettable registers. Please see the provided `dummy_core` as an example.

### Testbench Parameters
Testbench parameters are exposed as VHDL generics in the `LWC_TB` testbench top-level entity.
Some notable generics include:
- `G_MAX_FAILURES`(integer): number of maximum failures before stopping the simulation (default: 100)
- `G_TEST_MODE`(integer): see "Test Mode"below. (default: 0)
- `G_CLK_PERIOD_PS`(integer): simulation clock period (default: 10 ns)
- `G_FNAME_PDI`, `G_FNAME_SDI`, `G_FNAME_DO`(string): Paths to testvector input and expected output files.
- `G_FNAME_LOG`(string): Path to the testbench-generated log file.
- `G_FNAME_FAILED_TVS`(string): Path to testbench-generated file containing all failed test-vectors. It will be an empty file if all test vectors passed. (default: "failed_test_vectors.txt")

Please see [LWC_TB.vhd](hardware/LWC_tb/LWC_TB.vhd) for the full list of testbench generics.

Note: Commercial and open-source simulators provide mechanisms for overriding the value of top-level testbench generics without the need to manually change the VHDL file.

#### Measurement Mode
- The `LWC_TB` now includes a timing measurement mode which measures the number of cycles spent on the execution of each individual test-case. To activate this mode, set `G_TEST_MODE` to 4. The results of the timing measurement are written to the file specified by the `G_FNAME_TIMING` testbench generic.

## Software
The software subdirectory contains:
* [`cryptotvgen`](software/cryptotvgen): Python utility and library for the cryptographic hardware test-vector generation.
  `cryptotvgen` can prepare and build software implementations of LWC candidates from user-provided `C` reference code or a [SUPERCOP](https://bench.cr.yp.to/supercop.html) release and generate testvectors for various testing scenarios. The reference software implementation needs to be organized according to `SUPERCOP` package structure with the `C` reference code residing inside the `ref` subfolder of `crypto_aead` and `crypto_hash` directories. Please see [cryptotvgen's documentation](software/cryptotvgen/README.md) for updated installation and usage instructions.

* [dummy_lwc_ref](software/dummy_lwc_ref): `dummy_lwc` AEAD and hash C reference implementation. Folder follows SUPERCOP package structure.

