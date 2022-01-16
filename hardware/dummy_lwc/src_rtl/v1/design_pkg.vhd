--------------------------------------------------------------------------------
--! @file       design_pkg.vhd
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
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package design_pkg is
    --! design parameters needed by the PreProcessor, PostProcessor, and LWC
    --!
    --! Tag size in bits
    constant TAG_SIZE        : integer := 128;
    --! Hash digest size in bits
    constant HASH_VALUE_SIZE : integer := 256;
    --! CryptoCore BDI data width in bits. Supported values: 32, 16, 8
    constant CCW             : integer := 32;
    --!
    --===========================================================================================--
    --! CryptoCore key input width in bits
    --! DO NOT CHANGE: Only CCSW = CCW is currently supported
    constant CCSW            : integer := CCW;

    --===========================================================================================--

    --! Adjust the bit counter widths to reduce resource consumption.
    -- Range definition must not change.
    constant AD_CNT_WIDTH    : integer range 4 to 64 := 32;  --! Width of AD Bit counter
    constant MSG_CNT_WIDTH   : integer range 4 to 64 := 32;  --! Width of MSG (PT/CT) Bit counter

--------------------------------------------------------------------------------
------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
--------------------------------------------------------------------------------
    --! design parameters needed by the PreProcessor, PostProcessor, and LWC; assigned in the package body below!
    
    
    --! design parameters specific to the CryptoCore; assigned in the package body below!
    --! place declarations of your constants here
    constant NPUB_SIZE       : integer; --! Npub size
    constant DBLK_SIZE       : integer; --! Block size
    
    constant CCWdiv8         : integer; --! derived from parameters above, assigned in body.
    
    --! place declarations of your functions here
    --! Calculate the number of I/O words for a particular size
    function get_words(size: integer; iowidth:integer) return integer; 

    --! Padding the current word.
    function padd( bdi, bdi_valid_bytes, bdi_pad_loc : std_logic_vector ) return std_logic_vector;


end package;


package body design_pkg is





    --! design parameters specific to the CryptoCore
    constant NPUB_SIZE       : integer := 96;  --! Npub size
    constant DBLK_SIZE       : integer := 128; --! Block size

    constant CCWdiv8         : integer := CCW / 8;

    --! define your functions here
    --! Calculate the number of words
    function get_words(size: integer; iowidth:integer) return integer is
    begin
        if (size mod iowidth) > 0 then
            return size/iowidth + 1;
        else
            return size/iowidth;
        end if;
    end function get_words;



    --! Padd the data with 0x80 Byte if pad_loc is set.
    function padd( bdi, bdi_valid_bytes, bdi_pad_loc : std_logic_vector) return std_logic_vector is
        variable res : std_logic_vector(bdi'length - 1 downto 0) := (others => '0');
    begin

        for i in 0 to (bdi_valid_bytes'length - 1) loop
            if (bdi_valid_bytes(i) = '1') then
                res(8*(i+1) - 1 downto 8*i) := bdi(8*(i+1) - 1 downto 8*i);
            elsif (bdi_pad_loc(i) = '1') then
                res(8*(i+1) - 1 downto 8*i) := x"80";
            end if;
        end loop;

        return res;
    end function;

end package body design_pkg;
