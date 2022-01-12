library ieee;
use ieee.std_logic_1164.all;

use work.NIST_LWAPI_pkg.all;

entity LWC_wrapper is
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        pdi_data        : in  std_logic_vector(W-1 downto 0);
        pdi_valid       : in  std_logic;
        pdi_ready       : out std_logic;
        sdi_data        : in  std_logic_vector(SW-1 downto 0);
        sdi_valid       : in  std_logic;
        sdi_ready       : out std_logic;
        do_data         : out std_logic_vector(W-1 downto 0);
        do_ready        : in  std_logic;
        do_valid        : out std_logic;
        do_last         : out std_logic
    );
end LWC_wrapper;

architecture RTL of LWC_wrapper is
    signal lwc_pdi_data  : std_logic_vector(W-1 downto 0);
    signal lwc_pdi_valid : std_logic;
    signal lwc_pdi_ready : std_logic;
    signal lwc_sdi_data  : std_logic_vector(SW-1 downto 0);
    signal lwc_sdi_valid : std_logic;
    signal lwc_sdi_ready : std_logic;
    signal lwc_do_data   : std_logic_vector(W-1 downto 0);
    signal lwc_do_ready  : std_logic;
    signal lwc_do_valid  : std_logic;
    signal lwc_do_last   : std_logic;
    
    signal do_datalast_i : std_logic_vector(W downto 0);
    signal do_datalast_o : std_logic_vector(W downto 0);

    component LWC
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        pdi_data  : in  std_logic_vector(W - 1 downto 0);
        pdi_valid : in  std_logic;
        pdi_ready : out std_logic;
        sdi_data  : in  std_logic_vector(SW - 1 downto 0);
        sdi_valid : in  std_logic;
        sdi_ready : out std_logic;
        do_data   : out std_logic_vector(W - 1 downto 0);
        do_ready  : in  std_logic;
        do_valid  : out std_logic;
        do_last   : out std_logic
    );
    end component LWC;

    -- for all: LWC use entity work.xyz_LWC;
begin

    assert False report "Using LWC_wrapper" severity warning;
    
    LWC_inst : LWC
        port map(
            clk       => clk,
            rst       => rst,
            pdi_data  => lwc_pdi_data,
            pdi_valid => lwc_pdi_valid,
            pdi_ready => lwc_pdi_ready,
            sdi_data  => lwc_sdi_data,
            sdi_valid => lwc_sdi_valid,
            sdi_ready => lwc_sdi_ready,
            do_data   => lwc_do_data,
            do_ready  => lwc_do_ready,
            do_valid  => lwc_do_valid,
            do_last   => lwc_do_last
        );
    
    elastic_reg_fifo_pdi : entity work.elastic_reg_fifo
        generic map(
            W => W
        )
        port map(
            clk       => clk,
            reset     => rst,
            in_data   => pdi_data,
            in_valid  => pdi_valid,
            in_ready  => pdi_ready,
            out_data  => lwc_pdi_data,
            out_valid => lwc_pdi_valid,
            out_ready => lwc_pdi_ready
        );

    
    elastic_reg_fifo_sdi : entity work.elastic_reg_fifo
        generic map(
            W => SW
        )
        port map(
            clk       => clk,
            reset     => rst,
            in_data   => sdi_data,
            in_valid  => sdi_valid,
            in_ready  => sdi_ready,
            out_data  => lwc_sdi_data,
            out_valid => lwc_sdi_valid,
            out_ready => lwc_sdi_ready
        );
        
    elastic_reg_fifo_do : entity work.elastic_reg_fifo
        generic map(
            W => W+1
        )
        port map(
            clk       => clk,
            reset     => rst,
            in_data   => do_datalast_i,
            in_valid  => lwc_do_valid,
            in_ready  => lwc_do_ready,
            out_data  => do_datalast_o,
            out_valid => do_valid,
            out_ready => do_ready
        );
        
    do_datalast_i <= lwc_do_last & lwc_do_data;
    do_last <= do_datalast_o(W);
    do_data <= do_datalast_o(W-1 downto 0);   
    
end architecture;