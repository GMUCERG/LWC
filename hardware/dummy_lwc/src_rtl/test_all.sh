##!/bin/bash
export USE_DOCKER=1
# sed to dummy_lwc_32
sed -i 's/:= dummy_lwc_.*/:= dummy_lwc_32;/' design_pkg.vhd
export CONFIG_LOC=$PWD/configs/32config.ini
make sim-ghdl
export CONFIG_LOC=$PWD/configs/32MSconfig.ini
make sim-ghdl
# sed to dummy_16
sed -i 's/:= dummy_lwc_.*/:= dummy_lwc_16;/' design_pkg.vhd
export CONFIG_LOC=$PWD/configs/16config.ini
make sim-ghdl
export CONFIG_LOC=$PWD/configs/16MSconfig.ini
make sim-ghdl
## sed to dummy_8
sed -i 's/:= dummy_lwc_.*/:= dummy_lwc_8;/' design_pkg.vhd
export CONFIG_LOC=$PWD/configs/8config.ini
make sim-ghdl
export CONFIG_LOC=$PWD/configs/8MSconfig.ini
make sim-ghdl
