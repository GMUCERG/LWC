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
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package Design_pkg is

    --! user specific, algorithm independent parameters
    -- This module implements three different variants of dummy_lwc
    type set_selector is (dummy_lwc_8, dummy_lwc_16, dummy_lwc_32);

    --! Select variant
    constant variant : set_selector := dummy_lwc_32;
    
    --! Adjust the bit counter widths to reduce resource consumption.
    -- Range definition must not change.
    constant AD_CNT_WIDTH    : integer range 4 to 64 := 32;  --! Width of AD Bit counter
    constant MSG_CNT_WIDTH   : integer range 4 to 64 := 32;  --! Width of MSG (PT/CT) Bit counter

--------------------------------------------------------------------------------
------------------------- DO NOT CHANGE ANYTHING BELOW -------------------------
--------------------------------------------------------------------------------
    --! design parameters needed by the PreProcessor, PostProcessor, and LWC; assigned in the package body below!
    constant TAG_SIZE        : integer; --! Tag size
    constant HASH_VALUE_SIZE : integer; --! Hash value size
    
    constant CCSW            : integer; --! variant dependent design parameter!
    constant CCW             : integer; --! variant dependent design parameter!
    constant CCWdiv8         : integer; --! derived from parameters above, assigned in body.

    --! design parameters specific to the CryptoCore; assigned in the package body below!
    --! place declarations of your constants here
    constant NPUB_SIZE       : integer; --! Npub size
    constant DBLK_SIZE       : integer; --! Block size

    --! place declarations of your functions here
    --! Calculate the number of I/O words for a particular size
    function get_words(size: integer; iowidth:integer) return integer; 
    --! Calculate log2 and round up.
    function log2_ceil (N: natural) return natural;
    --! Reverse the Byte order of the input word.
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector;
    --! Reverse the Bit order of the input vector.
    function reverse_bit( vec : std_logic_vector ) return std_logic_vector;
    --! Padding the current word.
    function padd( bdi, bdi_valid_bytes, bdi_pad_loc : std_logic_vector ) return std_logic_vector;
    --! Return max value
    function max( a, b : integer) return integer;

end Design_pkg;


package body Design_pkg is

    -- The following construct is used to specify all varaint dependent parameters
    -- and make them selectable by the constant "variant" of type "set_selector".

    type vector_of_constants_t is array (1 to 2) of integer; -- two variant dependent constants
    type set_of_vector_of_constants_t is array (set_selector) of vector_of_constants_t;
    -- specify all variant dependent parameters (CCW, CCSW) for all variants (dummy_lwc_{8,16,32})
    constant set_of_vector_of_constants : set_of_vector_of_constants_t :=
      --   CCW
      --   |   CCSW
      --   |   |
      (  ( 8,  8), -- dummy_lwc_8
         (16, 16), -- dummy_lwc_16
         (32, 32)  -- dummy_lwc_32
      );
    -- select the correct set of parameters
    alias vector_of_constants is set_of_vector_of_constants(variant);


    --! design parameters needed by the PreProcessor, PostProcessor, and LWC
    constant TAG_SIZE        : integer := 128; --! Tag size
    constant HASH_VALUE_SIZE : integer := 256; --! Hash value size
    constant CCW             : integer := vector_of_constants(1); --! bdo/bdi width
    constant CCSW            : integer := vector_of_constants(2); --! key width
    constant CCWdiv8         : integer := CCW/8; -- derived from parameters above


    --! design parameters specific to the CryptoCore
    constant NPUB_SIZE       : integer := 96;  --! Npub size
    constant DBLK_SIZE       : integer := 128; --! Block size


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

    --! Log of base 2
    function log2_ceil (N: natural) return natural is
    begin
         if ( N = 0 ) then
             return 0;
         elsif N <= 2 then
             return 1;
         else
            if (N mod 2 = 0) then
                return 1 + log2_ceil(N/2);
            else
                return 1 + log2_ceil((N+1)/2);
            end if;
         end if;
    end function log2_ceil;

    --! Reverse the Byte order of the input word.
    function reverse_byte( vec : std_logic_vector ) return std_logic_vector is
        variable res : std_logic_vector(vec'length - 1 downto 0);
        constant n_bytes  : integer := vec'length/8;
    begin

        -- Check that vector length is actually byte aligned.
        assert (vec'length mod 8 = 0)
            report "Vector size must be in multiple of Bytes!" severity failure;

        -- Loop over every byte of vec and reorder it in res.
        for i in 0 to (n_bytes - 1) loop
            res(8*(i+1) - 1 downto 8*i) := vec(8*(n_bytes - i) - 1 downto 8*(n_bytes - i - 1));
        end loop;

        return res;
    end function reverse_byte;

    --! Reverse the Bit order of the input vector.
    function reverse_bit( vec : std_logic_vector ) return std_logic_vector is
        variable res : std_logic_vector(vec'length - 1 downto 0);
    begin

        -- Loop over every bit in vec and reorder it in res.
        for i in 0 to (vec'length - 1) loop
            res(i) := vec(vec'length - i - 1);
        end loop;

        return res;
    end function reverse_bit;

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

    --! Return max value.
    function max( a, b : integer) return integer is
    begin
        if (a >= b) then
            return a;
        else
            return b;
        end if;
    end function;

end package body Design_pkg;
