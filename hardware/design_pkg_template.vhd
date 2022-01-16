--===============================================================================================--
--! @file       design_pkg.vhd
--! @brief      Template for CryptoCore design package
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @author     Kamyar Mohajerani
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--! @note       Assign values to all constants in the package body. Add any
--!             constants, types, and functions used only by your CryptoCore.
--!
--! @note       Change the name of the file to design_pkg.vhd, and copy it
--!             to your workspace containing all files required to synthesize
--!             LWC, listed in source_list.txt.
--===============================================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package design_pkg is

    --! design parameters needed by the PreProcessor, PostProcessor, and LWC
    --!
    --! Tag size in bits
    constant TAG_SIZE        : integer;
    --! Hash digest size in bits
    constant HASH_VALUE_SIZE : integer;
    --! CryptoCore BDI data width in bits. Supported values: 32, 16, 8
    constant CCW             : integer;
    --!
    --===========================================================================================--
    --! CryptoCore key input width in bits
    --! DO NOT CHANGE: Only CCSW = CCW is currently supported
    constant CCSW            : integer := CCW;

end design_pkg;
