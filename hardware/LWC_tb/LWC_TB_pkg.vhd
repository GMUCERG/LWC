-------------------------------------------------------------------------------
--! @file       LWC_TB_pkg.vhd
--! @brief      Testbench Utility Package
--! @project    LWC Hardware API Testbench
--!                  
--! @copyright  
--! @version    1.1.1
--! @license    
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

use std.textio.all;

package LWC_TB_pkg is
    function LWC_TO_HSTRING (VALUE : STD_LOGIC_VECTOR) return STRING;
    procedure LWC_HREAD (L : inout LINE; VALUE : out STD_LOGIC_VECTOR; GOOD : out BOOLEAN);
    
    function log2_ceil (N : NATURAL) RETURN NATURAL;

    type RandGen is protected
        procedure seed(s : in POSITIVE);
        procedure seed(s1, s2 : in POSITIVE);
        impure function randint(min, max : INTEGER) return INTEGER;
    end protected;

    type LinkedList is protected
        procedure push(constant d   : in NATURAL);
        impure function pop return NATURAL;
        impure function isEmpty return BOOLEAN;
    end protected;

end package LWC_TB_pkg;

package body LWC_TB_pkg is

    function or_reduce (l : STD_LOGIC_VECTOR) return STD_LOGIC is
    variable result : STD_LOGIC := '0';
    begin
    for i in l'reverse_range loop
      result := (l(i) or result);
    end loop;
    return result;
    end function or_reduce;

    constant NBSP : CHARACTER      := CHARACTER'val(160); -- space character

    procedure skip_whitespace (
    L : inout LINE) is
    variable c : CHARACTER;
    variable left : positive;
    begin
    while L /= null and L.all'length /= 0 loop
      left := L.all'left;
      c := L.all(left);
      if (c = ' ' or c = NBSP or c = HT) then
        read (L, c);
      else
        exit;
      end if;
    end loop;
    end procedure skip_whitespace;

    procedure Char2QuadBits (C           :     CHARACTER;
    RESULT      : out STD_LOGIC_VECTOR(3 downto 0);
    GOOD        : out BOOLEAN;
    ISSUE_ERROR : in  BOOLEAN) is
    begin
    case C is
      when '0'       => RESULT := x"0"; GOOD := true;
      when '1'       => RESULT := x"1"; GOOD := true;
      when '2'       => RESULT := x"2"; GOOD := true;
      when '3'       => RESULT := x"3"; GOOD := true;
      when '4'       => RESULT := x"4"; GOOD := true;
      when '5'       => RESULT := x"5"; GOOD := true;
      when '6'       => RESULT := x"6"; GOOD := true;
      when '7'       => RESULT := x"7"; GOOD := true;
      when '8'       => RESULT := x"8"; GOOD := true;
      when '9'       => RESULT := x"9"; GOOD := true;
      when 'A' | 'a' => RESULT := x"A"; GOOD := true;
      when 'B' | 'b' => RESULT := x"B"; GOOD := true;
      when 'C' | 'c' => RESULT := x"C"; GOOD := true;
      when 'D' | 'd' => RESULT := x"D"; GOOD := true;
      when 'E' | 'e' => RESULT := x"E"; GOOD := true;
      when 'F' | 'f' => RESULT := x"F"; GOOD := true;
      when 'Z'       => RESULT := "ZZZZ"; GOOD := true;
      when 'X'       => RESULT := "XXXX"; GOOD := true;
      when others =>
        assert not ISSUE_ERROR
          report "LWC_HREAD Read a '" & C & "', expected a Hex character (0-F)." severity error;
        GOOD := false;
    end case;
    end procedure Char2QuadBits;

    procedure LWC_HREAD (L    : inout LINE; VALUE : out STD_LOGIC_VECTOR;
    GOOD : out   BOOLEAN) is
    variable ok  : BOOLEAN;
    variable c   : CHARACTER;
    constant ne  : INTEGER := (VALUE'length+3)/4;
    constant pad : INTEGER := ne*4 - VALUE'length;
    variable sv  : STD_LOGIC_VECTOR(0 to ne*4 - 1);
    variable i   : INTEGER;
    variable lastu  : BOOLEAN := false;       -- last character was an "_"
    begin
    VALUE := (VALUE'range => 'U'); -- initialize to a "U"
    skip_whitespace (L);
    if VALUE'length > 0 then
      read (L, c, ok);
      i := 0;
      while i < ne loop

        if not ok then
          GOOD := false;
          return;
        elsif c = '_' then
          if i = 0 then
            GOOD := false;                -- Begins with an "_"
            return;
          elsif lastu then
            GOOD := false;                -- "__" detected
            return;
          else
            lastu := true;
          end if;
        else
          Char2QuadBits(c, sv(4*i to 4*i+3), ok, false);
          if not ok then
            GOOD := false;
            return;
          end if;
          i := i + 1;
          lastu := false;
        end if;
        if i < ne then
          read(L, c, ok);
        end if;
      end loop;
      if or_reduce (sv (0 to pad-1)) = '1' then  -- %%% replace with "or"
        GOOD := false;                           -- vector was truncated.
      else
        GOOD  := true;
        VALUE := sv (pad to sv'high);
      end if;
    else
      GOOD := true;                     -- Null input string, skips whitespace
    end if;
    end procedure LWC_HREAD;

    function LWC_to_hstring (value : STD_LOGIC_VECTOR) return STRING is
    constant ne     : INTEGER := (value'length+3)/4;
    variable pad    : STD_LOGIC_VECTOR(0 to (ne*4 - value'length) - 1);
    variable ivalue : STD_LOGIC_VECTOR(0 to ne*4 - 1);
    variable result : STRING(1 to ne);
    variable quad   : STD_LOGIC_VECTOR(0 to 3);
    begin
    if value'length < 1 then
      return "";
    else
      if value (value'left) = 'Z' then
        pad := (others => 'Z');
      else
        pad := (others => '0');
      end if;
      ivalue := pad & value;
      for i in 0 to ne-1 loop
        quad := To_X01Z(ivalue(4*i to 4*i+3));
        case quad is
          when x"0"   => result(i+1) := '0';
          when x"1"   => result(i+1) := '1';
          when x"2"   => result(i+1) := '2';
          when x"3"   => result(i+1) := '3';
          when x"4"   => result(i+1) := '4';
          when x"5"   => result(i+1) := '5';
          when x"6"   => result(i+1) := '6';
          when x"7"   => result(i+1) := '7';
          when x"8"   => result(i+1) := '8';
          when x"9"   => result(i+1) := '9';
          when x"A"   => result(i+1) := 'A';
          when x"B"   => result(i+1) := 'B';
          when x"C"   => result(i+1) := 'C';
          when x"D"   => result(i+1) := 'D';
          when x"E"   => result(i+1) := 'E';
          when x"F"   => result(i+1) := 'F';
          when "ZZZZ" => result(i+1) := 'Z';
          when others => result(i+1) := 'X';
        end case;
      end loop;
      return result;
    end if;
    end function LWC_to_hstring;

    
    type RandGen is protected body

        variable seed1 : positive;
        variable seed2 : positive;
  
        procedure seed(s : in positive) is
        begin
            seed1 := s;
            if s > 1 then
                seed2 := s - 1;
            else
                seed2 := s + 42;
            end if;
        end procedure;

        procedure seed(s1, s2 : in positive) is
        begin
            seed1 := s1;
            seed2 := s2;
        end procedure;

        impure function random return real is
            variable result : real;
        begin
            uniform(seed1, seed2, result);
            return result;
        end function;

        impure function randint(min, max : integer) return integer is
        begin
            return integer(trunc(real(max - min + 1) * random)) + min;
        end function;
    end protected body;

    function log2_ceil (n : natural) return natural is
    begin
        if (n = 0) then
          return 0;
        elsif n <= 2 then
            return 1;
        else
            if (n mod 2 = 0) then
                return 1 + log2_ceil(n/2);
            else
                return 1 + log2_ceil((n + 1)/2);
            end if;
        end if;
    end function log2_ceil;

    type LinkedList is protected body
        type Item;
        type ItemPtr is access Item;
        type Item is record
            d   : NATURAL;
            nxt : ItemPtr;
        end record;
 
        variable root : ItemPtr;
 
        procedure push(constant d   : in NATURAL) is
            variable newNode : ItemPtr;
            variable node    : ItemPtr;
        begin
            newNode   := new Item;
            newNode.d := d;
            if root = null then
                root := newNode;
            else
                node := root;
                while node.nxt /= null loop
                   node := node.nxt;
                end loop;
                node.nxt := newNode;
            end if;
        end;
 
        impure function pop return NATURAL is
            variable node : ItemPtr;
            variable ret : NATURAL;
        begin
            node := root;
            root := root.nxt;
            ret  := node.d;
            deallocate(node);
            return ret;
        end;
 
        impure function isEmpty return BOOLEAN is
        begin
            return root = null;
        end;
 
    end protected body;

end package body LWC_TB_pkg;