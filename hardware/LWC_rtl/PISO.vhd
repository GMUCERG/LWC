--===============================================================================================--
--! @file              PISO.vhd
--! @brief             Pallell-In, Serial-Out width converter
--! @author            Kamyar Mohajerani
--! @copyright         Copyright (c) 2022 Cryptographic Engineering Research Group
--!                    ECE Department, George Mason University Fairfax, VA, USA
--!                    All rights Reserved.
--! @license           GNU Public License v3 ([GPL-3.0](http://www.gnu.org/licenses/gpl-3.0.txt))
--!                    
--! @vhdl              VHDL 1993, 2002, 2008, and later
--!
--! @details           Multi-purpose PISO implementation
--!
--! @param G_OUT_W     Width of output (serial) data
--! @param G_N         Ratio of the width of input (parallel) data to output (serial) data
--! @param G_CHANNELS  Input/output come in G_CHANNELS separate data "channels"
--! @param G_SUBWORD   If false, p_in_keep is discarded and all bytes are assumed to be valid
--!
--! @note              This implementation does not support empty input/output words
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PISO is
    generic(
        --! Output width in bits
        G_OUT_W      : positive;
        --! Ratio of input width to output width. Input width is `G_N * G_OUT_W`
        --! i.e., the number of serial output words per parallel input
        G_N          : positive;
        --! Input and output data are in `G_CHANNELS` independent "channels".
        --!    Used e.g., in masked LWC implementations
        G_CHANNELS   : positive := 1;
        --! with valid-bytes input/output, where each bit determins if a corresponding byte is valid  data
        G_SUBWORD    : boolean  := FALSE;
        --! When `TRUE`, reset is asynchronous and active-low
        G_ASYNC_RSTN : boolean  := FALSE;
        --! When `TRUE`, the first output word is the slice of the input with most-significant bits
        G_BIGENDIAN  : boolean  := TRUE
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        --! Parallel input
        p_in_data   : in  std_logic_vector(G_CHANNELS * G_OUT_W * G_N - 1 downto 0);
        p_in_keep   : in  std_logic_vector((G_OUT_W + 7) / 8 * G_N - 1 downto 0) := (others => '1');
        p_in_last   : in  std_logic := '0';
        p_in_valid  : in  std_logic;
        p_in_ready  : out std_logic;
        --! Serial output
        s_out_data  : out std_logic_vector(G_CHANNELS * G_OUT_W - 1 downto 0);
        s_out_keep  : out std_logic_vector((G_OUT_W + 7) / 8 - 1 downto 0);
        s_out_last  : out std_logic;
        s_out_valid : out std_logic;
        s_out_ready : in  std_logic
    );

end entity PISO;

architecture RTL of PISO is
begin
    GEN_TRIVIAL : if G_N = 1 generate
        s_out_data  <= p_in_data;
        s_out_keep  <= p_in_keep;
        s_out_valid <= p_in_valid;
        s_out_last  <= p_in_last;
        p_in_ready  <= s_out_ready;
    end generate GEN_TRIVIAL;

    GEN_NONTRIVIAL : if G_N > 1 generate
        --================================================== Constants ==============================================--
        constant W_OVB                     : natural := (G_OUT_W + 7) / 8;
        --================================================== Functions ==============================================--
        pure function W_VB return natural is
        begin
            if G_SUBWORD then
                return W_OVB * G_N;
            else
                return G_N;
            end if;
        end function;
        --==================================================== Types ================================================--
        type t_pout is array (0 to G_CHANNELS - 1) of std_logic_vector(G_OUT_W - 1 downto 0);
        type t_buffer is array (0 to G_N - 1) of t_pout;
        --================================================== Registers ==============================================--
        signal buff_array, pin_array       : t_buffer;
        signal valids                      : std_logic_vector(W_VB - 1 downto 0);
        signal last_p_in                   : std_logic;
        --==================================================== Wires ================================================--
        signal nx_valids                   : std_logic_vector(valids'range);
        signal valid_words                 : std_logic_vector(G_N - 1 downto 0);
        signal in_fire, out_fire           : boolean;
        signal is_empty                    : boolean;
        signal s_out_valid_o, p_in_ready_o : boolean;
        signal last_or_empty               : std_logic;
    begin

        assert FALSE
        report LF & "PISO instance parameters:" --
        & LF & "  G_OUT_W       " & integer'image(G_OUT_W) --
        & LF & "  G_N           " & integer'image(G_N) --
        & LF & "  G_CHANNELS    " & integer'image(G_CHANNELS) --
        & LF & "  G_SUBWORD     " & boolean'image(G_SUBWORD) --
        & LF & "  G_ASYNC_RSTN  " & boolean'image(G_ASYNC_RSTN) --
        & LF & "  G_BIGENDIAN   " & boolean'image(G_BIGENDIAN) --
        severity NOTE;

        in_fire       <= p_in_valid = '1' and p_in_ready_o;
        out_fire      <= s_out_ready = '1' and s_out_valid_o;
        p_in_ready_o  <= is_empty or (last_or_empty = '1' and s_out_ready = '1');
        s_out_valid_o <= not is_empty;
        p_in_ready    <= '1' when p_in_ready_o else '0';
        s_out_valid   <= '1' when s_out_valid_o else '0';
        is_empty      <= valid_words(0) = '0';
        last_or_empty <= not valid_words(1);
        s_out_last    <= last_p_in and last_or_empty; -- buffer is not empty when s_out_valid = '1'

        GEN_ASYNC_RSTN : if G_ASYNC_RSTN generate
            process(clk, rst) is
            begin
                if rst = '0' then
                    valids(0) <= '0';
                elsif rising_edge(clk) then
                    valids <= nx_valids;
                end if;
            end process;
        end generate GEN_ASYNC_RSTN;
        GEN_NOT_ASYNC_RSTN : if not G_ASYNC_RSTN generate
            process(clk) is
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        valids(0) <= '0';
                    else
                        valids <= nx_valids;
                    end if;
                end if;
            end process;
        end generate GEN_NOT_ASYNC_RSTN;

        GEN_SUBWORD : if G_SUBWORD generate
            signal valids_init : std_logic_vector(W_VB - 1 downto 0);
        begin
            GEN_VALID_WORDS : for i in 0 to G_N - 1 generate
                valid_words(i) <= valids(i * W_OVB);
            end generate;

            nx_valids <= valids_init when in_fire else
                         (W_OVB - 1 downto 0 => '0') & valids(W_VB - 1 downto W_OVB) when out_fire else
                         valids;

            GEN_BIGENDIAN : if G_BIGENDIAN generate
                GEN_REVERSE_IN : for i in p_in_keep'range generate
                    valids_init(i) <= p_in_keep(p_in_keep'length - 1 - i);
                end generate;
                GEN_REVERSE_OUT : for i in s_out_keep'range generate
                    s_out_keep(i) <= valids(W_OVB - 1 - i);
                end generate;
            end generate GEN_BIGENDIAN;
            GEN_NOT_BIGENDIAN : if not G_BIGENDIAN generate
                s_out_keep  <= valids(s_out_keep'range);
                valids_init <= p_in_keep;
            end generate GEN_NOT_BIGENDIAN;

        end generate GEN_SUBWORD;
        GEN_NOT_SUBWORD : if not G_SUBWORD generate
        begin
            valid_words <= valids(valid_words'range);
            nx_valids   <= (others => '1') when in_fire else
                           '0' & valids(valids'high downto 1) when out_fire else
                           valids;
            s_out_keep  <= (others => '1');
        end generate GEN_NOT_SUBWORD;

        GEN_SPLIT_P_IN : for i in 0 to G_N - 1 generate
            GEN_SPLIT_P_IN_CH : for ch in 0 to G_CHANNELS - 1 generate
                alias pd : std_logic_vector is p_in_data((i + ch * G_N + 1) * G_OUT_W - 1 downto (i + ch * G_N) * G_OUT_W);
            begin
                GEN_BIGENDIAN : if G_BIGENDIAN generate
                    pin_array(G_N - 1 - i)(ch) <= pd;
                end generate GEN_BIGENDIAN;
                GEN_NOT_BIGENDIAN : if not G_BIGENDIAN generate
                    pin_array(i)(ch) <= pd;
                end generate GEN_NOT_BIGENDIAN;
            end generate;
        end generate;

        process(clk) is
        begin
            if rising_edge(clk) then
                if in_fire then
                    last_p_in  <= p_in_last;
                    buff_array <= pin_array;
                elsif out_fire then
                    buff_array <= buff_array(1 to buff_array'high) & buff_array(buff_array'high);
                end if;
            end if;
        end process;

        GEN_CONCAT_CH : for ch in 0 to G_CHANNELS - 1 generate
            alias sd : std_logic_vector is s_out_data((ch + 1) * G_OUT_W - 1 downto ch * G_OUT_W);
        begin
            sd <= buff_array(0)(ch);
        end generate GEN_CONCAT_CH;

    end generate GEN_NONTRIVIAL;

end architecture RTL;
