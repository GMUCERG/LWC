-------------------------------------------------------------------------------
--! @file       LWC_TB.vhd
--! @brief      Testbench based on the GMU CAESAR project.
--! @project    CAESAR Candidate Evaluation
--! @author     Ekawat (ice) Homsirikamol
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2015, 2020, 2021 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @version    1.1.1
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.LWC_TB_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity LWC_TB IS
    generic (
        G_MAX_FAILURES      : integer := 100;                      --! Maximum number of failures before stopping the simulation
        G_TEST_MODE         : integer := 0;                        --! 0: normal, 1: stall both sdi/pdi_valid and do_ready, 2: stall sdi/pdi_valid, 3: stall do_ready, 4: Timing (cycle) measurement 
        G_TEST_IPSTALL      : integer := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall pdi_valid
        G_TEST_ISSTALL      : integer := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall sdi_valid
        G_TEST_OSTALL       : integer := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall do_ready
        G_RANDOMIZE_STALLS  : boolean := False;                    --! Randomize number of stalls from range [0, max], where max is any of the above G_TEST_xSTALL values
        G_PERIOD_PS         : integer := 10_000;                   --! Simulation clock period in picoseconds
        G_FNAME_PDI         : string  := "../KAT/v1/pdi.txt";      --! Path to the input file containing cryptotvgen PDI testvector data
        G_FNAME_SDI         : string  := "../KAT/v1/sdi.txt";      --! Path to the input file containing cryptotvgen SDI testvector data
        G_FNAME_DO          : string  := "../KAT/v1/do.txt";       --! Path to the input file containing cryptotvgen DO testvector data
        G_FNAME_LOG         : string  := "log.txt";                --! Path to the generated log file
        G_FNAME_TIMING      : string  := "timing.txt";             --! Path to the generated timing measurements (when G_TEST_MODE=4)
        G_FNAME_FAILED_TVS  : string  := "failed_testvectors.txt"; --! Path to the generated log of failed testvector words
        G_FNAME_RESULT      : string  := "result.txt";             --! Path to the generated result file containing 0 or 1  -- REDUNDANT / NOT USED
        G_PRERESET_WAIT     : time    := 100 ns                    --! Xilinx GSR takes 100ns, required for post-synth simulation
    );
end LWC_TB;

architecture TB of LWC_TB is
    ------------- timing constants ------------------
    constant clk_period         : time := G_PERIOD_PS * ps;
    constant input_delay        : time := 0 ns; -- clk_period / 2; --

    --! =================== --
    --! SIGNALS DECLARATION --
    --! =================== --

    --! simulation signals
    signal stop_clock           : boolean   := False;
    
    -- reset completed
    signal reset_done           : boolean   := False;

    --! globals
    signal clk                  : std_logic := '0';
    signal rst                  : std_logic := '0';

    --! pdi
    signal pdi_data             : std_logic_vector(W-1 downto 0) := (others => '0');
    signal pdi_data_delayed     : std_logic_vector(W-1 downto 0) := (others => '0');
    signal pdi_valid            : std_logic := '0';
    signal pdi_valid_delayed    : std_logic := '0';
    signal pdi_ready            : std_logic;

    --! sdi
    signal sdi_data             : std_logic_vector(SW-1 downto 0) := (others => '0');
    signal sdi_data_delayed     : std_logic_vector(SW-1 downto 0) := (others => '0');
    signal sdi_valid            : std_logic := '0';
    signal sdi_valid_delayed    : std_logic := '0';
    signal sdi_ready            : std_logic;

    --! do
    signal do_data              : std_logic_vector(W-1 downto 0);
    signal do_valid             : std_logic;
    signal do_last              : std_logic;
    signal do_ready             : std_logic := '0';
    signal do_ready_delayed     : std_logic := '0';

    signal tv_count             : integer := 0;
    signal cycle_counter        : NATURAL := 0;



    ---------------------- shared variables ----------------------
    shared variable  timingBoard : LinkedList;
    shared variable  rng : RandGen;
    
    ---------------------- constants ----------------------
    constant cons_tb            : string(1 to 6) := "# TB :";
    constant cons_ins           : string(1 to 6) := "INS = ";
    constant cons_hdr           : string(1 to 6) := "HDR = ";
    constant cons_dat           : string(1 to 6) := "DAT = ";
    constant cons_stt           : string(1 to 6) := "STT = ";
    constant cons_eof           : string(1 to 6) := "###EOF";
    constant SUCCESS_WORD       : std_logic_vector(W - 1 downto 0) := INST_SUCCESS & (W - 5 downto 0 => '0');
    constant FAILURE_WORD       : std_logic_vector(W - 1 downto 0) := INST_FAILURE & (W - 5 downto 0 => '0');


    ------------------- input / output files ----------------------
    file pdi_file       : text open read_mode  is G_FNAME_PDI;
    file sdi_file       : text open read_mode  is G_FNAME_SDI;
    file do_file        : text open read_mode  is G_FNAME_DO;
    file log_file       : text open write_mode is G_FNAME_LOG;
    file timing_file    : text open write_mode is G_FNAME_TIMING;
    file result_file    : text open write_mode is G_FNAME_RESULT;
    file failures_file  : text open write_mode is G_FNAME_FAILED_TVS;
    ----------------- end of input / output files -----------------
    

    function word_pass(actual: std_logic_vector(W-1 downto 0); expected: std_logic_vector(W-1 downto 0)) return boolean is
    begin
        for i in W-1 downto 0 loop
            if  actual(i) /= expected(i) and expected(i) /= 'X' then
                return False;
            end if;
        end loop;
        return True;
    end function word_pass;

    impure function get_stalls(max_stalls: INTEGER) return INTEGER is
    begin
        if G_RANDOMIZE_STALLS then
            return MINIMUM(0, rng.randint(-max_stalls, max_stalls));
        end if;
        return max_stalls;
    end function get_stalls;
    
    ----------------- component decrations ------------------
    -- LWC is instantiated as component to make mixed-language simulation possible
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
    
begin

    genClk: process
    begin
        if not stop_clock then
            clk <= '1';
            wait for clk_period / 2;
            clk <= '0';
            wait for clk_period / 2;
        else
            wait;
        end if;
    end process genClk;

    asyncRstnCycleCount : if ASYNC_RSTN generate
        process(clk, rst)
        begin
            if rst = '0' then
                cycle_counter <= 0;
            elsif rising_edge(clk) then
                cycle_counter <= cycle_counter + 1;
            end if;
        end process;
    end generate;

    syncRstCycleCount : if not ASYNC_RSTN generate
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    cycle_counter <= 0;
                else
                    cycle_counter <= cycle_counter + 1;
                end if;
            end if;
        end process;
    end generate;

    -- LWC is instantiated as a component for mixed languages simulation
    uut: LWC
        port map(
            clk          => clk,
            rst          => rst,
            pdi_data     => pdi_data_delayed,
            pdi_valid    => pdi_valid_delayed,
            pdi_ready    => pdi_ready,
            sdi_data     => sdi_data_delayed,
            sdi_valid    => sdi_valid_delayed,
            sdi_ready    => sdi_ready,
            do_data      => do_data,
            do_ready     => do_ready_delayed,
            do_valid     => do_valid,
            do_last      => do_last
        );
    
    pdi_data_delayed  <= transport pdi_data  after input_delay;
    pdi_valid_delayed <= transport pdi_valid after input_delay;
    sdi_data_delayed  <= transport sdi_data  after input_delay;
    sdi_valid_delayed <= transport sdi_valid after input_delay;
    do_ready_delayed  <= transport do_ready  after input_delay;

    genRst: process
    begin
        report LF & " -- Testvectors:  " & G_FNAME_PDI & " " & G_FNAME_SDI & " " & G_FNAME_DO & LF &
        " -- Clock Period: " & integer'image(G_PERIOD_PS) & " ps" & LF &
        " -- Test Mode:    " & integer'image(G_TEST_MODE) & LF &
        " -- Max Failures: " & integer'image(G_MAX_FAILURES) & LF & CR severity note;

        rng.seed(123);
        wait for G_PRERESET_WAIT;
        if ASYNC_RSTN then
            rst <= '0';
            wait for 2 * clk_period;
            rst <= '1';
        else
            rst <= '1';
            wait for 2 * clk_period;
            rst <= '0';
        end if;
        wait until rising_edge(clk);
        wait for clk_period; -- optional
        reset_done <= True;
        wait;
    end process;
    
    --! =======================================================================
    --! ==================== DATA POPULATION FOR PUBLIC DATA ==================
    tb_read_pdi : process
        variable line_data    : line;
        variable word_block   : std_logic_vector(W-1 downto 0) := (others=>'0');
        variable read_result  : boolean;
        variable line_head    : string(1 to 6);
        variable stall_cycles : integer;
        variable first_inst   : boolean; -- first instruction: either actkey or hash
    begin

        wait until reset_done;
        wait until rising_edge(clk);
        pdi_valid <= '1';
        
        while not endfile(pdi_file) loop
            readline(pdi_file, line_data);
            read(line_data, line_head, read_result); --! read line header
            if read_result and (line_head = cons_ins) then
                tv_count <= tv_count + 1;
            end if;
            if read_result and (line_head = cons_ins or line_head = cons_hdr or line_head = cons_dat) then
                loop
                    LWC_HREAD(line_data, word_block, read_result);
                    if not read_result then
                        exit;
                    end if;

                    if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
                        stall_cycles := get_stalls(G_TEST_IPSTALL);
                        if stall_cycles > 0 then
                            pdi_valid <= '0';
                            wait for stall_cycles * clk_period;
                            wait until rising_edge(clk);
                        end if;
                        pdi_valid <= '1';
                    end if;

                    first_inst := line_head = cons_ins and (word_block(W-1 downto W-8) = X"70" or word_block(W-1 downto W-8) = X"80");

                    if G_TEST_MODE = 4 and first_inst   and not timingBoard.isEmpty then
                        pdi_valid <= '0';
                        while not timingBoard.isEmpty loop
                            wait until rising_edge(clk);
                        end loop;
                        pdi_valid <= '1';
                    end if;

                    pdi_data <= word_block;
                    wait until rising_edge(clk) and pdi_ready = '1';

                    if G_TEST_MODE = 4 and first_inst   then
                        assert timingBoard.isEmpty report "timingBoard should be empty here!" severity failure;
                        timingBoard.push(cycle_counter);
                    end if;
               end loop;
            end if;
        end loop;
        pdi_valid <= '0';
        wait; -- forever
    end process;

    --! =======================================================================
    --! ==================== DATA POPULATION FOR SECRET DATA ==================
    tb_read_sdi : process
        variable line_data    : line;
        variable word_block   : std_logic_vector(SW-1 downto 0) := (others=>'0');
        variable read_result  : boolean;
        variable line_head    : string(1 to 6);
        variable stall_cycles : integer;
    begin
        wait until reset_done;
        wait until rising_edge(clk);
        sdi_valid <= '1';

        while not endfile(sdi_file) loop
            readline(sdi_file, line_data);
            read(line_data, line_head, read_result);
            if read_result and (line_head = cons_ins or line_head = cons_hdr or line_head = cons_dat) then
                loop
                    LWC_HREAD(line_data, word_block, read_result);
                    if not read_result then
                        exit;
                    end if;

                    if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
                        stall_cycles := get_stalls(G_TEST_ISSTALL);
                        if stall_cycles > 0 then
                            sdi_valid <= '0';
                            wait for stall_cycles * clk_period;
                            wait until rising_edge(clk);
                        end if;
                        sdi_valid <= '1';
                    end if;
                    sdi_data <= word_block;
                    wait until rising_edge(clk) and sdi_ready = '1';
               end loop;
            end if;
        end loop;
        sdi_valid <= '0';
        wait; -- forever
    end process;

    --! =======================================================================
    --! =================== DATA VERIFICATION =================================
    tb_verifydata : process
        variable line_no        : integer := 0;
        variable line_data      : line;
        variable logMsg         : line;
        variable failMsg        : line;
        variable tb_block       : std_logic_vector(20 - 1 downto 0);
        variable word_block     : std_logic_vector(W  - 1 downto 0) := (others=>'0');
        variable read_result    : boolean;
        variable temp_read      : string(1 to 6);
        variable word_count     : integer := 1;
        variable force_exit     : boolean := False;
        variable failed         : boolean := False;
        variable msgid          : integer;
        variable keyid          : integer;
        variable opcode         : std_logic_vector(3 downto 0);
        variable num_fails      : integer := 0;
        variable testcase       : integer := 0;
        variable stall_cycles   : integer;
        variable cycles         : integer;
        variable end_cycle      : natural;
        variable end_time       : time;
    begin
        wait until reset_done;
        wait until rising_edge(clk);
        while not endfile(do_file) and not force_exit loop
            readline(do_file, line_data);
            line_no := line_no + 1;
            read(line_data, temp_read, read_result);
            if read_result then
                if temp_read = cons_stt or temp_read = cons_hdr or temp_read = cons_dat then
                    loop
                        LWC_HREAD(line_data, word_block, read_result);
                        if not read_result then
                            exit;
                        end if;

                        if G_TEST_MODE = 1 or G_TEST_MODE = 3 then
                            stall_cycles := get_stalls(G_TEST_OSTALL);
                            if stall_cycles > 0 then
                                do_ready <= '0';
                                wait for stall_cycles * clk_period;
                                wait until rising_edge(clk);
                            end if;
                        end if;

                        do_ready <= '1';
                        wait until rising_edge(clk) and do_valid = '1';
                        
                        if G_TEST_MODE = 4 and temp_read = cons_stt then
                            if timingBoard.isEmpty then
                                do_ready <= '0';
                                while timingBoard.isEmpty loop
                                    wait until rising_edge(clk);
                                end loop;
                                do_ready <= '1';
                            end if;
                            assert not timingBoard.isEmpty report "timingBoard should not be empty here" severity failure;
                            cycles := cycle_counter - timingBoard.pop;
                            write(logMsg, integer'image(msgid) & ", "  & integer'image(cycles) );
                            writeline(timing_file, logMsg);
                            report "[Timing] MsgId: " & integer'image(msgid) & ", cycles: " & integer'image(cycles) severity note;
                        end if;

                        if not word_pass(do_data, word_block) then
                            failed := True;
                            write(logMsg, string'("[Log] Msg ID #")
                                & integer'image(msgid)
                                & string'(" fails at line #") & integer'image(line_no)
                                & string'(" word #") & integer'image(word_count));
                            writeline(log_file,logMsg);
                            write(logMsg, string'("[Log]     Expected: ")
                                & LWC_TO_HSTRING(word_block)
                                & string'(" Received: ") & LWC_TO_HSTRING(do_data));
                            writeline(log_file,logMsg);

                            report " --- MsgID #" & integer'image(testcase)
                                & " Data line #" & integer'image(line_no)
                                & " Word #" & integer'image(word_count)
                                & " at " & time'image(now) & " FAILS ---"
                                severity error;
                            report "Expected: " & LWC_TO_HSTRING(word_block)
                                & " Actual: " & LWC_TO_HSTRING(do_data) severity error;
                            write(result_file, string'("fail"));
                            num_fails := num_fails + 1;
                            write(failMsg,  string'("Failure #") & integer'image(num_fails)
                                & " MsgID: " & integer'image(testcase));-- & " Operation: ");

                            write(failMsg, string'(" Line: ") & integer'image(line_no)
                                & " Word: " & integer'image(word_count)
                                & " Expected: " & LWC_TO_HSTRING(word_block)
                                & " Received: " & LWC_TO_HSTRING(do_data));
                            writeline(failures_file, failMsg);
                            if num_fails >= G_MAX_FAILURES then
                                force_exit := True;
                            end if;
                        else
                            write(logMsg, string'("[Log]     Expected: ")
                                & LWC_TO_HSTRING(word_block)
                                & string'(" Received: ") & LWC_TO_HSTRING(do_data)
                                & string'(" Matched!"));
                            writeline(log_file,logMsg);
                        end if;
                        word_count := word_count + 1;
                end loop;
                elsif temp_read = cons_eof then
                    force_exit := True;
                elsif temp_read = cons_tb then
                    testcase := testcase + 1;
                    LWC_HREAD(line_data, tb_block, read_result); --! read data
                    read_result    := False;
                    opcode := tb_block(19 downto 16);
                    keyid  := to_integer(to_01(unsigned(tb_block(15 downto 8))));
                    msgid  := to_integer(to_01(unsigned(tb_block(7  downto 0))));
                    if ((opcode = INST_DEC or opcode = INST_ENC or opcode = INST_HASH)
                        or (opcode = INST_SUCCESS or opcode = INST_FAILURE))
                    then
                        write(logMsg, string'("[Log] == Verifying msg ID #")
                            & integer'image(testcase));
                        if (opcode = INST_ENC) then
                            write(logMsg, string'(" for ENC"));
                        elsif (opcode = INST_HASH) then
                            write(logMsg, string'(" for HASH"));
                        else
                            write(logMsg, string'(" for DEC"));
                        end if;
                        writeline(log_file,logMsg);
                    end if;
                    report "---------Started verifying MsgID = " & integer'image(testcase) severity note;
                end if;
            end if;
        end loop;

        end_cycle := cycle_counter;
        end_time := now;

        do_ready <= '0';
        wait until rising_edge(clk);
        
        if failed then
            report "FAIL (1): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & time'image(end_time) severity failure; -- error
            write(logMsg, "FAIL (1): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & time'image(end_time));
            write(result_file, "1");
        else
            report "PASS (0): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & time'image(end_time) severity note;
            write(logMsg, "PASS (0): SIMULATION FINISHED after " & integer'image(end_cycle) & " cycles at " & time'image(end_time));
            write(result_file, "0");
        end if;
        
        writeline(log_file, logMsg);
        write(logMsg, string'("[Log] Done"));
        writeline(log_file, logMsg);

        file_close(do_file);
        file_close(result_file);
        file_close(log_file);
        file_close(timing_file);

        stop_clock <= True;
        wait;

    end process;

end architecture;
