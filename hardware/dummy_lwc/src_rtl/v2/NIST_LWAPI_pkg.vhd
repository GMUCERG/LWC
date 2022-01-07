------------------------------------------------------------------------------
--! @file       NIST_LWAPI_pkg.vhd 
--! @brief      NIST lightweight API package
--! @author     Panasayya Yalla & Ekawat (ice) Homsirikamol
--! @copyright  Copyright (c) 2016 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--------------------------------------------------------------------------------
--! Description
--!
--!
--!
--!
--!
--!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

package NIST_LWAPI_pkg is

    --! External bus: supported values are 8, 16 and 32 bits
    constant W          : positive := 16;
    constant SW         : positive := W;
    --! only used in protected implementations
    constant PDI_SHARES : positive := 1;
    constant SDI_SHARES : positive := 1;
    constant RW         : natural  := 0;

    --! Asynchronous and active-low reset.
    --! Can be set to `True` when targeting ASICs given that your CryptoCore supports it.
    constant ASYNC_RSTN : boolean := False;

    --! Default values for do_data bus
    --! to avoid leaking intermeadiate values if do_valid = '0'.
    constant do_data_defaults : std_logic_vector(W - 1 downto 0) := (others => '0');

    -- DO NOT CHANGE ANYTHING BELOW!
    constant Wdiv8  : integer := W / 8;
    constant SWdiv8 : integer := SW / 8;

    --! INSTRUCTIONS (OPCODES)
    constant INST_HASH       : std_logic_vector(3 downto 0) := "1000";
    constant INST_ENC        : std_logic_vector(3 downto 0) := "0010";
    constant INST_DEC        : std_logic_vector(3 downto 0) := "0011";
    constant INST_LDKEY      : std_logic_vector(3 downto 0) := "0100";
    constant INST_ACTKEY     : std_logic_vector(3 downto 0) := "0111";
    constant INST_SUCCESS    : std_logic_vector(3 downto 0) := "1110";
    constant INST_FAILURE    : std_logic_vector(3 downto 0) := "1111";
    --! SEGMENT TYPE ENCODING
    --! Reserved := "0000";
    constant HDR_AD          : std_logic_vector(3 downto 0) := "0001";
    constant HDR_NPUB_AD     : std_logic_vector(3 downto 0) := "0010";
    constant HDR_AD_NPUB     : std_logic_vector(3 downto 0) := "0011";
    constant HDR_PT          : std_logic_vector(3 downto 0) := "0100";
    --deprecated! use HDR_PT instead!
    alias HDR_MSG is HDR_PT;
    constant HDR_CT          : std_logic_vector(3 downto 0) := "0101";
    constant HDR_CT_TAG      : std_logic_vector(3 downto 0) := "0110";
    constant HDR_HASH_MSG    : std_logic_vector(3 downto 0) := "0111";
    constant HDR_TAG         : std_logic_vector(3 downto 0) := "1000";
    constant HDR_HASH_VALUE  : std_logic_vector(3 downto 0) := "1001";
    --NOT USED in this support package
    constant HDR_LENGTH      : std_logic_vector(3 downto 0) := "1010";
    --! Reserved := "1011";
    constant HDR_KEY         : std_logic_vector(3 downto 0) := "1100";
    constant HDR_NPUB        : std_logic_vector(3 downto 0) := "1101";
    --NOT USED in NIST LWC
    constant HDR_NSEC        : std_logic_vector(3 downto 0) := "1110";
    --NOT USED in NIST LWC
    constant HDR_ENSEC       : std_logic_vector(3 downto 0) := "1111";
    --! Maximum supported length
    --! Length of segment header
    constant SINGLE_PASS_MAX : integer                      := 16;
    --! Length of segment header
    constant TWO_PASS_MAX    : integer                      := 16;

    --! Other
    --! Limit to the segment counter size
    constant CTR_SIZE_LIM : integer := 16;

    -- type bit_array_t is array (natural range <>) of std_logic;
    -- type slv_array_t is array (natural range <>) of std_logic_vector;

    --! =======================================================================
    --! Functions used by LWC Core, PreProcessor and PostProcessor
    --! expands input vector 8 times.
    function Byte_To_Bits_EXP(bytes_in : std_logic_vector) return std_logic_vector;

    --!
    function log2ceil(n : positive) return natural;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Big Endian: Most significant (MSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_be(a : std_logic_vector; n : positive) return slv_array_t;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Little Endian: least significant (LSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_le(a : std_logic_vector; n : positive) return slv_array_t;

    --! convert boolean to std_logic
    function to_std_logic(a : boolean) return std_logic;

    --! concatinates slv_array_t elements into a single std_logic_vector
    -- Big Endian
    -- function concat_be(a : slv_array_t) return std_logic_vector;

    -- -- Little Endian
    -- function concat_le(a : slv_array_t) return std_logic_vector;

    -- function xor_slv_array(a : slv_array_t) return std_logic_vector;

    --! same as OR_REDUCE in ieee.std_logic_misc. ieee.std_logic_misc is a Non-standard package and should be avoided
    function LWC_OR_REDUCE(l : STD_LOGIC_VECTOR) return STD_LOGIC;

    --! first TO_01 and then TO_INTEGER
    function TO_INT01(S : UNSIGNED) return INTEGER;
    function TO_INT01(S : STD_LOGIC_VECTOR) return INTEGER;

end NIST_LWAPI_pkg;

package body NIST_LWAPI_pkg is

    function Byte_To_Bits_EXP(
        bytes_in : std_logic_vector
    ) return std_logic_vector is

        variable bits : std_logic_vector((8 * bytes_in'length) - 1 downto 0);
    begin

        for i in 0 to bytes_in'length - 1 loop
            if (bytes_in(i) = '1') then
                bits(8 * (i + 1) - 1 downto 8 * i) := (others => '1');
            else
                bits(8 * (i + 1) - 1 downto 8 * i) := (others => '0');
            end if;
        end loop;

        return bits;
    end Byte_To_Bits_EXP;

    function log2ceil(n : positive) return natural is
        variable pow2 : positive := 1;
        variable r    : natural  := 0;
    begin
        while n > pow2 loop
            pow2 := pow2 * 2;
            r    := r + 1;
        end loop;
        return r;
    end function;

    function LWC_OR_REDUCE(l : STD_LOGIC_VECTOR) return STD_LOGIC is
        variable result : STD_LOGIC := '0';
    begin
        for i in l'reverse_range loop
            result := (l(i) or result);
        end loop;
        return result;
    end function LWC_OR_REDUCE;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Little Endian: least significant (LSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_le(a : std_logic_vector; n : positive) return slv_array_t is
    --     constant el_w : positive := a'length / n;
    --     variable ret  : slv_array_t(0 to n - 1)(el_w - 1 downto 0);
    -- begin
    --     for i in ret'range loop
    --         ret(i) := a((i + 1) * el_w - 1 downto i * el_w);
    --     end loop;
    --     return ret;
    -- end function;

    -- --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    -- --! requires length of a to be a multiple of n
    -- --! Big Endian: Most significant (MSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_be(a : std_logic_vector; n : positive) return slv_array_t is
    --     constant el_w : positive := a'length / n;
    --     variable ret  : slv_array_t(0 to n - 1)(el_w - 1 downto 0);
    -- begin
    --     for i in ret'range loop
    --         ret(n - 1 - i) := a((i + 1) * el_w - 1 downto i * el_w);
    --     end loop;
    --     return ret;
    -- end function;

    -- --! concatinates slv_array_t elements into a single std_logic_vector
    -- -- Big Endian
    -- function concat_be(a : slv_array_t) return std_logic_vector is
    --     constant n    : positive := a'length;
    --     constant el_w : positive := a(0)'length;
    --     variable ret  : std_logic_vector(el_w * n - 1 downto 0);
    -- begin
    --     for i in a'range loop
    --         ret((i + 1) * el_w - 1 downto i * el_w) := a(n - 1 - i);
    --     end loop;
    --     return ret;
    -- end function;

    -- function concat_le(a : slv_array_t) return std_logic_vector is
    --     constant n    : positive := a'length;
    --     constant el_w : positive := a(0)'length;
    --     variable ret  : std_logic_vector(el_w * n - 1 downto 0);
    -- begin
    --     for i in a'range loop
    --         ret((i + 1) * el_w - 1 downto i * el_w) := a(i);
    --     end loop;
    --     return ret;
    -- end function;

    -- function xor_slv_array(a : slv_array_t) return std_logic_vector is
    --     constant el   : std_logic_vector := a(a'left);
    --     constant el_w : POSITIVE         := el'length;
    --     variable ret  : std_logic_vector(el_w - 1 downto 0);
    -- begin
    --     ret := a(0);
    --     for i in 1 to a'length - 1 loop
    --         ret := ret xor a(i);
    --     end loop;
    --     return ret;
    -- end function;

    function to_std_logic(a : boolean) return std_logic is
    begin
        if a then
            return '1';
        else
            return '0';
        end if;
    end function;

    function TO_INT01(S : UNSIGNED) return INTEGER is
    begin
        return to_integer(to_01(S));

    end function TO_INT01;

    function TO_INT01(S : STD_LOGIC_VECTOR) return INTEGER is
    begin
        return TO_INT01(unsigned(S));

    end function TO_INT01;

end NIST_LWAPI_pkg;
