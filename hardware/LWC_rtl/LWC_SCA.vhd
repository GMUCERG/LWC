--------------------------------------------------------------------------------
--! @file       LWC.vhd (CAESAR API for Lightweight)
--!
--! @brief      LWC top level file
--!
--! @author     Panasayya Yalla & Ekawat (ice) Homsirikamol
--!             Edited by Kamyar Mohajerani
--!
--! @copyright  Copyright (c) 2022 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--!
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
--------------------------------------------------------------------------------
--! Description
--!
--!
--!   
--!                               ┌────────────┐
--!                            ┌─►│ HeaderFifo ├──┐
--!          ┌──────────────┐  │  └────────────┘  │  ┌───────────────┐
--!          │              ├──┘                  └─►│               │
--!    PDI──►│              │     ┌────────────┐     │               │
--!          │ PreProcessor ├────►│            │     │ PostProcessor ├─►DO
--!    SDI──►│              │     │ CryptoCore ├────►│               │
--!          │              ├────►│            │     │               │
--!          └──────────────┘     └────────────┘     └───────────────┘
--!       
--!
--!
--!
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;
use work.LWC_pkg.all;

entity LWC_SCA is
    port(
        --! Global ports
        clk       : in  std_logic;
        rst       : in  std_logic;
        --! Public data input
        pdi_data  : in  std_logic_vector(PDI_SHARES * W - 1 downto 0);
        pdi_valid : in  std_logic;
        pdi_ready : out std_logic;
        --! Secret data input
        sdi_data  : in  std_logic_vector(SDI_SHARES * SW - 1 downto 0);
        sdi_valid : in  std_logic;
        sdi_ready : out std_logic;
        --! Data out ports
        do_data   : out std_logic_vector(PDI_SHARES * W - 1 downto 0);
        do_ready  : in  std_logic;
        do_valid  : out std_logic;
        do_last   : out std_logic;
        --! Random Input
        rdi_data  : in  std_logic_vector(RW - 1 downto 0);
        rdi_valid : in  std_logic;
        rdi_ready : out std_logic
    );
end LWC_SCA;

architecture structure of LWC_SCA is
    ------!Pre-Processor to CryptoCore (Key PISO)
    signal key_cipher_in              : std_logic_vector(SDI_SHARES * CCSW - 1 downto 0);
    signal key_valid_cipher_in        : std_logic;
    signal key_ready_cipher_in        : std_logic;
    ------!Pre-Processor to CryptoCore (DATA PISO)
    signal bdi_cipher_in              : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdi_valid_cipher_in        : std_logic;
    signal bdi_ready_cipher_in        : std_logic;
    --
    signal bdi_pad_loc_cipher_in      : std_logic_vector(CCW / 8 - 1 downto 0);
    signal bdi_valid_bytes_cipher_in  : std_logic_vector(CCW / 8 - 1 downto 0);
    signal bdi_size_cipher_in         : std_logic_vector(3 - 1 downto 0);
    signal bdi_eot_cipher_in          : std_logic;
    signal bdi_eoi_cipher_in          : std_logic;
    signal bdi_type_cipher_in         : std_logic_vector(4 - 1 downto 0);
    signal decrypt_cipher_in          : std_logic;
    signal hash_cipher_in             : std_logic;
    signal key_update_cipher_in       : std_logic;
    ------!CryptoCore(DATA SIPO) to Post-Processor
    signal bdo_cipher_out             : std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
    signal bdo_valid_cipher_out       : std_logic;
    signal bdo_ready_cipher_out       : std_logic;
    ------!CryptoCore to Post-Processor
    signal end_of_block_cipher_out    : std_logic;
    signal bdo_valid_bytes_cipher_out : std_logic_vector(CCW / 8 - 1 downto 0);
    signal bdo_type_cipher_out        : std_logic_vector(4 - 1 downto 0);
    signal msg_auth_valid             : std_logic;
    signal msg_auth_ready             : std_logic;
    signal msg_auth                   : std_logic;
    ------!Pre-Processor to FIFO
    signal cmd_FIFO_in                : std_logic_vector(W - 1 downto 0);
    signal cmd_valid_FIFO_in          : std_logic;
    signal cmd_ready_FIFO_in          : std_logic;
    ------!FIFO to Post_Processor
    signal cmd_FIFO_out               : std_logic_vector(W - 1 downto 0);
    signal cmd_valid_FIFO_out         : std_logic;
    signal cmd_ready_FIFO_out         : std_logic;

    --==========================================================================

    component CryptoCore_SCA
        port(
            clk             : in  STD_LOGIC;
            rst             : in  STD_LOGIC;
            key             : in  STD_LOGIC_VECTOR(SDI_SHARES * CCSW - 1 downto 0);
            key_update      : in  STD_LOGIC;
            key_valid       : in  STD_LOGIC;
            key_ready       : out STD_LOGIC;
            bdi             : in  STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
            bdi_valid       : in  STD_LOGIC;
            bdi_ready       : out STD_LOGIC;
            bdi_pad_loc     : in  STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
            bdi_valid_bytes : in  STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
            bdi_size        : in  STD_LOGIC_VECTOR(3 - 1 downto 0);
            bdi_eot         : in  STD_LOGIC;
            bdi_eoi         : in  STD_LOGIC;
            bdi_type        : in  STD_LOGIC_VECTOR(4 - 1 downto 0);
            decrypt_in      : in  STD_LOGIC;
            hash_in         : in  std_logic;
            bdo             : out STD_LOGIC_VECTOR(PDI_SHARES * CCW - 1 downto 0);
            bdo_valid       : out STD_LOGIC;
            bdo_ready       : in  STD_LOGIC;
            bdo_type        : out STD_LOGIC_VECTOR(4 - 1 downto 0);
            bdo_valid_bytes : out STD_LOGIC_VECTOR(CCW / 8 - 1 downto 0);
            end_of_block    : out STD_LOGIC;
            --
            msg_auth_valid  : out STD_LOGIC;
            msg_auth_ready  : in  STD_LOGIC;
            msg_auth        : out STD_LOGIC;
            --! Random Input
            rdi_data        : in  std_logic_vector(RW - 1 downto 0);
            rdi_valid       : in  std_logic;
            rdi_ready       : out std_logic
        );
    end component;

begin
    -- synthesis translate_off
    assert false report "[LWC]" & LF & "  GW=" & integer'image(W) & "  SW=" & integer'image(SW) & LF & "  CCW=" & integer'image(CCW) & " CCSW=" & integer'image(CCSW) severity note;
    -- synthesis translate_on

    -- The following combinations (W, CCW) are supported in the current version
    -- of the Development Package: (32, 32), (32, 16), (32, 8), (16, 16), and (8, 8).
    -- The following combinations (SW, CCSW) are supported: (32, 32), (32, 16),
    -- (32, 8), (16, 16), and (8, 8). In addition, W and SW must be always the same.

    assert ((W = 32 and (CCW = 32 or CCW = 16 or CCW = 8)) or (W = 16 and CCW = 16) or (W = 8 and CCW = 8))
    report "[LWC] Invalid combination of (G_W, CCW)" severity failure;
    --
    assert ((SW = 32 and (CCSW = 32 or CCSW = 16 or CCSW = 8)) or (SW = 16 and CCSW = 16) or (SW = 8 and CCSW = 8))
    report "[LWC] Invalid combination of (SW, CCSW)" severity failure;
    --
    assert W = SW report "[LWC] SW /= W" severity failure;

    -- ASYNC_RSTN notification
    assert not ASYNC_RSTN report "[LWC] ASYNC_RSTN=True: reset is configured as asynchronous and active-low" severity note;

    Inst_PreProcessor : entity work.PreProcessor
        port map(
            clk             => clk,
            rst             => rst,
            --
            pdi_data        => pdi_data,
            pdi_valid       => pdi_valid,
            pdi_ready       => pdi_ready,
            --
            sdi_data        => sdi_data,
            sdi_valid       => sdi_valid,
            sdi_ready       => sdi_ready,
            --
            key_data        => key_cipher_in,
            key_valid       => key_valid_cipher_in,
            key_ready       => key_ready_cipher_in,
            --
            key_update      => key_update_cipher_in,
            --
            bdi_data        => bdi_cipher_in,
            bdi_valid_bytes => bdi_valid_bytes_cipher_in,
            bdi_pad_loc     => bdi_pad_loc_cipher_in,
            bdi_size        => bdi_size_cipher_in,
            bdi_eot         => bdi_eot_cipher_in,
            bdi_eoi         => bdi_eoi_cipher_in,
            bdi_type        => bdi_type_cipher_in,
            bdi_valid       => bdi_valid_cipher_in,
            bdi_ready       => bdi_ready_cipher_in,
            --
            decrypt         => decrypt_cipher_in,
            hash            => hash_cipher_in,
            --
            cmd_data        => cmd_FIFO_in,
            cmd_valid       => cmd_valid_FIFO_in,
            cmd_ready       => cmd_ready_FIFO_in
        );

    Inst_CryptoCore : CryptoCore_SCA
        port map(
            clk             => clk,
            rst             => rst,
            key             => key_cipher_in,
            key_valid       => key_valid_cipher_in,
            key_ready       => key_ready_cipher_in,
            bdi             => bdi_cipher_in,
            bdi_valid       => bdi_valid_cipher_in,
            bdi_ready       => bdi_ready_cipher_in,
            bdi_pad_loc     => bdi_pad_loc_cipher_in,
            bdi_valid_bytes => bdi_valid_bytes_cipher_in,
            bdi_size        => bdi_size_cipher_in,
            bdi_eot         => bdi_eot_cipher_in,
            bdi_eoi         => bdi_eoi_cipher_in,
            bdi_type        => bdi_type_cipher_in,
            decrypt_in      => decrypt_cipher_in,
            key_update      => key_update_cipher_in,
            hash_in         => hash_cipher_in,
            bdo             => bdo_cipher_out,
            bdo_valid       => bdo_valid_cipher_out,
            bdo_ready       => bdo_ready_cipher_out,
            bdo_type        => bdo_type_cipher_out,
            bdo_valid_bytes => bdo_valid_bytes_cipher_out,
            end_of_block    => end_of_block_cipher_out,
            msg_auth_valid  => msg_auth_valid,
            msg_auth_ready  => msg_auth_ready,
            msg_auth        => msg_auth,
            rdi_data        => rdi_data,
            rdi_valid       => rdi_valid,
            rdi_ready       => rdi_ready
        );

    Inst_PostProcessor : entity work.PostProcessor
        port map(
            clk             => clk,
            rst             => rst,
            bdo_data        => bdo_cipher_out,
            bdo_valid       => bdo_valid_cipher_out,
            bdo_ready       => bdo_ready_cipher_out,
            bdo_last        => end_of_block_cipher_out,
            bdo_type        => bdo_type_cipher_out,
            bdo_valid_bytes => bdo_valid_bytes_cipher_out,
            auth_success    => msg_auth,
            auth_ready      => msg_auth_ready,
            auth_valid      => msg_auth_valid,
            cmd_data        => cmd_FIFO_out,
            cmd_valid       => cmd_valid_FIFO_out,
            cmd_ready       => cmd_ready_FIFO_out,
            do_data         => do_data,
            do_valid        => do_valid,
            do_last         => do_last,
            do_ready        => do_ready
        );

    Inst_HeaderFifo : entity work.fwft_fifo
        generic map(
            G_W         => W,
            G_LOG2DEPTH => 2
        )
        port map(
            clk        => clk,
            rst        => rst,
            din        => cmd_FIFO_in,
            din_valid  => cmd_valid_FIFO_in,
            din_ready  => cmd_ready_FIFO_in,
            dout       => cmd_FIFO_out,
            dout_valid => cmd_valid_FIFO_out,
            dout_ready => cmd_ready_FIFO_out
        );

end architecture;
