# Unit tests for LWC Package components.
These tests are used during development of the LWC package to verify functionality of some of the components used in the package.

Python-based testbenches are based on [cocotb](https://www.cocotb.org) framework and utilize [cocoLight](https://github.com/kammoh/cocolight).

[Xeda](https://github.com/XedaHQ/xeda) design descriptions are provided to enable easy execution of target flows.
Xeda is not a strict requirement and the testbenches can be used with any supported simulator, using the traditional cocotb Makefile method.

## Requirements
Python >= 3.8 is required.
Target simulator (e.g., GHDL) should be installed on the system.

To install the required Python packages:
```
$ pip3 install -r unit_tests/requirements.txt
```

## Examples
To run the tests using [Xeda](https://github.com/XedaHQ/xeda) and [GHDL](https://github.com/ghdl/ghdl):

```
NUM_TV=1000 xeda run --design unit_tests/sipo.toml ghdl_sim
```
runs simulation using GHDL with 1000 sets of random testvectors.


```
NUM_TV=10 DEBUG=1 xeda run --design unit_tests/sipo.toml ghdl_sim --settings vcd=$PWD/debug 
```
runs 10 tests in DEBUG mode and also dumps waveform to `debug.vcd` in the current working directory.
