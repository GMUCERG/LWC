# CryptoTVgen
Automatic test-vector generation for hardware implementations of NIST Light-Weight Cryptography (LWC) candidates using GMU LWC Hardware API package.

## Requirements
OS: Linux, macOS, Windows

Dependencies:
- Python 3.6.5+

## Installation
To install as symlinks:
```
$ pip install -e .
```
This requires the the LWC source directory to be kept in it's current location, but all updates to this directory it will be immediately accessible. 


Alternatively, to install as a copy:
```
$ pip install .
```
If using the latter command, remember to run it again following any git pulls or updates to the source distribution.

You can replace `pip` with `python3 -m pip` in case the `pip` executable is not available on your system.

## Running the Executable

See help
```
$ cryptotvgen -h
```


## Using the Library
See the [examples](./examples) sub-folder.