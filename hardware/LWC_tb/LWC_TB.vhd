-------------------------------------------------------------------------------
--! @file       LWC_TB.vhd
--! @brief      Testbench based on the GMU CAESAR project.
--! @project    CAESAR Candidate Evaluation
--! @author     Ekawat (ice) Homsirikamol
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2015, 2020, 2021 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @version    1.1.2
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
        G_MAX_FAILURES      : INTEGER := 100;                      --! Maximum number of failures before stopping the simulation
        G_TEST_MODE         : INTEGER := 0;                        --! 0: normal, 1: stall both sdi/pdi_valid and do_ready, 2: stall sdi/pdi_valid, 3: stall do_ready, 4: Timing (cycle) measurement 
        G_TEST_IPSTALL      : INTEGER := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall pdi_valid
        G_TEST_ISSTALL      : INTEGER := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall sdi_valid
        G_TEST_OSTALL       : INTEGER := 3;                        --! Number of cycles (or max cycles, if G_RANDOMIZE_STALLS) to stall do_ready
        -- G_RANDOMIZE_STALLS  : BOOLEAN := False;                    --! Randomize number of stalls from range [0, max], where max is any of the above G_TEST_xSTALL values (removed to keep VHDL 93 compatibility)
        G_PERIOD_PS         : INTEGER := 10_000;                   --! Simulation clock period in picoseconds
        G_FNAME_PDI         : STRING  := "../KAT/v1/pdi.txt";      --! Path to the input file containing cryptotvgen PDI testvector data
        G_FNAME_SDI         : STRING  := "../KAT/v1/sdi.txt";      --! Path to the input file containing cryptotvgen SDI testvector data
        G_FNAME_DO          : STRING  := "../KAT/v1/do.txt";       --! Path to the input file containing cryptotvgen DO testvector data
        G_FNAME_LOG         : STRING  := "log.txt";                --! Path to the generated log file
        G_FNAME_TIMING      : STRING  := "timing.txt";             --! Path to the generated timing measurements (when G_TEST_MODE=4)
        G_FNAME_FAILED_TVS  : STRING  := "failed_testvectors.txt"; --! Path to the generated log of failed testvector words
        G_FNAME_RESULT      : STRING  := "result.txt";             --! Path to the generated result file containing 0 or 1  -- REDUNDANT / NOT USED
        G_PRERESET_WAIT     : TIME    := 100 ns                    --! Xilinx GSR takes 100ns, required for post-synth simulation
    );
end LWC_TB;

architecture TB of LWC_TB is
    -------------! timing constants ------------------
    constant clk_period         : TIME := G_PERIOD_PS * ps;
    constant input_delay        : TIME := 0 ns; -- clk_period / 2; --

    -- =================== --
    -- SIGNALS DECLARATION --
    -- =================== --

    --! simulation signals
    signal stop_clock           : BOOLEAN   := False;
    
    --! reset completed
    signal reset_done           : BOOLEAN   := False;

    --! globals
    signal clk                  : STD_LOGIC := '0';
    signal rst                  : STD_LOGIC := '0';

    --! PDI
    signal pdi_data             : STD_LOGIC_VECTOR(W-1 downto 0) := (others => '0');
    signal pdi_data_delayed     : STD_LOGIC_VECTOR(W-1 downto 0) := (others => '0');
    signal pdi_valid            : STD_LOGIC := '0';
    signal pdi_valid_delayed    : STD_LOGIC := '0';
    signal pdi_ready            : STD_LOGIC;

    --! SDI
    signal sdi_data             : STD_LOGIC_VECTOR(SW-1 downto 0) := (others => '0');
    signal sdi_data_delayed     : STD_LOGIC_VECTOR(SW-1 downto 0) := (others => '0');
    signal sdi_valid            : STD_LOGIC := '0';
    signal sdi_valid_delayed    : STD_LOGIC := '0';
    signal sdi_ready            : STD_LOGIC;

    --! DO
    signal do_data              : STD_LOGIC_VECTOR(W-1 downto 0);
    signal do_valid             : STD_LOGIC;
    signal do_last              : STD_LOGIC;
    signal do_ready             : STD_LOGIC := '0';
    signal do_ready_delayed     : STD_LOGIC := '0';

    signal tv_count             : INTEGER := 0;
    signal cycle_counter        : NATURAL := 0;
    
    signal start_cycle          : NATURAL;
    signal timing_started       : BOOLEAN := False;
    signal timing_started_probe       : std_logic;
    signal timing_stopped       : BOOLEAN := False;
    signal timing_stopped_probe       : std_logic;
    
    ---------------------- constants ----------------------
    constant cons_tb            : STRING(1 to 6) := "# TB :";
    constant cons_ins           : STRING(1 to 6) := "INS = ";
    constant cons_hdr           : STRING(1 to 6) := "HDR = ";
    constant cons_dat           : STRING(1 to 6) := "DAT = ";
    constant cons_stt           : STRING(1 to 6) := "STT = ";
    constant cons_eof           : STRING(1 to 6) := "###EOF";
    constant SUCCESS_WORD       : STD_LOGIC_VECTOR(W - 1 downto 0) := INST_SUCCESS & (W - 5 downto 0 => '0');
    constant FAILURE_WORD       : STD_LOGIC_VECTOR(W - 1 downto 0) := INST_FAILURE & (W - 5 downto 0 => '0');


    ------------------- input / output files ----------------------
    file pdi_file       : TEXT open read_mode  is G_FNAME_PDI;
    file sdi_file       : TEXT open read_mode  is G_FNAME_SDI;
    file do_file        : TEXT open read_mode  is G_FNAME_DO;
    file log_file       : TEXT open write_mode is G_FNAME_LOG;
    file timing_file    : TEXT open write_mode is G_FNAME_TIMING;
    file result_file    : TEXT open write_mode is G_FNAME_RESULT;
    file failures_file  : TEXT open write_mode is G_FNAME_FAILED_TVS;
    ----------------- end of input / output files -----------------
    

    function word_pass(actual: STD_LOGIC_VECTOR(W-1 downto 0); expected: STD_LOGIC_VECTOR(W-1 downto 0)) return BOOLEAN is
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
        return max_stalls;
    end function get_stalls;
    
    ----------------- component decrations ------------------
    -- LWC is instantiated as component to make mixed-language simulation possible
    component LWC
        port(
            clk       : in  STD_LOGIC;
            rst       : in  STD_LOGIC;
            pdi_data  : in  STD_LOGIC_VECTOR(W - 1 downto 0);
            pdi_valid : in  STD_LOGIC;
            pdi_ready : out STD_LOGIC;
            sdi_data  : in  STD_LOGIC_VECTOR(SW - 1 downto 0);
            sdi_valid : in  STD_LOGIC;
            sdi_ready : out STD_LOGIC;
            do_data   : out STD_LOGIC_VECTOR(W - 1 downto 0);
            do_ready  : in  STD_LOGIC;
            do_valid  : out STD_LOGIC;
            do_last   : out STD_LOGIC
        );
    end component LWC;
    
begin

    clockProc: process
    begin
        if not stop_clock then
            clk <= '1';
            wait for clk_period / 2;
            clk <= '0';
            wait for clk_period / 2;
        else
            wait;
        end if;
    end process;

    resetProc: process
    begin
        report LF & " -- Testvectors:  " & G_FNAME_PDI & " " & G_FNAME_SDI & " " & G_FNAME_DO & LF &
        " -- Clock Period: " & INTEGER'image(G_PERIOD_PS) & " ps" & LF &
        " -- Test Mode:    " & INTEGER'image(G_TEST_MODE) & LF &
        " -- Max Failures: " & INTEGER'image(G_MAX_FAILURES) & LF & CR severity note;

        wait for G_PRERESET_WAIT;
        if ASYNC_RSTN then
            rst <= '0';
            wait for 2 * clk_period;
            rst <= '1';
        else
            rst <= '1';
            wait for 2 * clk_period + input_delay;
            rst <= '0';
        end if;
        wait until rising_edge(clk);
        wait for clk_period; -- optional
        reset_done <= True;
        wait;
    end process;

    cycleCountProc: process(clk)
    begin
        if reset_done and rising_edge(clk) then
            cycle_counter <= cycle_counter + 1;
        end if;
    end process;

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

    timing_started_probe <= '1' when timing_started else '0';
    timing_stopped_probe <= '1' when timing_stopped else '0';

    --  =======================================================================
    --! ============================ PDI Stimulus =============================
    tb_read_pdi : process
        variable line_data     : LINE;
        variable word_block    : STD_LOGIC_VECTOR(W-1 downto 0) := (others => '0');
        variable read_result   : BOOLEAN;
        variable line_head     : STRING(1 to 6);
        variable stall_cycles  : INTEGER;
        variable actkey_hash   : BOOLEAN; -- either actkey or hash instruction
        variable op_sent       : BOOLEAN := False; -- instruction other than actkey or hash was already sent
    begin
        wait until reset_done;
        wait until rising_edge(clk);
        
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
                    
                    actkey_hash := (word_block(W-1 downto W-8) = X"70") or (word_block(W-1 downto W-8) = X"80"); -- for all values of W

                    -- stalls
                    if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
                        stall_cycles := get_stalls(G_TEST_IPSTALL);
                        if stall_cycles > 0 then
                            pdi_valid <= '0';
                            wait for stall_cycles * clk_period;
                            wait until rising_edge(clk); -- TODO verify number of generated stall cycles
                        end if;
                    elsif G_TEST_MODE = 4 and line_head = cons_ins and (actkey_hash or op_sent) and timing_started then
                        if not timing_stopped then
                            pdi_valid <= '0';
                            wait until rising_edge(clk) and timing_stopped; -- wait for DO process to complete timed operation
                        end if;
                        timing_started <= False; -- signal to DO: I saw you stopped timing
                    end if;

                    pdi_valid <= '1';
                    pdi_data <= word_block;
                    wait until rising_edge(clk) and pdi_ready = '1';
                    
                    -- NOTE: should never stall here
                    if G_TEST_MODE = 4 and line_head = cons_ins then
                        op_sent := not actkey_hash;
                        if not timing_started then
                            start_cycle <= cycle_counter;
                            timing_started <= True;
                            wait for 0 ns; -- yield to update timing_started signal as there could be no wait before next read
                        end if;
                    end if;

                end loop;
            end if;
        end loop;

        pdi_valid <= '0';

        if timing_started and not timing_stopped then
            wait until timing_stopped;
            timing_started <= False;
        end if;

        wait; -- forever
    end process;

    --  =======================================================================
    --! ============================ SDI Stimulus =============================
    tb_read_sdi : process
        variable line_data    : LINE;
        variable word_block   : STD_LOGIC_VECTOR(SW-1 downto 0) := (others => '0');
        variable read_result  : BOOLEAN;
        variable line_head    : STRING(1 to 6);
        variable stall_cycles : INTEGER;
    begin
        wait until reset_done;
        wait until rising_edge(clk);

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
                            -- wait until rising_edge(clk);
                        end if;
                    elsif G_TEST_MODE = 4 and not timing_started then
                        sdi_valid <= '0';
                        wait until timing_started;
                    end if;

                    sdi_valid <= '1';
                    sdi_data <= word_block;
                    wait until rising_edge(clk) and sdi_ready = '1';
               end loop;
            end if;
        end loop;
        sdi_valid <= '0';
        wait; -- forever
    end process;

    --  =======================================================================
    --! =========================== DO Verification ===========================
    tb_verifydata : process
        variable line_no        : INTEGER := 0;
        variable line_data      : LINE;
        variable logMsg         : LINE;
        variable failMsg        : LINE;
        variable tb_block       : STD_LOGIC_VECTOR(20 - 1 downto 0);
        variable word_block     : STD_LOGIC_VECTOR(W  - 1 downto 0) := (others => '0');
        variable read_result    : BOOLEAN;
        variable temp_read      : STRING(1 to 6);
        variable word_count     : INTEGER := 1;
        variable force_exit     : BOOLEAN := False;
        variable failed         : BOOLEAN := False;
        variable msgid          : INTEGER;
        variable keyid          : INTEGER;
        variable opcode         : STD_LOGIC_VECTOR(3 downto 0);
        variable num_fails      : INTEGER := 0;
        variable testcase       : INTEGER := 0;
        variable stall_cycles   : INTEGER;
        variable cycles         : INTEGER;
        variable end_cycle      : NATURAL;
        variable end_time       : TIME;
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

                        -- stalls
                        if G_TEST_MODE = 1 or G_TEST_MODE = 3 then
                            stall_cycles := get_stalls(G_TEST_OSTALL);
                            if stall_cycles > 0 then
                                do_ready <= '0';
                                wait for stall_cycles * clk_period;
                                -- wait until rising_edge(clk);
                            end if;
                        elsif G_TEST_MODE = 4 and not timing_started then
                            -- stall until timing has started from PDI
                            do_ready <= '0';
                            timing_stopped <= False;
                            wait until timing_started;
                        end if;

                        do_ready <= '1';
                        wait until rising_edge(clk) and do_valid = '1';

                        if not word_pass(do_data, word_block) then
                            failed := True;
                            write(logMsg, STRING'("[Log] Msg ID #")
                                & INTEGER'image(msgid)
                                & STRING'(" fails at line #") & INTEGER'image(line_no)
                                & STRING'(" word #") & INTEGER'image(word_count));
                            writeline(log_file,logMsg);
                            write(logMsg, STRING'("[Log]     Expected: ")
                                & LWC_TO_HSTRING(word_block)
                                & STRING'(" Received: ") & LWC_TO_HSTRING(do_data));
                            writeline(log_file,logMsg);

                            report " --- MsgID #" & INTEGER'image(testcase)
                                & " Data line #" & INTEGER'image(line_no)
                                & " Word #" & INTEGER'image(word_count)
                                & " at " & TIME'image(now) & " FAILS ---"
                                severity error;
                            report "Expected: " & LWC_TO_HSTRING(word_block)
                                & " Actual: " & LWC_TO_HSTRING(do_data) severity error;
                            write(result_file, STRING'("fail"));
                            num_fails := num_fails + 1;
                            write(failMsg,  STRING'("Failure #") & INTEGER'image(num_fails)
                                & " MsgID: " & INTEGER'image(testcase));-- & " Operation: ");

                            write(failMsg, STRING'(" Line: ") & INTEGER'image(line_no)
                                & " Word: " & INTEGER'image(word_count)
                                & " Expected: " & LWC_TO_HSTRING(word_block)
                                & " Received: " & LWC_TO_HSTRING(do_data));
                            writeline(failures_file, failMsg);
                            if num_fails >= G_MAX_FAILURES then
                                force_exit := True;
                            end if;
                        else
                            write(logMsg, STRING'("[Log]     Expected: ")
                                & LWC_TO_HSTRING(word_block)
                                & STRING'(" Received: ") & LWC_TO_HSTRING(do_data)
                                & STRING'(" Matched!"));
                            writeline(log_file,logMsg);
                        end if;
                        word_count := word_count + 1;

                        if G_TEST_MODE = 4 and temp_read = cons_stt then
                            assert timing_started;
                            cycles := cycle_counter - start_cycle;
                            timing_stopped <= True;
                            do_ready <= '0';
                            wait until not timing_started;
                            write(logMsg, INTEGER'image(msgid) & ", "  & INTEGER'image(cycles) );
                            writeline(timing_file, logMsg);
                            report "[Timing] MsgId: " & INTEGER'image(msgid) & ", cycles: " & INTEGER'image(cycles) severity note;
                        end if;

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
                        write(logMsg, STRING'("[Log] == Verifying msg ID #")
                            & INTEGER'image(testcase));
                        if (opcode = INST_ENC) then
                            write(logMsg, STRING'(" for ENC"));
                        elsif (opcode = INST_HASH) then
                            write(logMsg, STRING'(" for HASH"));
                        else
                            write(logMsg, STRING'(" for DEC"));
                        end if;
                        writeline(log_file,logMsg);
                    end if;
                    report "---------Started verifying MsgID = " & INTEGER'image(testcase) severity note;
                end if;
            end if;
        end loop;

        end_cycle := cycle_counter;
        end_time := now;

        do_ready <= '0';
        wait until rising_edge(clk);
        
        if failed then
            report "FAIL (1): SIMULATION FINISHED after " & INTEGER'image(end_cycle) & " cycles at " & TIME'image(end_time) severity failure; -- error
            write(logMsg, "FAIL (1): SIMULATION FINISHED after " & INTEGER'image(end_cycle) & " cycles at " & TIME'image(end_time));
            write(result_file, "1");
        else
            report "PASS (0): SIMULATION FINISHED after " & INTEGER'image(end_cycle) & " cycles at " & TIME'image(end_time) severity note;
            write(logMsg, "PASS (0): SIMULATION FINISHED after " & INTEGER'image(end_cycle) & " cycles at " & TIME'image(end_time));
            write(result_file, "0");
        end if;
        
        writeline(log_file, logMsg);
        write(logMsg, STRING'("[Log] Done"));
        writeline(log_file, logMsg);

        file_close(do_file);
        file_close(result_file);
        file_close(log_file);
        file_close(timing_file);

        stop_clock <= True;
        wait;
    end process;

end architecture;
