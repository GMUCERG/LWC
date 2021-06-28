library ieee;
use ieee.std_logic_1164.all;

use work.NIST_LWAPI_pkg.all;

entity LWC_2pass_wrapper is
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
        do_last         : out std_logic;
        fdi_data        : in  std_logic_vector(W-1 downto 0);
        fdi_valid       : in  std_logic;
        fdi_ready       : out std_logic;
        fdo_data        : out std_logic_vector(W-1 downto 0);
        fdo_valid       : out std_logic;
        fdo_ready       : in  std_logic
    );
end LWC_2pass_wrapper;

architecture RTL of LWC_2pass_wrapper is
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
    signal lwc_fdi_data  : std_logic_vector(W-1 downto 0);
    signal lwc_fdi_valid : std_logic;
    signal lwc_fdi_ready : std_logic;
    signal lwc_fdo_data  : std_logic_vector(W-1 downto 0);
    signal lwc_fdo_valid : std_logic;
    signal lwc_fdo_ready : std_logic;
    
    signal do_datalast_i : std_logic_vector(W downto 0);
    signal do_datalast_o : std_logic_vector(W downto 0);

    component LWC_2pass
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
        do_last   : out std_logic;
        fdi_data  : in  std_logic_vector(W - 1 downto 0);
        fdi_valid : in  std_logic;
        fdi_ready : out std_logic;
        fdo_data  : out std_logic_vector(W - 1 downto 0);
        fdo_valid : out std_logic;
        fdo_ready : in  std_logic
    );
    end component LWC_2pass;

begin

    assert False report "Using LWC_2pass_wrapper" severity warning;
    
    LWC_inst : LWC_2pass
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
            do_last   => lwc_do_last,
            fdi_data  => lwc_fdi_data,
            fdi_valid => lwc_fdi_valid,
            fdi_ready => lwc_fdi_ready,
            fdo_data  => lwc_fdo_data,
            fdo_valid => lwc_fdo_valid,
            fdo_ready => lwc_fdo_ready
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

    elastic_reg_fifo_fdi : entity work.elastic_reg_fifo
        generic map(
            W => W
        )
        port map(
            clk       => clk,
            reset     => rst,
            in_data   => fdi_data,
            in_valid  => fdi_valid,
            in_ready  => fdi_ready,
            out_data  => lwc_fdi_data,
            out_valid => lwc_fdi_valid,
            out_ready => lwc_fdi_ready
        );       

    elastic_reg_fifo_fdo : entity work.elastic_reg_fifo
        generic map(
            W => W
        )
        port map(
            clk       => clk,
            reset     => rst,
            in_data   => lwc_fdo_data,
            in_valid  => lwc_fdo_valid,
            in_ready  => lwc_fdo_ready,
            out_data  => fdo_data,
            out_valid => fdo_valid,
            out_ready => fdo_ready
        );
        
    do_datalast_i <= lwc_do_last & lwc_do_data;
    do_last <= do_datalast_o(W);
    do_data <= do_datalast_o(W-1 downto 0);  
    
end architecture;