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
    --===============================================================================================================--
    --=                                             User Configuration                                              =--
    --===============================================================================================================--

    --! External bus: supported values are 8, 16 and 32 bits
    constant W          : positive := 32;
    constant SW         : positive := W;
    --! Implementation of an "offline" algorithm
    constant G_OFFLINE  : boolean  := False;
    --! only used in protected implementations
    constant PDI_SHARES : positive := 1;
    constant SDI_SHARES : positive := 1;
    -- constant RW         : natural  := 0;
    -- constant API_KEY_BYTES        : integer := 32; --! Key size in bytes
    -- constant API_TAG_BYTES        : integer := 32; --! Tag size in bytes
    -- constant API_DIGEST_BYTES : integer := 64 --! Hash digest size in byutes

    --! Asynchronous and active-low reset.
    --! Can be set to `True` when targeting ASICs given that your CryptoCore supports it.
    constant ASYNC_RSTN : boolean := False;


    --===============================================================================================================--
    -- DO NOT CHANGE ANYTHING BELOW
    --===============================================================================================================--


    constant Wdiv8  : integer := W / 8;
    constant SWdiv8 : integer := SW / 8;

    subtype T_LWC_SEGMENT is std_logic_vector(3 downto 0);
    subtype T_LWC_OPCODE is std_logic_vector(3 downto 0);


    --! INSTRUCTIONS (OPCODES)
    constant INST_HASH      : T_LWC_OPCODE := "1000";
    constant INST_ENC       : T_LWC_OPCODE := "0010";
    constant INST_DEC       : T_LWC_OPCODE := "0011";
    constant INST_LDKEY     : T_LWC_OPCODE := "0100";
    constant INST_ACTKEY    : T_LWC_OPCODE := "0111";
    constant INST_SUCCESS   : T_LWC_OPCODE := "1110";
    constant INST_FAILURE   : T_LWC_OPCODE := "1111";
    --! SEGMENT TYPE ENCODING
    --! Reserved := "0000";
    constant HDR_AD         : T_LWC_SEGMENT := "0001";
    constant HDR_NPUB_AD    : T_LWC_SEGMENT := "0010";
    constant HDR_AD_NPUB    : T_LWC_SEGMENT := "0011";
    constant HDR_PT         : T_LWC_SEGMENT := "0100";
    constant HDR_CT         : T_LWC_SEGMENT := "0101";
    constant HDR_CT_TAG     : T_LWC_SEGMENT := "0110";
    constant HDR_HASH_MSG   : T_LWC_SEGMENT := "0111";
    constant HDR_TAG        : T_LWC_SEGMENT := "1000";
    constant HDR_HASH_VALUE : T_LWC_SEGMENT := "1001";
    constant HDR_LENGTH     : T_LWC_SEGMENT := "1010";
    constant HDR_KEY        : T_LWC_SEGMENT := "1100";
    constant HDR_NPUB       : T_LWC_SEGMENT := "1101";
    --! Reserved := "1011";
    --NOT USED in NIST LWC
    constant HDR_NSEC       : T_LWC_SEGMENT := "1110";
    --NOT USED in NIST LWC
    constant HDR_ENSEC      : T_LWC_SEGMENT := "1111";
    --! Maximum supported length
    --! Length of segment header
    -- constant SINGLE_PASS_MAX : integer                      := 16;
    -- --! Length of segment header
    -- constant TWO_PASS_MAX    : integer                      := 16;

    -- --! Other
    -- --! Limit to the segment counter size
    -- constant CTR_SIZE_LIM : integer := 16;

    -- type bit_array_t is array (natural range <>) of std_logic;
    -- type slv_array_t is array (natural range <>) of std_logic_vector;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Big Endian: Most significant (MSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_be(a : std_logic_vector; n : positive) return slv_array_t;

    --! chop a std_logic_vector into `n` equal-length pieces as a slv_array_t
    --! requires length of a to be a multiple of n
    --! Little Endian: least significant (LSB) portion of the input `a` is assigned to index 0 of the output
    -- function chop_le(a : std_logic_vector; n : positive) return slv_array_t;


    --! concatinates slv_array_t elements into a single std_logic_vector
    -- Big Endian
    -- function concat_be(a : slv_array_t) return std_logic_vector;

    -- -- Little Endian
    -- function concat_le(a : slv_array_t) return std_logic_vector;

    -- function xor_slv_array(a : slv_array_t) return std_logic_vector;
    --! =======================================================================
    --! Functions used by LWC Core, PreProcessor and PostProcessor
    --! expands input vector 8 times.
    function Byte_To_Bits_EXP(bytes_in : std_logic_vector) return std_logic_vector;

    --! Returns the number of bits required to represet positive integers strictly less than `n` (0 to n - 1 inclusive)
    --! Output is equal to ceil(log2(n))
    function log2ceil(n : positive) return natural;

    --! convert boolean to std_logic
    function to_std_logic(a : boolean) return std_logic;

    --! same as OR_REDUCE in ieee.std_logic_misc. ieee.std_logic_misc is a Non-standard package and should be avoided
    function LWC_OR_REDUCE(l : STD_LOGIC_VECTOR) return STD_LOGIC;

    --! first TO_01 and then TO_INTEGER
    function TO_INT01(S : UNSIGNED) return INTEGER;
    function TO_INT01(S : STD_LOGIC_VECTOR) return INTEGER;

    --! check if all bits are zero
    function is_zero(slv : std_logic_vector) return boolean;
    function is_zero(u : unsigned) return boolean;

    --! Reverse the Bit order of the input vector.
    function reverse_bits(slv : std_logic_vector) return std_logic_vector;
    function reverse_bits(u : unsigned) return unsigned;

    --! reverse byte endian-ness of the input vector
    function reverse_bytes(vec : std_logic_vector) return std_logic_vector;

    --! binary to one-hot encoder
    function to_1H(u : unsigned) return unsigned;
    function to_1H(slv : std_logic_vector) return std_logic_vector;
    function to_1H(u : unsigned; out_bits : positive) return unsigned;
    function to_1H(slv : std_logic_vector; out_bits : positive) return std_logic_vector;

    function minimum(a : integer; b : integer) return integer;

    --! dynamic (u << sh) using an efficient barrel shifter
    function barrel_shift_left(u : unsigned; sh : unsigned) return unsigned;

    -- function resize(u : unsigned; sz: natural) return unsigned;

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

    --! Returns the number of bits required to represet values less than n (0 to n - 1 inclusive)
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

    function is_zero(u : unsigned) return boolean is
    begin
        if u'length <= 0 then
            return True;
        end if;
        return u = 0;
    end function;

    function is_zero(slv : std_logic_vector) return boolean is
    begin
        return is_zero(unsigned(slv));
    end function;

    --! Reverse the Byte order of the input word.
    function reverse_bytes(vec : std_logic_vector) return std_logic_vector is
        variable res     : std_logic_vector(vec'length - 1 downto 0);
        constant n_bytes : integer := vec'length / 8;
    begin
        -- Check that vector length is actually byte aligned.
        -- assert (vec'length mod 8 = 0)
        -- report "Vector size must be in multiple of Bytes!" severity failure;
        for i in 0 to (n_bytes - 1) loop
            res(8 * (i + 1) - 1 downto 8 * i) := vec(8 * (n_bytes - i) - 1 downto 8 * (n_bytes - i - 1));
        end loop;
        return res;
    end function;

    --! Reverse the bit-order of the input
    function reverse_bits(slv : std_logic_vector) return std_logic_vector is
        variable res : std_logic_vector(slv'range);
    begin
        for i in res'range loop
            res(i) := slv(slv'length - i - 1);
        end loop;
        return res;
    end function;

    function reverse_bits(u : unsigned) return unsigned is
    begin
        return unsigned(reverse_bits(std_logic_vector(u)));
    end function;

    --! binary to one-hot encoder
    function to_1H(u : unsigned) return unsigned is
    begin
        return to_1H(u, 2 ** u'length);
    end function;

    --! binary to one-hot encoder
    function to_1H(u : unsigned; out_bits : positive) return unsigned is
        variable ret : unsigned(out_bits - 1 downto 0) := (others => '0');
    begin
        for i in 0 to out_bits - 1 loop
            if u = to_unsigned(i, u'length) then
                ret(i) := '1';
            end if;
        end loop;
        return ret;
    end function;

    function to_1H(slv : std_logic_vector; out_bits : positive) return std_logic_vector is
    begin
        return std_logic_vector(to_1H(unsigned(slv), out_bits));
    end function;

    function to_1H(slv : std_logic_vector) return std_logic_vector is
    begin
        return std_logic_vector(to_1H(unsigned(slv)));
    end function;

    function minimum(a : integer; b : integer) return integer is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;

    function barrel_shift_left(u : unsigned; sh : unsigned) return unsigned is
        variable ret : unsigned(u'length + (2 ** sh'length) - 1 downto 0) := u;
    begin
        for i in 0 to sh'length - 1 loop
            if sh(i) = '1' then
                ret := shift_left(ret, 2 ** i);
            end if;
        end loop;
        return ret;
    end function;

    -- function resize(u : unsigned; sz: natural) return unsigned is
    --     variable min_sz: positive := u'length;
    --     variable ret : unsigned(sz - 1 downto 0) := (others => '0');
    -- begin
    --     if sz < min_sz then
    --         min_sz := sz;
    --     end if;
    --     ret(min_sz - 1 downto 0) := u;
    --     return ret;
    -- end function;

end NIST_LWAPI_pkg;
