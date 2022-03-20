--===============================================================================================--
--! @file       SIPO.vhd
--! @brief      Serial-In-Pallell-Out width converter
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
--!             under the License Exception TSU (Technology and software-unrestricted)
--! @vhdl       Compatible with VHDL 1993, 2002, 2008                                             
---------------------------------------------------------------------------------------------------
--! Description generic feed-forward (pass-through) SIPO
--!
--===============================================================================================--

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SIPO is
    generic(
        --! Input width in bits
        G_IN_W          : positive;
        --! Ratio of output width to input width. Output width is G_N * G_IN_W
        G_N             : positive;
        G_ASYNC_RSTN    : boolean := FALSE;
        --! Pipelined (and not passthrough)
        G_PIPELINED     : boolean := FALSE; -- TODO
        G_LAST_NO_DELAY : boolean := TRUE; -- TODO
        G_BIGENDIAN     : boolean := TRUE;
        G_ZERO_EMPTY    : boolean := TRUE
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        --! Serial Input
        sin_data   : in  std_logic_vector(G_IN_W - 1 downto 0);
        --! last input word. The output will be then ready, even if less than G_IN parts are filled in
        sin_last   : in  std_logic;
        sin_valid  : in  std_logic;
        sin_ready  : out std_logic;
        --! Parallel Output
        pout_data  : out std_logic_vector(G_N * G_IN_W - 1 downto 0);
        pout_valid : out std_logic;
        pout_ready : in  std_logic
    );

end entity SIPO;

architecture RTL of SIPO is

begin
    GEN_TRIVIAL : if G_N = 1 generate
        -- sin_last is ignored
        pout_data  <= sin_data;
        pout_valid <= sin_valid;
        sin_ready  <= pout_ready;
    end generate GEN_TRIVIAL;

    GEN_NONTRIVIAL : if G_N > 1 generate -- passthrough version, i.e., passes the last input to output
        constant BUFF_WORDS  : natural                           := G_N - 1;
        constant INIT_MARKER : std_logic_vector(0 to BUFF_WORDS) := (0 => '1', others => '0');
        --==================================================== Types ================================================--
        type t_buffer is array (0 to BUFF_WORDS - 1) of std_logic_vector(G_IN_W - 1 downto 0);

        --================================================== Registers ==============================================--
        signal buff_array                 : t_buffer;
        -- fill marker as a one-hot shift-register
        -- size is BUFF_WORDS+1 bits
        -- bits 0..BUFF_WORDS-1 correspond to the buffer index where the next input is stored.
        -- bit BUFF_WORDS indicates the buffer is full
        -- initialized with 10..0 at reset
        signal marker                     : std_logic_vector(0 to BUFF_WORDS);
        --==================================================== Wires ================================================--
        --! Next value of the 'marker' register
        --! feedback style to support both sync and async resset options
        signal nx_marker                  : std_logic_vector(0 to BUFF_WORDS);
        signal valids                     : std_logic_vector(0 to BUFF_WORDS - 1);
        signal in_fire, out_fire, is_full : boolean;
        signal pout_valid_o, sin_ready_o  : boolean;
    begin
        is_full      <= marker(BUFF_WORDS) = '1';
        -- sin_ready_o  <= pout_ready = '1' when sin_valid = '1' and sin_last = '1' else not is_full or pout_ready = '1';
        sin_ready_o  <= pout_ready = '1' or (sin_last = '0' and not is_full);
        pout_valid_o <= (is_full or sin_last = '1') and sin_valid = '1';
        sin_ready    <= '1' when sin_ready_o else '0';
        pout_valid   <= '1' when pout_valid_o else '0';
        in_fire      <= sin_valid = '1' and sin_ready_o;
        out_fire     <= pout_ready = '1' and pout_valid_o;
        nx_marker    <= INIT_MARKER when out_fire else '0' & marker(0 to BUFF_WORDS - 1) when in_fire else marker;

        GEN_proc_SYNC_RST : if not G_ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        marker <= INIT_MARKER;
                    else
                        marker <= nx_marker;
                    end if;
                end if;
            end process;
        end generate GEN_proc_SYNC_RST;
        GEN_proc_ASYNC_RSTN : if G_ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    marker <= INIT_MARKER;
                elsif rising_edge(clk) then
                    marker <= nx_marker;
                end if;
            end process;
        end generate GEN_proc_ASYNC_RSTN;

        GEN_ZERO_INVALIDS : if G_ZERO_EMPTY generate
            process(marker)
                variable t : std_logic;
            begin
                for i in 0 to BUFF_WORDS - 1 loop
                    t         := marker(i + 1);
                    for j in i + 2 to BUFF_WORDS loop
                        t := t or marker(j);
                    end loop;
                    valids(i) <= t;
                end loop;
            end process;
        end generate;
        GEN_NO_ZERO_INVALIDS : if not G_ZERO_EMPTY generate
            valids <= not marker(0 to BUFF_WORDS - 1);
        end generate;

        process(marker, valids, buff_array, sin_data)
            function j(i : natural) return natural is
            begin
                if G_BIGENDIAN then
                    return G_N - 1 - i;
                else
                    return i;
                end if;
            end function;
            variable t : std_logic_vector(G_IN_W - 1 downto 0);
        begin
            for i in 0 to BUFF_WORDS loop
                -- t := ((G_IN_W - 1 downto 0 => valids(i)) and ) or ((G_IN_W - 1 downto 0 => marker(i)) and sin_data);
                -- pout_data((j(i) + 1) * G_IN_W - 1 downto j(i) * G_IN_W) <= sin_data when sin_last = '1' and marker(i) = '1' else
                --                                                                                  buff_array(i) when valids(i) = '1' else (others => '0');
                if i < BUFF_WORDS then
                    t := ((G_IN_W - 1 downto 0 => valids(i)) and buff_array(i)) or ((G_IN_W - 1 downto 0 => marker(i)) and sin_data);
                elsif G_ZERO_EMPTY then
                    t := ((G_IN_W - 1 downto 0 => marker(i)) and sin_data);
                else
                    t := sin_data;
                end if;
                pout_data((j(i) + 1) * G_IN_W - 1 downto j(i) * G_IN_W) <= t;
            end loop;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then
                if in_fire then
                    for i in 0 to BUFF_WORDS - 1 loop
                        if marker(i) = '1' then
                            buff_array(i) <= sin_data;
                        end if;
                    end loop;
                end if;
            end if;
        end process;
    end generate GEN_NONTRIVIAL;
end architecture;
