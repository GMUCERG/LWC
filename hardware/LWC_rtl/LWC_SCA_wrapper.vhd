library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.LWC_config.all;

entity LWC_SCA_wrapper is
  generic(
    XRW             : natural  := 0;
    XW              : natural  := 32;
    PDI_FIFO_DEPTH  : positive := 2;
    SDI_FIFO_DEPTH  : positive := 2;
    DO_FIFO_DEPTH   : positive := 2;
    FIFOS_OUT_REG   : boolean  := TRUE;
    FIFOS_RAM_STYLE : string   := "block"
  );
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    --! all inputs
    pdi_data    : in  std_logic_vector(XW - 1 downto 0);
    pdi_valid   : in  std_logic;
    pdi_ready   : out std_logic;
    --! Secret data input
    sdi_data    : in  std_logic_vector(XW - 1 downto 0);
    sdi_valid   : in  std_logic;
    sdi_ready   : out std_logic;
    --! Data out ports
    do_data     : out std_logic_vector(XW - 1 downto 0);
    do_last     : out std_logic := '0';
    do_valid    : out std_logic;
    do_ready    : in  std_logic;
    --! Random Input
    rdi_data    : in  std_logic_vector(XRW - 1 downto 0) := (others => '-'); -- external RW
    rdi_valid   : in  std_logic := '0';
    rdi_ready   : out std_logic;
    --
    in_enable   : in  std_logic := '1';
    lwc_do_fire : out std_logic
  );

  attribute keep_hierarchy : string;

end entity LWC_SCA_wrapper;

architecture RTL of LWC_SCA_wrapper is
  --! Returns the number of bits required to represet values less than n (0 to n - 1 inclusive)
  function log2ceil(n : natural) return natural is
    variable pow2 : positive := 1;
    variable r    : natural  := 0;
  begin
    while n > pow2 loop
      pow2 := pow2 * 2;
      r    := r + 1;
    end loop;
    return r;
  end function;

  constant XSW: natural := XW;

  signal lwc_pdi_data : std_logic_vector(PDI_SHARES * W - 1 downto 0);
  signal lwc_sdi_data : std_logic_vector(SDI_SHARES * SW - 1 downto 0);
  signal lwc_do_data  : std_logic_vector(PDI_SHARES * W - 1 downto 0);
  signal lwc_rdi_data : std_logic_vector(RW - 1 downto 0);

  signal lwc_rdi_valid, lwc_rdi_ready            : std_logic;
  signal lwc_pdi_valid, lwc_pdi_ready            : std_logic;
  signal pdi_fifo_valid, pdi_fifo_ready          : std_logic;
  signal sdi_fifo_valid, sdi_fifo_ready          : std_logic;
  signal do_fifo_valid, do_fifo_ready            : std_logic;
  signal lwc_sdi_valid, lwc_sdi_ready            : std_logic;
  signal lwc_do_valid, lwc_do_ready, lwc_do_last : std_logic;

  attribute keep_hierarchy of INST_LWC : label is "yes";
begin

  lwc_do_fire   <= lwc_do_valid and lwc_do_ready;
  do_fifo_valid <= lwc_do_valid;
  lwc_do_ready  <= do_fifo_ready;

  lwc_pdi_valid  <= pdi_fifo_valid and in_enable and lwc_rdi_valid;
  pdi_fifo_ready <= lwc_pdi_ready and in_enable and lwc_rdi_valid;
  --
  lwc_sdi_valid  <= sdi_fifo_valid and in_enable and lwc_rdi_valid;
  sdi_fifo_ready <= lwc_sdi_ready and in_enable and lwc_rdi_valid;


  INST_PDI_FIFO : entity work.asym_fifo
    generic map(
      G_WR_W      => XW,
      G_RD_W      => PDI_SHARES * W,
      G_CAPACITY  => 2 ** log2ceil(PDI_FIFO_DEPTH * PDI_SHARES * W),
      G_OUT_REG   => FIFOS_OUT_REG,
      G_RAM_STYLE => FIFOS_RAM_STYLE
    )
    port map(
      clk       => clk,
      rst       => rst,
      enq_data  => pdi_data,
      enq_valid => pdi_valid,
      enq_ready => pdi_ready,
      deq_data  => lwc_pdi_data,
      deq_valid => pdi_fifo_valid,
      deq_ready => pdi_fifo_ready
    );

  INST_SDI_FIFO : entity work.asym_fifo
    generic map(
      G_WR_W      => XSW,
      G_RD_W      => SDI_SHARES * SW,
      G_CAPACITY  => 2 ** log2ceil(SDI_FIFO_DEPTH * SDI_SHARES * SW),
      G_OUT_REG   => FIFOS_OUT_REG,
      G_RAM_STYLE => FIFOS_RAM_STYLE
    )
    port map(
      clk       => clk,
      rst       => rst,
      enq_data  => sdi_data,
      enq_valid => sdi_valid,
      enq_ready => sdi_ready,
      deq_data  => lwc_sdi_data,
      deq_valid => sdi_fifo_valid,
      deq_ready => sdi_fifo_ready
    );

  INST_DO_FIFO : entity work.asym_fifo
    generic map(
      G_WR_W      => PDI_SHARES * W,
      G_RD_W      => XW,
      G_CAPACITY  => 2 ** log2ceil(DO_FIFO_DEPTH * PDI_SHARES * W),
      G_OUT_REG   => FIFOS_OUT_REG,
      G_RAM_STYLE => FIFOS_RAM_STYLE
    )
    port map(
      clk       => clk,
      rst       => rst,
      enq_data  => lwc_do_data,
      enq_valid => do_fifo_valid,
      enq_ready => do_fifo_ready,
      deq_data  => do_data,
      deq_valid => do_valid,
      deq_ready => do_ready
    );

  INST_LFSR : entity work.LFSR
    generic map(
      G_IN_BITS  => XRW,
      G_OUT_BITS => RW
    )
    port map(
      clk        => clk,
      rst        => rst,
      --
      reseed     => '0',
      --
      rin_data   => rdi_data,
      rin_valid  => rdi_valid,
      rin_ready  => rdi_ready,
      --
      rout_data  => lwc_rdi_data,
      rout_valid => lwc_rdi_valid,
      rout_ready => lwc_rdi_ready
    );

  INST_LWC : entity work.LWC_SCA
    port map(
      clk       => clk,
      rst       => rst,
      --
      pdi_data  => lwc_pdi_data,
      pdi_valid => lwc_pdi_valid,
      pdi_ready => lwc_pdi_ready,
      --
      sdi_data  => lwc_sdi_data,
      sdi_valid => lwc_sdi_valid,
      sdi_ready => lwc_sdi_ready,
      --
      do_data   => lwc_do_data,
      do_last   => lwc_do_last,
      do_valid  => lwc_do_valid,
      do_ready  => lwc_do_ready,
      --
      rdi_data  => lwc_rdi_data,
      rdi_valid => lwc_rdi_valid,
      rdi_ready => lwc_rdi_ready
    );

end architecture;
