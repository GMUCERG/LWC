FROM ubuntu:18.04
# INSTALL DEPS
RUN apt-get update && \
 DEBIAN_FRONTEND="noninteractive" apt install -y --no-install-recommends \
 gcc \
 vim \
 git \
 ca-certificates \
 apt-utils \
 make \
 gnat \
 zlib1g-dev \
 clang \
 tcl-dev \
 libreadline-dev \
 bison \
 flex \
 autoconf \
 g++ \
 libfl2 \
 libfl-dev \
 python3 \
 python \
 libffi-dev
# GHDL
RUN git clone https://github.com/ghdl/ghdl.git
RUN cd ghdl && ./configure && make && make install && cd /
# YOSYS
RUN git clone https://github.com/YosysHQ/yosys
RUN cd yosys && make && make install && cd /
# ghdl-yosys-plugin
RUN git clone https://github.com/ghdl/ghdl-yosys-plugin
RUN cd ghdl-yosys-plugin && make && make install && cd /
# verilator
RUN git clone https://github.com/verilator/verilator
RUN cd /verilator && autoconf && ./configure && make && make install
