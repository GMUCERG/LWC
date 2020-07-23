--------------------------------------------------------------------------------
--! @file       Design_pkg.vhd
--! @brief      Package for the Cipher Core.
--!
--! @author     Michael Tempelmeier <michael.tempelmeier@tum.de>
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
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
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package Design_pkg is

    --! user specific, algorithm indepent parameters 
    -- place user specific constants like variant selectors here

    --! design parameters needed by the PreProcessor, PostProcessor, and LWC; assigned in the package body below!

    constant TAG_SIZE        : integer; --! Tag size
    constant HASH_VALUE_SIZE : integer; --! Hash value size

    constant CCSW            : integer; --! Internal key width. If SW = 8 or 16, CCSW = SW. If SW=32, CCSW = 8, 16, or 32.
    constant CCW             : integer; --! Internal data width. If W = 8 or 16, CCW = W. If W=32, CCW = 8, 16, or 32.
    constant CCWdiv8         : integer; --! derived from the parameters above, assigned in the package body below.

    --! design parameters specific to the CryptoCore; assigned in the package body below!
    --! place declarations of your types here

    --! place declarations of your constants here

    --! place declarations of your functions here

end Design_pkg;

package body Design_pkg is

  --! assign values to all constants and aliases here

  --! define your functions here

end package body Design_pkg;
