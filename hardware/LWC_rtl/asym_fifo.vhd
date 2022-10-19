--===============================================================================================--
--! @file              asym_fifo.vhd
--! @brief             Asymmetric FIFO
--! @author            Kamyar Mohajerani
--! @copyright         Copyright (c) 2022
--! @license           Solderpad Hardware License v2.1
--!                    [SHL-2.1](https://solderpad.org/licenses/SHL-2.1/))
--!
--! @vhdl              VHDL 1993, 2002, 2008, 2017
--!
--! @details           - Can be used as regular FIFO, Asymmetric FIFO (enqueue/write width different
--!                     from dequeue/read width), SIPO, or PISO.
--!                    - Using dual-port syncrhonous-read memory
--!                      (read data available on the next clock edge)
--!                    - Following AMD/Xilinx/Vivado HDL coding styles for SDP BRAM inference
--!
--! @note              read/write widths and capacity MUST be powers of 2
--===============================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asym_fifo is
  generic(
    G_WR_W       : positive := 4;       -- write (enqueue) width in bits, must be powers of 2
    G_RD_W       : positive := 16;      -- read (dequeue) width in bits, must be powers of 2
    G_CAPACITY   : positive := 4096;    -- memory capacity in bits, must be powers of 2
    G_BIG_ENDIAN : boolean  := TRUE;
    G_OUT_REG    : boolean  := FALSE;
    G_RAM_STYLE  : string   := "block"  -- "block" (BRAM), "ultra" (UlstraScale+), "distributed" (LUT), "registers" (FFs), "mixed" (combination of RAM types designed to minimize the amount of space)
  );

  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    -- Enqueue
    enq_data  : in  std_logic_vector(G_WR_W - 1 downto 0);
    enq_valid : in  std_logic;
    enq_ready : out std_logic;
    -- Dequeue
    deq_data  : out std_logic_vector(G_RD_W - 1 downto 0);
    deq_valid : out std_logic;
    deq_ready : in  std_logic
  );

end asym_fifo;

architecture RTL of asym_fifo is
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

  -- whether `n` is a power of 2
  function is_pow_2(n : natural) return boolean is
  begin
    return 2 ** log2ceil(n) = n;
  end function;

  function to_int01(S : unsigned) return natural is
  begin
    return to_integer(to_01(S));
  end function;

  function slv_chunk(slv : std_logic_vector; chunk_width, i : natural) return std_logic_vector is
    constant NUM_CHUNKS : natural := slv'length / chunk_width;
  begin
    if G_BIG_ENDIAN then
      return slv((NUM_CHUNKS - i) * chunk_width - 1 downto (NUM_CHUNKS - i - 1) * chunk_width);
    else
      return slv((i + 1) * chunk_width - 1 downto i * chunk_width);
    end if;
  end function;

  function MIN_W return natural is
  begin
    if G_WR_W <= G_RD_W then
      return G_WR_W;
    end if;
    return G_RD_W;
  end function;

  constant WR_RD_LOG2 : natural := log2ceil(G_WR_W / G_RD_W);
  constant RD_WR_LOG2 : natural := log2ceil(G_RD_W / G_WR_W);
  constant MEM_DEPTH  : natural := G_CAPACITY / MIN_W;

  type T_RAM is array (0 to MEM_DEPTH - 1) of std_logic_vector(MIN_W - 1 downto 0);

  --========================================= Memory ===========================================--
  signal ram : T_RAM;

  -- Xilinx/Vivado:
  attribute ram_style : string;
  attribute ram_style of ram : signal is G_RAM_STYLE;

  --======================================== Registers =========================================--
  signal is_empty          : boolean;
  signal is_full           : boolean;
  signal dequeued_is_valid : std_logic;
  signal rd_ptr            : unsigned(log2ceil(G_CAPACITY / G_RD_W) - 1 downto 0);
  signal wr_ptr            : unsigned(log2ceil(G_CAPACITY / G_WR_W) - 1 downto 0);

  --========================================== Wires ============================================--
  signal next_rd_ptr                : unsigned(rd_ptr'range);
  signal next_wr_ptr                : unsigned(wr_ptr'range);
  signal write_en, read_en, overlap : boolean;
  signal almost_empty, almost_full  : boolean;
  signal can_deq                    : boolean;
  signal read_data                  : std_logic_vector(G_RD_W - 1 downto 0);
  signal out_ready, enq_ready_o     : std_logic; -- := FALSE;

begin
  assert FALSE
  report LF & "[ASYM_FIFO] " & LF & " G_RD_W: " & integer'image(G_RD_W) & " G_WR_W: " & integer'image(G_WR_W) & "  Read(dequeue) DEPTH:" & integer'image(G_CAPACITY / G_RD_W)
  severity NOTE;

  assert is_pow_2(G_RD_W) and is_pow_2(G_WR_W) and is_pow_2(G_CAPACITY)
  report "G_RD_W, G_WR_W, and G_CAPACITY must be powers of 2"
  severity FAILURE;

  assert G_CAPACITY >= G_WR_W and G_CAPACITY >= G_RD_W
  report "G_CAPACITY should not be smaller than G_WR_W or G_RD_W"
  severity FAILURE;

  next_rd_ptr <= rd_ptr + 1;            -- mod (2 ** DEPTH_BITS)
  next_wr_ptr <= wr_ptr + 1;            -- mod (2 ** DEPTH_BITS)

  -- GEN_OVERLAP_ZEROLEN_PTR : if rd_ptr'length = 0 or wr_ptr'length = 0 generate
  -- overlap <= TRUE;
  -- end generate;
  GEN_OVERLAP : if rd_ptr'length /= 0 and wr_ptr'length /= 0 generate
    overlap <= rd_ptr(rd_ptr'length - 1 downto WR_RD_LOG2) = wr_ptr(wr_ptr'length - 1 downto RD_WR_LOG2);
  end generate;

  assert (wr_ptr'length - RD_WR_LOG2) = (rd_ptr'length - WR_RD_LOG2) severity FAILURE;

  write_en  <= enq_valid = '1' and enq_ready_o = '1';
  read_en   <= can_deq and (dequeued_is_valid = '0' or out_ready = '1');
  enq_ready <= enq_ready_o;

  process(clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        is_empty          <= TRUE;
        is_full           <= FALSE;
        dequeued_is_valid <= '0';
        rd_ptr            <= (others => '0');
        wr_ptr            <= (others => '0');
      else
        if write_en then
          if not read_en and almost_full then
            is_full <= TRUE;
          end if;
          is_empty <= FALSE;
          wr_ptr   <= next_wr_ptr;
        end if;
        if read_en then
          dequeued_is_valid <= '1';
          if not write_en and almost_empty then
            is_empty <= TRUE;
          end if;
          is_full           <= FALSE;
          rd_ptr            <= next_rd_ptr;
        elsif out_ready = '1' then
          dequeued_is_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  GEN_READ_WIDER_OR_EQ : if G_RD_W >= G_WR_W generate
    signal read_tmp          : std_logic_vector(G_RD_W - 1 downto 0);
    constant NUM_READ_CHUNKS : positive := G_RD_W / G_WR_W;
  begin

    GEN_READ_WIDER : if G_RD_W > G_WR_W generate
      almost_empty <= next_rd_ptr & (RD_WR_LOG2 - 1 downto 0 => '0') = wr_ptr;
      almost_full  <= next_wr_ptr = rd_ptr & (RD_WR_LOG2 - 1 downto 0 => '0');
    end generate;
    GEN_READ_EQ : if G_RD_W = G_WR_W generate
      almost_empty <= next_rd_ptr = wr_ptr;
      almost_full  <= next_wr_ptr = rd_ptr;
    end generate;

    can_deq     <= is_full or not overlap;
    enq_ready_o <= '0' when is_full else '1';

    GEN_READ_BIG_ENDIAN : if G_BIG_ENDIAN generate
      GEN_READ_SWAP : for i in 0 to NUM_READ_CHUNKS - 1 generate
        read_data((NUM_READ_CHUNKS - i) * G_WR_W - 1 downto (NUM_READ_CHUNKS - i - 1) * G_WR_W) <= read_tmp((i + 1) * G_WR_W - 1 downto i * G_WR_W);
      end generate;
    end generate;

    GEN_READ_LITTLE_ENDIAN : if not G_BIG_ENDIAN generate
      read_data <= read_tmp;
    end generate;

    process(clk) is
    begin
      if rising_edge(clk) then
        -- Write
        if write_en then
          ram(to_int01(wr_ptr)) <= enq_data;
        end if;
        -- Read
        if read_en then
          -- read_words(i) <= ram(to_int01(rd_ptr & to_unsigned(i, RD_WR_LOG2)));
          for i in 0 to NUM_READ_CHUNKS - 1 loop
            read_tmp((i + 1) * G_WR_W - 1 downto i * G_WR_W) <= ram(to_int01(rd_ptr & to_unsigned(i, RD_WR_LOG2)));
          end loop;
        end if;
      end if;
    end process;
  end generate;

  GEN_WRITE_WIDER : if G_RD_W < G_WR_W generate -- enq is wider than deq
  begin

    almost_empty <= next_rd_ptr = wr_ptr & (WR_RD_LOG2 - 1 downto 0 => '0');
    almost_full  <= next_wr_ptr & (WR_RD_LOG2 - 1 downto 0 => '0') = rd_ptr;

    can_deq     <= not is_empty;
    enq_ready_o <= '1' when (is_empty or not overlap) else '0';

    process(clk) is
    begin
      if rising_edge(clk) then
        -- Write
        if write_en then
          for i in 0 to (G_WR_W / G_RD_W) - 1 loop
            ram(to_int01(wr_ptr & to_unsigned(i, WR_RD_LOG2))) <= slv_chunk(enq_data, G_RD_W, i);
          end loop;
        end if;
        -- Read
        if read_en then
          read_data <= ram(to_int01(rd_ptr));
        end if;
      end if;
    end process;
  end generate;

  GEN_OUTREG : if G_OUT_REG generate
    --======================================== Registers ==========================================--
    signal out_reg       : std_logic_vector(G_RD_W - 1 downto 0);
    signal out_reg_valid : std_logic;   -- := FALSE;

  begin
    deq_data  <= out_reg;
    deq_valid <= out_reg_valid;
    out_ready <= not out_reg_valid or deq_ready;

    process(clk) is
    begin
      if rising_edge(clk) then
        if rst = '1' then
          out_reg_valid <= '0';
        elsif deq_ready = '1' or out_reg_valid = '0' then
          out_reg       <= read_data;
          out_reg_valid <= dequeued_is_valid;
        end if;
      end if;
    end process;
  end generate;

  GEN_NO_OUTREG : if not G_OUT_REG generate
    deq_data  <= read_data;
    deq_valid <= dequeued_is_valid;
    out_ready <= deq_ready;
  end generate;

end architecture;
