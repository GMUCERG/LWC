--------------------------------------------------------------------------------
--! @file       elastic_reg_fifo.vhd
--! @brief      Reg-based 2-level elastic FIFO for breaking combinational loops
--!                while maintaining full data rate
--! @author     Kamyar Mohajerani (kamyar <at> ieee.org)
--! @copyright  Copyright (c) 2016 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--------------------------------------------------------------------------------
--! Description
--!  Minimal FIFO with no combinational path from inputs to outputs
--!   composed of a pipelined FIFO (fifo0) and a bypassing FIFO (fifo1).
--!   The pipelined FIFO can enque incoming data when full but can't deque while empty
--!   The bypassing FIFO can deque incoming data when empty but can't enque while full
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity elastic_reg_fifo is
    generic (
        W: integer
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        in_data   : in  std_logic_vector(W-1 downto 0); 
        in_valid  : in  std_logic;
        in_ready  : out std_logic;
        out_data  : out std_logic_vector(W-1 downto 0); 
        out_valid : out std_logic;
        out_ready : in  std_logic
    );
end entity;

architecture rtl of elastic_reg_fifo is
    -- registers
    signal data0, data1 : std_logic_vector(W-1 downto 0);
    signal v0, v1       : std_logic;

    -- wires
    signal fifo0_in_ready, fifo1_can_enq: std_logic;
begin

    
    -- FIFO_0: pipelined (can enque even when full and output is ready)
    in_ready <= fifo0_in_ready;
    fifo0_in_ready <= (not v0) or fifo1_can_enq; -- either not full or out is ready
    -- fifo0_out_valid <= v0; -- but can dequeue only when not empty

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                v0 <= '0';
            else
                if fifo0_in_ready = '1' then -- can store
                    v0 <= in_valid;
                    if in_valid = '1' then
                        data0 <= in_data;
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- FIFO_1: bypassing (can dequeue even if empty and input is valid)
    out_data <= data1 when v1 = '1' else data0;
    out_valid <= v0 or v1; -- can dequeue input valid or full
    fifo1_can_enq <= not v1; -- can enque only when not full

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                v1 <= '0';
            else
                if out_ready = '0' then -- can't bypass
                    if v1 = '0' and v0 = '1' then -- will enqueue without bypass (store)
                        data1 <= data0;
                        v1 <= '1';
                    end if;
                else -- deque
                    v1 <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture;