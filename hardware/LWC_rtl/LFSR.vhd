library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package utils_pkg is
  -- functions
  function log2ceil (n : natural) return natural;
  function compat_maximum (x, y : integer) return integer;
  function compat_minimum (x, y : integer) return integer;
end package;

package body utils_pkg is
  --! Returns the number of bits required to represet values less than n (0 to n - 1 inclusive)
  function log2ceil(n : natural) return natural is
    variable r : natural := 0;
  begin
    while n > 2 ** r loop
      r := r + 1;
    end loop;
    return r;
  end function;

  function compat_maximum (x, y : integer) return integer is
  begin
    if x > y then return x;
    else return y;
    end if;
  end function;

  function compat_minimum (x, y : integer) return integer is
  begin
    if x < y then return x;
    else return y;
    end if;
  end function;
end package body;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_pkg.all;

entity LFSR is
  generic(
    G_IN_BITS  : natural := 0;
    G_OUT_BITS : positive;
    G_LFSR_LEN : natural := 0;   -- LFSR length (lower bound), 0 = heuristically select LFSR_LEN based on G_OUT_BITS
    G_INIT_VAL : std_logic_vector := x"17339D82D78DA5BBD48284F414EA31AC9A936B271A5F85E573C3E243787FB4C4DEC7E333630F3C311754789B635625501346E88DC4BC8E92FE6C8F390CA6E553"
  );
  port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    -- reseed when rout_valid = '1'
    reseed     : in  std_logic := '0';
    -- fresh random input
    rin_data   : in  std_logic_vector(G_IN_BITS - 1 downto 0);
    rin_valid  : in  std_logic := '0';
    rin_ready  : out std_logic;
    -- output
    rout_data  : out std_logic_vector(G_OUT_BITS - 1 downto 0);
    rout_valid : out std_logic;
    rout_ready : in  std_logic
  );
end entity LFSR;

architecture RTL of LFSR is
  type T_TAPS is array (0 to 1) of integer;
  type T_TAPS_TABLE is array (1 to 26) of T_TAPS;
  -- Maximum-length Fibonacci LFSRs with 2 taps (XOR form) and length >= 63
  -- generated using https://github.com/hayguen/mlpolygen
  constant TAPS_TABLE : T_TAPS_TABLE := (
    (63, 1), (65, 18), (68, 9), (71, 6), (73, 25), (79, 9), (81, 4), (84, 13), (87, 13),
    (93, 2), (94, 21), (95, 11), (100, 37), (105, 16), (106, 15), (108, 31), (118, 33), (123, 2),
    (124, 37), (132, 29), (135, 11), (140, 29), (142, 21), (148, 27), (150, 53), (252, 67)
  );
  function GET_LFSR_LEN return positive is
    variable taps : T_TAPS;
  begin
    if G_LFSR_LEN > 0 then
      return G_LFSR_LEN;
    end if;
    -- auto select: best resource efficiency (both LUTs and FFs) when LFSR length matches output length
    for l in TAPS_TABLE'range loop
      taps := TAPS_TABLE(l);
      -- very crude heuristic to choose best LFSR_LEN
      -- We assume all LFSR entries in the table provide the required security level
      --  and try to make the best use of available resources
      -- G_OUT_BITS - 1 so one less, unless G_OUT_BITS + 1 is in the table
      if taps(0) >= G_OUT_BITS or (taps(0) = G_OUT_BITS - 1 and l < TAPS_TABLE'high and TAPS_TABLE(l + 1)(0) > G_OUT_BITS + 1) then
        return taps(0);
      end if;
    end loop;
    return TAPS_TABLE(TAPS_TABLE'high)(0); -- longest in the table
  end function;

  constant LFSR_LEN : positive := GET_LFSR_LEN;

  function GET_N_SEED return natural is
  begin
    if G_IN_BITS = 0 then
      return 0;
    else
      return LFSR_LEN / G_IN_BITS;
    end if;
  end function;

  constant N_SEED : natural  := GET_N_SEED;
  constant NUM_FF : positive := compat_maximum(LFSR_LEN, G_OUT_BITS);

  function get_taps(len : positive) return T_TAPS is
    variable taps : T_TAPS;
  begin
    for l in TAPS_TABLE'range loop
      taps := TAPS_TABLE(l);
      if taps(0) = len then
        return taps;
      end if;
    end loop;
    assert FALSE report "specified lfsr length was not found in TAPS_TABLE" severity FAILURE;
    return taps;                        -- just to avoid a Vivado warning
  end function;

  function lfsr_feedback(sr : std_logic_vector) return std_logic is
    constant LFSR_TAPS : T_TAPS    := get_taps(LFSR_LEN);
    variable fb        : std_logic := sr(LFSR_TAPS(0) - 1);
  begin
    for t in 1 to LFSR_TAPS'length - 1 loop
      if LFSR_TAPS(t) > 0 then
        fb := fb xor sr(LFSR_TAPS(t) - 1);
      end if;
    end loop;
    return not fb;
  end function;

  function lfsr_update(sr : std_logic_vector) return std_logic_vector is
    variable ret : std_logic_vector(sr'range) := sr;
  begin
    for i in 0 to G_OUT_BITS - 1 loop
      ret := ret(sr'length - 2 downto 0) & lfsr_feedback(ret(LFSR_LEN - 1 downto 0));
    end loop;
    return ret;
  end function;

  -- Wires
  signal next_sr : std_logic_vector(NUM_FF - 1 downto 0);

  function SR_INIT return std_logic_vector is
    variable ret : std_logic_vector(NUM_FF - 1 downto 0) := (others => '0');
  begin
    if G_IN_BITS = 0 then
      -- assert G_INIT_VAL'length >= G_OUT_BITS report "G_INIT_VAL length should be >= G_OUT_BITS" severity FAILURE;
      -- ret := G_INIT_VAL(NUM_FF - 1 downto 0);
      for i in 0 to compat_minimum(NUM_FF, G_INIT_VAL'length) - 1 loop
        ret(i) := G_INIT_VAL(i);
      end loop;
    -- else
      -- assert G_INIT_VAL'length = 0 report "G_INIT_VAL should be empty" severity FAILURE;
    end if;
    ret := lfsr_update(ret); -- run LFSR updates to fill all remaining zeros
    return ret;
  end function;

  -- Registers
  -- shift_registers: contains both previous output overflow (if any, MSB) and actual LFSR (LSB)
  signal shift_registers : std_logic_vector(NUM_FF - 1 downto 0) := SR_INIT; -- init for simulation
  signal seed_counter    : unsigned(log2ceil(N_SEED) - 1 downto 0);
  signal reseeding       : boolean;
begin

  next_sr   <= lfsr_update(shift_registers);
  rout_data <= shift_registers(G_OUT_BITS - 1 downto 0);

  GEN_CONST_SEED : if G_IN_BITS = 0 generate
    process(clk) is
    begin
      if rising_edge(clk) then
        if rout_ready = '1' then
          shift_registers <= next_sr;
        end if;
      end if;
    end process;
    rin_ready  <= '0';
    rout_valid <= '1';
  end generate;

  GEN_SEED_IN : if G_IN_BITS /= 0 generate
    process(clk) is
    begin
      if rising_edge(clk) then
        if rst = '1' then
          seed_counter <= (others => '0');
          -- shift_registers <= (others => '1'); -- FIXME
          reseeding <= TRUE;
        else
          if reseeding then
            if rin_valid = '1' then
              -- if seed_counter = N_SEED - 1 then --
              -- This saves a few LUTs, more seeding cycles and rand input, and absorbs (redundantly) more randomness:
              if seed_counter = (seed_counter'range => '1') then -- all ones
                seed_counter <= (others => '0');
                reseeding    <= FALSE;
              else
                seed_counter <= seed_counter + 1;
              end if;
              -- injecting fresh randomness into the lower bits
              shift_registers <= next_sr xor std_logic_vector(resize(unsigned(rin_data), shift_registers'length));
            end if;
          else
            if rout_ready = '1' then
              shift_registers <= next_sr;
            end if;
            if reseed = '1' then
              reseeding <= TRUE;
            end if;
          end if;
        end if;
      end if;
    end process;
    rin_ready  <= '1' when reseeding else '0';
    rout_valid <= '0' when reseeding else '1';
  end generate;

end architecture;
