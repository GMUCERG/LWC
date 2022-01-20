library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.LWC_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity FIFO is
    generic(
        G_W     : natural;
        G_DEPTH : natural
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
    type t_storage is array (0 to G_DEPTH - 1) of std_logic_vector(G_W - 1 downto 0);
    -- registers
    signal storage : t_storage;
begin
    GEN_SYNC_RST : if not ASYNC_RSTN generate
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                else
                end if;
            end if;
        end process;
    end generate;

    GEN_ASYNC_RSTN : if ASYNC_RSTN generate
        process(clk, rst)
        begin
            if rst = '0' then
            elsif rising_edge(clk) then
            end if;
        end process;
    end generate;

    GEN_DEPTH_0 : if G_DEPTH = 0 generate
        dout       <= din;
        dout_valid <= din_valid;
        din_ready  <= dout_ready;
    end generate;
    GEN_DEPTH_1 : if G_DEPTH = 1 generate
        --=== Registers ==--
        signal full                      : std_logic;
        --=== Wires ==--
        signal dout_valid_o, din_ready_o : std_logic;
    begin
        dout_valid   <= dout_valid_o;
        din_ready    <= din_ready_o;
        dout_valid_o <= full;
        din_ready_o  <= not full or dout_ready;
        dout         <= storage(0);

        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    full <= '0';
                elsif din_valid = '1' and din_ready_o = '1' then
                    storage(0) <= din;
                    full       <= '1';
                elsif dout_valid_o = '1' and dout_ready = '1' then
                    full <= '0';
                end if;
            end if;
        end process;
    end generate;
    GEN_DEPTH_2 : if G_DEPTH = 2 generate -- implement as an "elastic" FIFO
        --!  Implements a FIFO of depth 2 with no combinational path from inputs to outputs
        --!   (neither data nor ready/valid control signals)
        --!   composed of a pipelined FIFO (fifo0) and a bypassing FIFO (fifo1).
        --!   The pipelined FIFO can enqueue incoming data when full but can't dequeue while empty
        --!   The bypassing FIFO can dequeue incoming data when empty but can't enqueue while full
        -- registers
        signal filled  : unsigned(0 to G_DEPTH - 1);
        -- wires
        signal din_ready_o : std_logic;
    begin
        din_ready_o <= not lwc_and_reduce(filled);
        din_ready   <= din_ready_o;
        dout        <= storage(1) when filled(1) = '1' else storage(0);
        dout_valid  <= lwc_or_reduce(filled); -- can dequeue input valid or full

        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    filled <= (others => '0');
                else
                    if din_ready_o = '1' then -- enqueue (enq fifo1)
                        filled(0) <= din_valid;
                        if din_valid = '1' then -- optional (to save power or isolate invalid data)
                            storage(0) <= din;
                        end if;
                    end if;
                    if dout_ready = '1' then -- dequeue if not empty (deq fifo1 or fifo0)
                        filled(1) <= '0';
                    elsif filled(1) = '0' then -- shift, possibly with enqueue (enq fifo1)
                        storage(1) <= storage(0);
                        filled(1)  <= filled(0);
                    end if;
                end if;
            end if;
        end process;
    end generate;
    GEN_DEPTH_GT_2 : if G_DEPTH > 2 generate -- implement as circular buffer
        assert false severity failure;
    end generate;

end architecture;
