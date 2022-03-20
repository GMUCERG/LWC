--===============================================================================================--
--! @file       PISO.vhd
--! @brief      Parallel-In Serial-Out width converter
--!
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2022 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, USA
--!             All rights Reserved.
--!
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--! @vhdl       Compatible with VHDL 1993, 2002, 2008                                             
---------------------------------------------------------------------------------------------------
--! Description 
--! @param      G_VALIDBYTES (bool):
--!             NOTE:  This implementation does not support empty input/output words
--!
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.design_pkg.all;

entity PISO is
    generic(
        --! Output width in bits
        G_OUT_W         : positive;
        --! Ratio of input width to output width. Input width is G_N * G_OUT_W
        --! i.e., the number of serial output words per parallel input
        G_N             : positive;
        --! with valid-bytes input/output, where each bit determins if a corresponding byte is valid  data
        --! This implementation does not support empty input/output words
        G_VALIDBYTES    : boolean := FALSE;
        G_ASYNC_RSTN    : boolean := FALSE;
        --! Pipelined (and not passthrough)
        G_PIPELINED     : boolean := FALSE; -- TODO
        G_LAST_NO_DELAY : boolean := TRUE; -- TODO
        G_BIGENDIAN     : boolean := TRUE
    );
    port(
        clk              : in  std_logic;
        rst              : in  std_logic;
        -- parallel in
        p_in_data        : in  std_logic_vector(G_OUT_W * G_N - 1 downto 0);
        p_in_validbytes  : in  std_logic_vector((G_OUT_W + 7) / 8 * G_N - 1 downto 0);
        p_in_valid       : in  std_logic;
        p_in_ready       : out std_logic;
        -- serial out
        s_out_data       : out std_logic_vector(G_OUT_W - 1 downto 0);
        s_out_validbytes : out std_logic_vector((G_OUT_W + 7) / 8 - 1 downto 0);
        --! last serial output word of the parallel word
        s_out_last       : out std_logic;
        s_out_valid      : out std_logic;
        s_out_ready      : in  std_logic
    );

end entity PISO;

architecture RTL of PISO is
begin
    GEN_TRIVIAL : if G_N = 1 generate
        s_out_data       <= p_in_data;
        s_out_validbytes <= p_in_validbytes;
        s_out_valid      <= p_in_valid;
        s_out_last       <= '1';
        p_in_ready       <= s_out_ready;
    end generate GEN_TRIVIAL;

    GEN_NONTRIVIAL : if G_N > 1 generate
        --================================================== Constants ==============================================--
        constant W_OVB                     : natural := (G_OUT_W + 7) / 8;
        --================================================== Functions ==============================================--
        pure function GET_W_VB return natural is
        begin
            if G_VALIDBYTES then
                return W_OVB * G_N;
            else
                return G_N;
            end if;
        end function;
        --================================================== Constants ==============================================--
        constant W_VB                      : natural := GET_W_VB;
        --==================================================== Types ================================================--
        type t_buffer is array (0 to G_N - 1) of std_logic_vector(G_OUT_W - 1 downto 0);
        --================================================== Registers ==============================================--
        signal buff_array                  : t_buffer;
        signal valids                      : std_logic_vector(W_VB - 1 downto 0);
        --==================================================== Wires ================================================--
        signal nx_valids                   : std_logic_vector(W_VB - 1 downto 0);
        signal valid_words                 : std_logic_vector(G_N - 1 downto 0);
        signal in_fire, out_fire, is_empty : boolean;
        signal s_out_valid_o, p_in_ready_o : boolean;
        signal last_or_empty               : std_logic;
    begin
        in_fire       <= p_in_valid = '1' and p_in_ready_o;
        out_fire      <= s_out_ready = '1' and s_out_valid_o;
        p_in_ready_o  <= is_empty or (last_or_empty = '1' and s_out_ready = '1');
        s_out_valid_o <= not is_empty;
        p_in_ready    <= '1' when p_in_ready_o else '0';
        s_out_valid   <= '1' when s_out_valid_o else '0';
        is_empty      <= valid_words(0) = '0';
        last_or_empty <= not valid_words(1);
        s_out_last    <= last_or_empty; -- not empty when s_out_valid

        GEN_proc_SYNC_RST : if not G_ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        valids(0) <= '0';
                    else
                        valids <= nx_valids;
                    end if;
                end if;
            end process;
        end generate GEN_proc_SYNC_RST;
        GEN_proc_ASYNC_RSTN : if G_ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    valids(0) <= '0';
                elsif rising_edge(clk) then
                    valids <= nx_valids;
                end if;
            end process;
        end generate GEN_proc_ASYNC_RSTN;

        GEN_NO_VALIDBYTES : if not G_VALIDBYTES generate
        begin
            valid_words      <= valids;
            nx_valids        <= (others => '1') when in_fire else
                                '0' & valids(G_N - 1 downto 1) when out_fire else
                                valids;
            s_out_validbytes <= (others => '1');
        end generate GEN_NO_VALIDBYTES;

        GEN_VALIDBYTES : if G_VALIDBYTES generate
            signal valids_init : std_logic_vector(W_VB - 1 downto 0);
        begin
            GEN_VALID_WORDS : for i in 0 to G_N - 1 generate
                valid_words(i) <= valids(i * W_OVB);
            end generate;

            nx_valids <= valids_init when in_fire else
                         (W_OVB - 1 downto 0 => '0') & valids(W_VB - 1 downto W_OVB) when out_fire else
                         valids;

            GEN_VALIDS_INIT_BIGENDIAN : if G_BIGENDIAN generate
                GEN_REVERSE_IN : for i in p_in_validbytes'range generate
                    valids_init(i) <= p_in_validbytes(p_in_validbytes'length - 1 - i);
                end generate;
                GEN_REVERSE_OUT : for i in s_out_validbytes'range generate
                    s_out_validbytes(i) <= valids(W_OVB - 1 - i);
                end generate;
            end generate;
            GEN_VALIDS_INIT_LITTLEENDIAN : if not G_BIGENDIAN generate
                s_out_validbytes <= valids(s_out_validbytes'range);
                valids_init      <= p_in_validbytes;
            end generate;
        end generate GEN_VALIDBYTES;

        process(clk)
            function j(i : natural) return natural is
            begin
                if G_BIGENDIAN then
                    return G_N - 1 - i;
                else
                    return i;
                end if;
            end function;
        begin
            if rising_edge(clk) then
                if in_fire then
                    for i in 0 to G_N - 1 loop
                        buff_array(i) <= p_in_data((j(i) + 1) * G_OUT_W - 1 downto j(i) * G_OUT_W);
                    end loop;
                elsif out_fire then
                    buff_array <= buff_array(1 to G_N - 1) & buff_array(G_N - 1);
                end if;
            end if;
        end process;

        s_out_data <= buff_array(0);
    end generate GEN_NONTRIVIAL;

end architecture;
