--------------------------------------------------------------------------------
--! @file       fwft_fifo_tb.vhd
--! @brief      Simple First-In-First_Out
--!
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!--------------------------------------------------------------------------------
--! @file       fwft_fifo.vhd
--! @brief      Simple First-In-First_Out
--!
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NIST_LWAPI_pkg.all;

entity fwft_fifo_tb is
	generic(
        G_W         : integer; --! Width of I/O (bits)
        G_LOG2DEPTH : integer  --! LOG(2) of depth
    );
    port(
        clk         : in    std_logic;
        rst         : in    std_logic;

        -- Input Port
        din         : in    std_logic_vector(G_W - 1 downto 0);
        din_valid   : in    std_logic;
        din_ready   : out   std_logic;

        -- Output Port
        dout        : out   std_logic_vector(G_W - 1 downto 0);
        dout_valid  : out   std_logic;
        dout_ready  : in    std_logic
    );
end entity fwft_fifo_tb;

architecture tb_use_only of fwft_fifo_tb is

begin
	fwft_fifo_inst : entity work.fwft_fifo(structure)
		generic map(
			G_W         => G_W,
			G_LOG2DEPTH => G_LOG2DEPTH
		)
		port map(
			clk        => clk,
			rst        => rst,
			din        => din,
			din_valid  => din_valid,
			din_ready  => din_ready,
			dout       => dout,
			dout_valid => dout_valid,
			dout_ready => dout_ready
		);	
end architecture tb_use_only;
