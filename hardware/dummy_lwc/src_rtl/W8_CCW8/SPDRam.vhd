--------------------------------------------------------------------------------
--! @file       SPDRam.vhd
--! @brief      Single port 2^AddrWidth x DataWidth (depth x width) 
--!             distributed ram  
--! @author     Panasayya Yalla
--! @copyright  Copyright (c) 2016 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             unrestricted)                                                  
--------------------------------------------------------------------------------
--! Description         : Single-port Distributed RAM 
--! DataWidth(integer)  : Generic parameter for setting width of the memory
--! AddrWidth(integer)  : Address bus width determining the depth of memory
--!                       2^AddrWidth 
--! wen                 : write enable      
--! addr                : address for read/write
--! din                 : input data of width "DataWidth"
--! dout                : output data of width "DataWidth" 
--! Mode                : read_first_write_next
--!                       Place "Read data" line after "Write data" line for 
--!                       write_first_read_next 
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

--USE ieee.std_logic_unsigned.all;

entity SPDRam is 
    generic (   DataWidth : integer ; 
                AddrWidth : integer
            ); 
    port    ( 
                clk       : in  std_logic;
                wen       : in  std_logic;
                addr      : in  std_logic_vector(AddrWidth  -1 downto 0);
                din       : in  std_logic_vector(DataWidth  -1 downto 0);
                dout      : out std_logic_vector(DataWidth  -1 downto 0)
            );
    --Xilinx attributes for using only distributed rams
    attribute ram_style:string;
    attribute ram_style of SpDRam: entity is "distributed";

end SPDRam;

architecture behavioral of SpDRam is
type ram_type is array (2**AddrWidth-1 downto 0) of std_logic_vector (DataWidth-1 downto 0); 
signal RAM : ram_type;  
begin
    process (clk)
    begin
        if rising_edge(clk) then
            
            if (wen = '1') then
                RAM(to_integer(to_01(unsigned(addr)))) <= din; --Write data
            end if;            
        end if;
    end process;
    dout <= RAM(to_integer(to_01(unsigned(addr))));    --Read data
    --place the "Read data" line here for asynchronous read.     
end behavioral;
