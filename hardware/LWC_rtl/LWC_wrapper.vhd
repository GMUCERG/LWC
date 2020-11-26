library ieee;
use ieee.std_logic_1164.all;

use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity LWC_wrapper is
    port (
        --! Global ports
        clk             : in  std_logic;
        rst             : in  std_logic;
        --! Publica data ports
        pdi_data        : in  std_logic_vector(W-1 downto 0);
        pdi_valid       : in  std_logic;
        pdi_ready       : out std_logic;
        --! Secret data ports
        -- NOTE for future dev: this G_W is really SW!
        sdi_data        : in  std_logic_vector(SW-1 downto 0);
        sdi_valid       : in  std_logic;
        sdi_ready       : out std_logic;
        --! Data out ports
        do_data         : out std_logic_vector(W-1 downto 0);
        do_ready        : in  std_logic;
        do_valid        : out std_logic;
        do_last         : out std_logic
    );
end LWC_wrapper;

architecture RTL of LWC_wrapper is
begin
    
end architecture;