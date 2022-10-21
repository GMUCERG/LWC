--===============================================================================================--
--! @file          fifo.vhd
--! @brief         Versatile FIFO
--!
--! @author        Kamyar Mohajerani
--!
--! @copyright     Copyright (c) 2022 Cryptographic Engineering Research Group
--!                ECE Department, George Mason University Fairfax, VA, U.S.A.
--!                All rights Reserved.
--!
--! @license       This work is dual-licensed under Solderpad Hardware License v2.1 (SHL-2.1) and
--!                   GNU General Public License v3.0 (GPL-3.0)
--!                For more information please see:
--!                   Solderpad Hardware License v2.1:  https://spdx.org/licenses/SHL-2.1.html and
--!                   GNU General Public License v3.0:  https://spdx.org/licenses/GPL-3.0.html
--!
--! @note          This is publicly available encryption source code that falls
--!                under the License Exception TSU (Technology and software-
--!                unrestricted)
--!
--! @vhdl          1993, 2002, 2008
--!
--! @description   Optimized pipelined FIFO: supports concurrent enqueue and dequeue when full
--!
--! @parameter     G_DEPTH: depth of the FIFO. Specifies the number of storage elements.
--!                     MUST be either 0 or a power of 2
--!                     depending on the value for G_DEPTH an optimized implementation is chosen:
--!                     0: directly connect inputs and outputs (0 delay, 0 resource utilization)
--!                     1: pipelined register FIFO
--!                     2 and G_ELASTIC_2: elastic FIFO fully isolating control and datapath
--!                     G_DEPTH > 2 (or 2 and not G_ELASTIC_2): pipelined circular buffer
--!
--!
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;

entity FIFO is
    generic(
        G_W         : natural;
        G_DEPTH     : natural;
        G_ELASTIC_2 : boolean := TRUE;
        G_RAM_STYLE : string  := "distributed"
    );
    port(
        clk        : in  std_logic;
        rst        : in  std_logic;
        --
        din        : in  std_logic_vector(G_W - 1 downto 0);
        din_valid  : in  std_logic;
        din_ready  : out std_logic;
        --
        dout       : out std_logic_vector(G_W - 1 downto 0);
        dout_valid : out std_logic;
        dout_ready : in  std_logic
    );
end entity;

architecture RTL of FIFO is
    constant DEPTH_BITS : natural := log2ceil(G_DEPTH);
    --
    type t_storage is array (0 to G_DEPTH - 1) of std_logic_vector(G_W - 1 downto 0);
    -- registers
    signal storage      : t_storage;

    attribute ram_style : string;
    attribute ram_style of storage : signal is G_RAM_STYLE;
begin

    assert G_DEPTH = 0 or 2 ** DEPTH_BITS = G_DEPTH report "G_DEPTH must be either 0 or a power of 2" severity failure;

    GEN_DEPTH_0 : if G_DEPTH = 0 generate
        dout       <= din;
        dout_valid <= din_valid;
        din_ready  <= dout_ready;
    end generate;
    GEN_DEPTH_1 : if G_DEPTH = 1 generate
        --======================================= Registers =========================================--
        signal full                      : std_logic;
        --========================================= Wires ===========================================--
        signal dout_valid_o, din_ready_o : std_logic;
        signal enq, deq                  : boolean;
    begin
        dout_valid   <= dout_valid_o;
        din_ready    <= din_ready_o;
        dout_valid_o <= full;
        din_ready_o  <= not full or dout_ready;
        enq          <= din_valid = '1' and din_ready_o = '1';
        deq          <= dout_valid_o = '1' and dout_ready = '1';
        dout         <= storage(0);
        GEN_SYNC_RST : if not ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        full <= '0';
                    elsif enq then
                        full <= '1';
                    elsif deq then
                        full <= '0';
                    end if;
                end if;
            end process;
        end generate;

        GEN_ASYNC_RSTN : if ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    full <= '0';
                elsif rising_edge(clk) then
                    if enq then
                        full <= '1';
                    elsif deq then
                        full <= '0';
                    end if;
                end if;
            end process;
        end generate;
        --
        process(clk)
        begin
            if rising_edge(clk) then
                if enq then
                    storage(0) <= din;
                end if;
            end if;
        end process;
    end generate;
    GEN_DEPTH_2 : if G_DEPTH = 2 and G_ELASTIC_2 generate
        -----------------------------------------------------------------------------------------------
        --!  Implements a FIFO of depth 2 with no combinational path from inputs to outputs
        --!   (neither data nor ready/valid control signals)
        --!   composed of a pipelined FIFO (fifo0) and a bypassing FIFO (fifo1).
        --!   The pipelined FIFO can enqueue incoming data when full but can't dequeue while empty
        --!   The bypassing FIFO can dequeue incoming data when empty but can't enqueue while full
        --!  Operates at full bandwith at a half-empty state
        ---------------------------------------------------------------------------------------------------

        --======================================= Registers =========================================--
        signal filled      : unsigned(0 to G_DEPTH - 1);
        --========================================= Wires ===========================================--
        signal filled_nxt  : unsigned(0 to G_DEPTH - 1);
        signal din_ready_o : std_logic;
    begin
        din_ready_o <= not (filled(0) and filled(1));
        din_ready   <= din_ready_o;
        dout        <= storage(1) when filled(1) = '1' else storage(0);
        dout_valid  <= filled(0) or filled(1);

        assert false report "Isolating FIFO of depth 2" severity note; -- print information

        -- update registers with a reset
        GEN_SYNC_RST : if not ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        filled <= (others => '0');
                    else
                        filled <= filled_nxt;
                    end if;
                end if;
            end process;
        end generate;
        GEN_ASYNC_RSTN : if ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    filled <= (others => '0');
                elsif rising_edge(clk) then
                    filled <= filled_nxt;
                end if;
            end process;
        end generate;

        process(filled, din_valid, din_ready_o, dout_ready)
        begin
            -- default reg feedback
            filled_nxt <= filled;
            if din_ready_o = '1' then   -- set or clear
                filled_nxt(0) <= din_valid;
            end if;
            if dout_ready = '1' then    -- dequeue
                filled_nxt(1) <= '0';
            elsif filled(1) = '0' then
                -- shift, possibly with enqueue (enq fifo1)
                filled_nxt(1) <= filled(0);
            end if;
        end process;

        -- update registers without reset (storage)
        process(clk)
        begin
            if rising_edge(clk) then
                if din_valid = '1' and din_ready_o = '1' then
                    storage(0) <= din;
                end if;
                -- dequeue if not empty (deq fifo1 or fifo0)
                -- shift, possibly with enqueue (enq fifo1)
                if dout_ready = '0' and filled(1) = '0' then
                    storage(1) <= storage(0);
                end if;
            end if;
        end process;
    end generate;

    -- for depth > 2 (or non-isolating depth=2) implement as circular buffer
    GEN_DEPTH_GT_2 : if (G_DEPTH > 2 or (G_DEPTH = 2 and not G_ELASTIC_2)) and G_RAM_STYLE /= "block" generate
        -- registers
        signal rd_ptr, wr_ptr            : unsigned(DEPTH_BITS - 1 downto 0);
        signal empty                     : std_logic;
        --========================================= Wires ===========================================--
        signal next_rd_ptr               : unsigned(DEPTH_BITS - 1 downto 0);
        signal enq, deq                  : std_logic;
        signal din_ready_o, dout_valid_o : std_logic; -- VHDL < 2008 compatibility
    begin
        assert FALSE report "FIFO of depth " & -- print information
        integer'image(G_DEPTH) & " implemented as circular buffer" severity note;

        din_ready    <= din_ready_o;
        dout_valid   <= dout_valid_o;
        enq          <= din_valid and din_ready_o;
        deq          <= dout_valid_o and dout_ready;
        din_ready_o  <= empty or to_std_logic(rd_ptr /= wr_ptr); -- not full
        dout_valid_o <= not empty;
        next_rd_ptr  <= rd_ptr + 1;     -- mod (2 ** DEPTH_BITS)

        -- `empty` is the only register which requires a reset
        -- synchronous active-high reset
        GEN_SYNC_RST : if not ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        empty <= '1';
                    elsif empty = '1' then
                        if enq = '1' then
                            empty <= '0';
                        end if;
                    elsif deq = '1' and enq = '0' and next_rd_ptr = wr_ptr then
                        empty <= '1';
                    end if;
                end if;
            end process;
        end generate;
        -- asynchronous active-low reset
        GEN_ASYNC_RSTN : if ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    empty <= '1';
                elsif rising_edge(clk) then
                    if empty = '1' then
                        if enq = '1' then
                            empty <= '0';
                        end if;
                    elsif deq = '1' and enq = '0' and next_rd_ptr = wr_ptr then
                        empty <= '1';
                    end if;
                end if;
            end process;
        end generate;

        process(clk)
        begin
            if rising_edge(clk) then
                if empty = '1' then
                    rd_ptr <= (others => '0');
                    if enq = '1' then
                        storage(0) <= din;
                        wr_ptr     <= (0 => '1', others => '0');
                    else
                        wr_ptr <= (others => '0');
                    end if;
                else
                    if enq = '1' then
                        storage(to_integer(to_01(wr_ptr))) <= din;
                        wr_ptr                             <= wr_ptr + 1; -- mod (2 ** DEPTH_BITS)
                    end if;
                    if deq = '1' then
                        rd_ptr <= next_rd_ptr;
                    end if;
                end if;
            end if;
        end process;
        dout <= storage(to_integer(to_01(rd_ptr)));
    end generate;

    GEN_BRAM : if (G_DEPTH > 2 or (G_DEPTH = 2 and not G_ELASTIC_2)) and G_RAM_STYLE = "block" generate

        constant G_OUT_REG: boolean := TRUE; -- TODO: add as generic?

        --======================================== Registers =========================================--
        signal is_full           : boolean;
        signal dequeued_is_valid : std_logic;
        signal rd_ptr, wr_ptr    : unsigned(log2ceil(G_DEPTH) - 1 downto 0);

        --========================================== Wires ============================================--
        signal next_rd_ptr                : unsigned(rd_ptr'range);
        signal next_wr_ptr                : unsigned(wr_ptr'range);
        signal write_en, read_en, overlap : boolean;
        signal almost_full  : boolean;
        signal can_deq                    : boolean;
        signal read_data                  : std_logic_vector(G_W - 1 downto 0);
        signal out_ready, enq_ready_o     : std_logic;

    begin

        assert FALSE report LF & "[FIFO] Block RAM" severity NOTE;

        next_rd_ptr <= rd_ptr + 1;            -- mod (2 ** DEPTH_BITS)
        next_wr_ptr <= wr_ptr + 1;            -- mod (2 ** DEPTH_BITS)

        overlap     <= rd_ptr = wr_ptr;
        almost_full <= next_wr_ptr = rd_ptr;

        can_deq     <= is_full or not overlap;
        enq_ready_o <= '0' when is_full else '1';
        write_en    <= din_valid = '1' and enq_ready_o = '1';
        read_en     <= can_deq and (dequeued_is_valid = '0' or out_ready = '1');
        din_ready   <= enq_ready_o;

        process(clk) is
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    is_full           <= FALSE;
                    dequeued_is_valid <= '0';
                    rd_ptr            <= (others => '0');
                    wr_ptr            <= (others => '0');
                else
                    if write_en then
                        if not read_en and almost_full then
                            is_full <= TRUE;
                        end if;
                        wr_ptr <= next_wr_ptr;
                    end if;
                    if read_en then
                        dequeued_is_valid <= '1';
                        if not write_en then
                            is_full <= FALSE;
                        end if;
                        rd_ptr <= next_rd_ptr;
                    elsif out_ready = '1' then
                        dequeued_is_valid <= '0';
                    end if;
                end if;
            end if;
        end process;

        process(clk) is
        begin
            if rising_edge(clk) then
                if write_en then
                    storage(to_int01(wr_ptr)) <= din;
                end if;
                if read_en then
                    read_data <= storage(to_int01(rd_ptr));
                end if;
            end if;
        end process;

        GEN_OUTREG : if G_OUT_REG generate
            --======================================== Registers ==========================================--
            signal out_reg       : std_logic_vector(G_W - 1 downto 0);
            signal out_reg_valid : std_logic;   -- := FALSE;

        begin
            dout  <= out_reg;
            dout_valid <= out_reg_valid;
            out_ready <= not out_reg_valid or dout_ready;

            process(clk) is
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        out_reg_valid <= '0';
                    elsif dout_ready = '1' or out_reg_valid = '0' then
                        out_reg       <= read_data;
                        out_reg_valid <= dequeued_is_valid;
                    end if;
                end if;
            end process;
        end generate;

        GEN_NO_OUTREG : if not G_OUT_REG generate
            dout  <= read_data;
            dout_valid <= dequeued_is_valid;
            out_ready <= dout_ready;
        end generate;

    end generate;

end architecture;
