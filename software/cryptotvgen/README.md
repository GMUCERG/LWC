# cryptotvgen
Automatic test-vector generation for hardware implementations of NIST Light-Weight Cryptography (LWC) candidates using GMU LWC Hardware API package.
<!-- Linux
===========
> sudo apt-get install libssl-dev
> sudo apt-get install python3-pip
> sudo apt-get install python3-cffi -->



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

## Using the `cryptotvgen` Script

See help
```
$ cryptotvgen -h
```


## Using the `cryptotvgen` Library
See the [examples](./examples) sub-folder.