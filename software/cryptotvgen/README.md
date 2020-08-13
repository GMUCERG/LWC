# CryptoTVgen
Automatic test-vector generation for hardware implementations of NIST Light-Weight Cryptography (LWC) candidates using GMU LWC Hardware API package.

## Requirements
OS: Linux, macOS, Windows (WSL, MSYS2, Cygwin)

Dependencies:
- Python 3.6.5+
- GNU Make 3.82+
- C compiler (e.g. gcc or clang)

## Installation
To install as symlinks (recommended):
```
$ pip install -e .
```
This requires the the LWC source directory to be kept in it's current location, but all updates to this directory it will be immediately accessible. 


Alternatively, to install as a copy:
```
$ pip install .
```
If using the latter command, remember to run it again following any git pulls or updates to the source distribution.

To uninstall:
```
$ pip uninstall cryptotvgen
```

Note: 
- In some systems the Python 3 version of `pip` is named `pip3`
- You can replace `pip` with `python3 -m pip` in case the Python 3 `pip` executable is not available.


## Running the Executable

- To build the libraries for the reference C implementation of `dummy_lwc` available in [software/dummy_lwc_ref](../dummy_lwc_ref/) run:
```
$ cryptotvgen --prepare_libs --candidates_dir=software/dummy_lwc_ref
```
Replace `software/dummy_lwc_ref` with the relative/absolute path to the subfolder containing `crypto_aead` and `crypto_hash` folders containing the reference implementation of an algorithm. 
This could also be the root to an already extracted SUPERCOP distribution. The built libraries will be in then available in `software/dummy_lwc_ref/lib` folder.




- To generate a random AEAD testvector for `dummy_lwc` using the reference C libraries already built in in `software/dummy_lwc_ref/lib` run:
```
$ cryptotvgen --gen_random 1 --lib_path=software/dummy_lwc_ref/lib --aead=dummy_lwc
```

To generate hash test-vectors 2 to 5 with MODE=1:
```
$ cryptotvgen --gen_hash 5 5 1 --lib_path=software/dummy_lwc_ref/lib --hash dummy_lwc
```

- To automatically download, extract, and build reference library of all LWC Round 2 candidates from SUPERCOP:
```
$ cryptotvgen --prepare_libs 
```
The downloaded tarball will be cached in `$HOME/.cryptotvgen/cache`. 
The source code of reference implementations of the LWC candidates will be extracted to the corresponding `$HOME/.cryptotvgen/crypto_*` folders.
The built libraries will be kept in the default location of `$HOME/.cryptotvgen/lib`. 
Running subsequent testvector generation commands will use these libraries by default and there will be no need to specify `--lib_path` 
(unless you want to use a different location).
The `--supercop_version` switch can be used to specify a SUPERCOP version in `YYYMMDD` format other than the latest version verified to work with `cryptotvgen`. e.g.

```
$ cryptotvgen --prepare_libs --supercop_version=20191221
```
As perviously mentioned you can also manually download and extract the SUPERCOP distribution and specify its path with using the `--candidates_dir` option. 
In that case you need to specify the path to the built libraries for the subsequent testvector generation commands by adding the `--lib_path` option.


- After the `cryptotvgen --prepare_libs` you can generate testvectors for any of the LWC candidates.
At least one of `--aead <ALGORITHM-VARIANT>` or `--hash <ALGORITHM-VARIANT>`  (or both) need to be provided with the correct name of the AEAD or hash variant.
Some candidates may provide more than one AEAD and/or hash variants.


- To generate hash testvector #5 with MODE=0 (All random data, see help for meaning of MODEs) for `xoodyakv1`:
```
$ cryptotvgen --hash xoodyakv1 --gen_hash 5 5 1 
```
- To generate hash testvector #5 with MODE=1 (see help for details) for `acehash256v1`:
```
$ cryptotvgen --hash acehash256v1 --gen_hash 5 5 1 
```

To generate combined AEAD+hash testvectors with random data for LWC candidate "ACE" (`aceae128v1` and `acehash256v1`):
```
$ cryptotvgen --aead aceae128v1 --hash acehash256v1 --gen_test_combine 1 10 0
```
The testvectors are interleaved as encrypt, decrypt, and hash.

For more information see the script help
```
$ cryptotvgen -h
```


## Using the Library
See the example scripts in the [examples](./examples) sub-folder as well as [hardware/dummy_lwc/test_all.py](../../hardware/dummy_lwc/test_all.py).

1. [examples/dummy_lwc.py](examples/dummy_lwc.py): generate AEAD and hash test-vectors for `dummy_lwc` core.

    Usage : `dummy_lwc.py <io-bits> [<max_block_per_sgmt>]`
    - The `io-bits` argument is mandatory and specifies the I/O of the top level `LWC` module. Valid values: {8, 16, 32}
    - The `max_block_per_sgmt` argument is optional and is only used for multi-segment test-vectors. It specifies the maximum blocks per segment.
    
    To generate test vectors for 32 bit width I/O:
    ```
    $ dummy_lwc.py 32
    ```
    To generate multi-segment test vectors for 16 bit width I/O and maximum of 2 blocks per segment:
    ```
    $ dummy_lwc.py 16 2
    ```

 1. [examples/gimli24v1.py](examples/gimli24v1.py) generate AEAD and hash test-vectors for `gimli24v1` NIST Round 2 LWC candidate.

