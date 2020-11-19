-------------------------------------------------------------------------------
--! @file       LWC_TB.vhd
--! @brief      Testbench based on the GMU CAESAR project.
--! @project    CAESAR Candidate Evaluation
--! @author     Ekawat (ice) Homsirikamol
--! @copyright  Copyright (c) 2015, 2020 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--! @version    1.1.0
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use std.textio.all;

use work.LWC_TB_compatibility_pkg.all;
use work.NIST_LWAPI_pkg.all;


entity LWC_TB IS
    generic (
        G_MAX_FAILURES      : integer := 100;
        G_TEST_MODE         : integer := 0;
        G_TEST_IPSTALL      : integer := 10;
        G_TEST_ISSTALL      : integer := 100;
        G_TEST_OSTALL       : integer := 40;
        G_PERIOD_PS         : integer := 10_000;
        G_FNAME_PDI         : string  := "../KAT/v1/pdi.txt";
        G_FNAME_SDI         : string  := "../KAT/v1/sdi.txt";
        G_FNAME_DO          : string  := "../KAT/v1/do.txt";
        G_FNAME_LOG         : string  := "log.txt";
        G_FNAME_TIMING      : string  := "timing.txt";
        G_FNAME_TIMING_CSV  : string  := "timing.csv";
        G_FNAME_FAILED_TVS  : string  := "failed_test_vectors.txt";
        G_FNAME_RESULT      : string  := "result.txt"
    );
end LWC_TB;

architecture behavior of LWC_TB is
	
    --! bus width. 
    constant G_PWIDTH           : integer := W;
    constant G_SWIDTH           : integer := SW;
    -- for automated/scripted testing override:
    --    W and SW in work.NIST_LWAPI_pkg
    --    CCW and CCSW in work.design_pkg

    --! =================== --
    --! SIGNALS DECLARATION --
    --! =================== --

    --! simulation signals (used by ATHENa script, ignore if not used)
    signal simulation_fails     : std_logic := '0';
    signal stop_clock           : boolean   := False;
    
    -- reset completed
    signal reset_done           : boolean   := False;

    --! globals
    signal clk                  : std_logic := '0';
    signal rst                  : std_logic := '0';

    --! pdi
--    signal fpdi_din             : std_logic_vector(G_PWIDTH-1 downto 0);
--    signal fpdi_din_valid       : std_logic := '0';
--    signal fpdi_din_ready       : std_logic;
--    signal fpdi_dout            : std_logic_vector(G_PWIDTH-1 downto 0);
--    signal fpdi_dout_valid      : std_logic;
--    signal fpdi_dout_ready      : std_logic;
    signal pdi_data         : std_logic_vector(G_PWIDTH-1 downto 0) := (others => '0');
    signal pdi_valid        : std_logic := '0';
--    signal pdi_valid_selected   : std_logic;
    signal pdi_ready        : std_logic;

    --! sdi
--    signal fsdi_din             : std_logic_vector(G_SWIDTH-1 downto 0) := (others => '0');
--    signal fsdi_din_valid       : std_logic := '0';
--    signal fsdi_din_ready       : std_logic;
--    signal fsdi_dout            : std_logic_vector(G_SWIDTH-1 downto 0);
--    signal fsdi_dout_valid      : std_logic;
--    signal fsdi_dout_ready      : std_logic;
    signal sdi_data             : std_logic_vector(G_SWIDTH-1 downto 0) := (others => '0');
    signal sdi_valid            : std_logic := '0';
--    signal sdi_valid_selected   : std_logic;
    signal sdi_ready            : std_logic;

    --! do
    signal do_data              : std_logic_vector(G_PWIDTH-1 downto 0);
    signal do_valid             : std_logic;
    signal do_last              : std_logic;
    signal do_ready             : std_logic;

    --! Verification signals
--    signal stall_pdi_valid      : std_logic := '0';
--    signal stall_sdi_valid      : std_logic := '0';
--    signal stall_do_full        : std_logic := '0';
    signal stall_msg            : std_logic := '0';
    constant SUCCESS_WORD       : std_logic_vector(G_PWIDTH - 1 downto 0) := INST_SUCCESS & (G_PWIDTH - 5 downto 0 => '0');
    constant FAILURE_WORD       : std_logic_vector(G_PWIDTH - 1 downto 0) := INST_FAILURE & (G_PWIDTH - 5 downto 0 => '0');
    --! Measurement signals
    signal clk_cycle_counter    : integer := 0;
    signal latency              : integer := 0;
    signal latency_done         : std_logic := '0';
    signal start_latency_timer  : std_logic := '0';
    ------------- clock constant ------------------
    constant clk_period         : time := G_PERIOD_PS * ps;
    ----------- end of clock constant -------------

    ------------- string constant ------------------
    --! constant
    constant cons_tb            : string(1 to 6) := "# TB :";
    constant cons_ins           : string(1 to 6) := "INS = ";
    constant cons_hdr           : string(1 to 6) := "HDR = ";
    constant cons_dat           : string(1 to 6) := "DAT = ";
    constant cons_stt           : string(1 to 6) := "STT = ";

    --! Shared constant
    constant cons_eof           : string(1 to 6) := "###EOF";
    
    constant input_delay        : time := 0.05 ns;


    signal tv_count     : integer:=0;

    ------------------- input / output files ----------------------
    file pdi_file       : text open read_mode  is G_FNAME_PDI;
    file sdi_file       : text open read_mode  is G_FNAME_SDI;
    file do_file        : text open read_mode  is G_FNAME_DO;

    file log_file       : text open write_mode is G_FNAME_LOG;
    file timing_file    : text open write_mode is G_FNAME_TIMING;
    file timing_csv     : text open write_mode is G_FNAME_TIMING_CSV;
    file result_file    : text open write_mode is G_FNAME_RESULT;
    file failures_file  : text open write_mode is G_FNAME_FAILED_TVS;
    ----------------- end of input / output files -----------------

    function word_pass(actual: std_logic_vector(G_PWIDTH-1 downto 0); expected: std_logic_vector(G_PWIDTH-1 downto 0)) return boolean is
    begin
        for i in G_PWIDTH-1 downto 0 loop
            if  actual(i) /= expected(i) and expected(i) /= 'X' then
                return False;
            end if;
        end loop;
        return True;
    end function word_pass;
	
	----------------- component decrations ------------------
	-- LWC is instantiated as component to make mixed-language simulation possible
	component LWC
		port(
			clk       : in  std_logic;
			rst       : in  std_logic;
			pdi_data  : in  std_logic_vector(W - 1 downto 0);
			pdi_valid : in  std_logic;
			pdi_ready : out std_logic;
			sdi_data  : in  std_logic_vector(W - 1 downto 0);
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
            wait for clk_period/2;
            clk <= '0';
            wait for clk_period/2;
        else
            wait;
        end if;
    end process genClk;
	
	-- LWC is instantiated as a component for mixed languages simulation
	uut: LWC
		port map(
	        clk          => clk,
	        rst          => rst,
	        pdi_data     => pdi_data,
	        pdi_valid    => pdi_valid,
	        pdi_ready    => pdi_ready,
	        sdi_data     => sdi_data,
	        sdi_valid    => sdi_valid,
	        sdi_ready    => sdi_ready,
	        do_data      => do_data,
	        do_ready     => do_ready,
	        do_valid     => do_valid,
	        do_last      => do_last
		);

	genRst: process
	begin
	   wait for 100 ns; -- Xilinx GSR takes 100ns, required for post-synth simulation
	   wait until falling_edge(clk);
	   if ASYNC_RSTN then
	        rst <= '0'; -- @suppress "Dead code"
	        wait for 3*clk_period;
	        rst <= '1';
    	else
	        rst <= '1';
	        wait for 3*clk_period;
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
        variable line_data      : line;
        variable word_block     : std_logic_vector(G_PWIDTH-1 downto 0) := (others=>'0');
        variable read_result    : boolean;
        variable line_head      : string(1 to 6);
    begin

		wait until reset_done;
		
		wait on clk until clk = '1';
		wait for input_delay;
		
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
	            	pdi_data <= word_block;
                    pdi_valid <= '1';
            		wait on clk until clk = '1' and pdi_ready = '1';
            		wait for input_delay;
			   end loop;
			end if;
        end loop;
        pdi_valid <= '0';
        wait; -- forever
    end process;
    --! =======================================================================
    --! ==================== DATA POPULATION FOR SECRET DATA ==================
    tb_read_sdi : process
        variable line_data      : line;
        variable word_block     : std_logic_vector(G_SWIDTH-1 downto 0) := (others=>'0');
        variable read_result    : boolean;
        variable line_head      : string(1 to 6);
    begin
        wait until reset_done;
        
        wait on clk until clk = '1';
        wait for input_delay;
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
                    
                    sdi_data <= word_block;
                    wait on clk until clk = '1' and sdi_ready = '1';
                    wait for input_delay;
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
        variable tb_block       : std_logic_vector(20      -1 downto 0);
        variable word_block     : std_logic_vector(G_PWIDTH-1 downto 0) := (others=>'0');
        variable read_result    : boolean;
        variable temp_read      : string(1 to 6);
        variable word_count     : integer := 1;
        variable instr_encoding : boolean := False;
        variable force_exit     : boolean := False;
        variable msgid          : integer;
        variable keyid          : integer;
        variable opcode         : std_logic_vector(3 downto 0);
        variable num_fails      : integer := 0;
        variable testcase       : integer := 0;


    begin
        wait until reset_done;
        if G_TEST_MODE = 4 then
            file_open(do_file, G_FNAME_DO, read_mode); -- reset the file pointer
        end if;

        wait for input_delay;
        do_ready <= '1';

        while not endfile(do_file) loop
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

                        wait on clk until clk = '1' and do_valid = '1';

                        if not word_pass(do_data, word_block) then
                            simulation_fails <= '1';
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
                        wait for input_delay;
                end loop;
                elsif temp_read = cons_eof then
                    force_exit := True;
                elsif temp_read = cons_tb then
                    testcase := testcase + 1;
                    LWC_HREAD(line_data, tb_block, read_result); --! read data
                    instr_encoding := False;
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
        -- while not endfile (do_file) and valid_line and not force_exit loop
        --     --! Keep reading new line until a valid line is found
        --     LWC_HREAD( line_data, word_block, read_result );
        --     while ((read_result = False or valid_line = False)
        --           and (not endfile(do_file)))
        --     loop
        --         readline(do_file, line_data);
        --         line_no := line_no + 1;
        --         read(line_data, temp_read, read_result); --! read line header
        --         if (temp_read = cons_hdr
        --             or temp_read = cons_dat
        --             or temp_read = cons_stt)
        --         then
        --             valid_line := True;
        --             word_count := 1;
        --         else
        --             valid_line := False;
        --             if (temp_read = cons_tb) then
        --                 instr_encoding := True;
        --             end if;
        --         end if;

        --         if (temp_read = cons_eof) then
        --             force_exit := True;
        --         end if;

        --         if instr_encoding then
        --         	testcase := testcase + 1;
        --             LWC_HREAD(line_data, tb_block, read_result); --! read data
        --             instr_encoding := False;
        --             read_result    := False;
        --             opcode := tb_block(19 downto 16);
        --             keyid  := to_integer(to_01(unsigned(tb_block(15 downto 8))));
        --             msgid  := to_integer(to_01(unsigned(tb_block(7  downto 0))));
        --             if ((opcode = INST_DEC or opcode = INST_ENC or opcode = INST_HASH)
        --                 or (opcode = INST_SUCCESS or opcode = INST_FAILURE))
        --             then
        --                 write(logMsg, string'("[Log] == Verifying msg ID #")
        --                     & integer'image(testcase));
        --                 if (opcode = INST_ENC) then
        --                     write(logMsg, string'(" for ENC"));
        --                 elsif (opcode = INST_HASH) then
        --                     write(logMsg, string'(" for HASH"));
        --                 else
        --                     write(logMsg, string'(" for DEC"));
        --                 end if;
        --                 writeline(log_file,logMsg);
        --             end if;

        --             report "---------Started verifying MsgID = " & integer'image(testcase) severity note;
        --         else
        --             LWC_HREAD(line_data, word_block, read_result); --! read data
        --         end if;
        --     end loop;

        --     if valid_line then
        --         do_ready <= '1';
        --         wait on clk until clk = '1' and do_valid = '1';

        --         word_pass := 1;
        --         for i in G_PWIDTH-1 downto 0 loop
        --             if  do_data(i) /= word_block(i)
        --                 and word_block(i) /= 'X'
        --             then
        --                 word_pass := 0;
        --             end if;
        --         end loop;
        --         if word_pass = 0 then
        --             simulation_fails <= '1';
        --             write(logMsg, string'("[Log] Msg ID #")
        --                 & integer'image(msgid)
        --                 & string'(" fails at line #") & integer'image(line_no)
        --                 & string'(" word #") & integer'image(word_count));
        --             writeline(log_file,logMsg);
        --             write(logMsg, string'("[Log]     Expected: ")
        --                 & LWC_TO_HSTRING(word_block)
        --                 & string'(" Received: ") & LWC_TO_HSTRING(do_data));
        --             writeline(log_file,logMsg);

        --             report " --- MsgID #" & integer'image(testcase)
        --                 & " Data line #" & integer'image(line_no)
        --                 & " Word #" & integer'image(word_count)
        --                 & " at " & time'image(now) & " FAILS ---"
        --                 severity error;
        --             report "Expected: " & LWC_TO_HSTRING(word_block)
        --                 & " Actual: " & LWC_TO_HSTRING(do_data) severity error;
        --             write(result_file, string'("fail"));
        --             num_fails := num_fails + 1;
        --             write(failMsg,  string'("Failure #") & integer'image(num_fails)
        --             	& " MsgID: " & integer'image(testcase));-- & " Operation: ");

        --             write(failMsg, string'(" Line: ") & integer'image(line_no)
        --             	& " Word: " & integer'image(word_count)
        --             	& " Expected: " & LWC_TO_HSTRING(word_block)
        --                 & " Received: " & LWC_TO_HSTRING(do_data));
        --             writeline(failures_file, failMsg);
        --             if num_fails >= G_MAX_FAILURES then
        --                 force_exit := True;
        --             end if;
        --         else
        --             write(logMsg, string'("[Log]     Expected: ")
        --                 & LWC_TO_HSTRING(word_block)
        --                 & string'(" Received: ") & LWC_TO_HSTRING(do_data)
        --                 & string'(" Matched!"));
        --             writeline(log_file,logMsg);
        --         end if;

        --         word_count := word_count + 1;
        --     end if;
        -- end loop;

        do_ready <= '0';
        wait for clk_period;

        if (simulation_fails = '1') then
            report "FAIL (1): SIMULATION FINISHED || Testvector files: "
                & G_FNAME_PDI & " " & G_FNAME_SDI & " " & G_FNAME_DO severity error;
            write(result_file, "1");
        else
            report "PASS (0): SIMULATION FINISHED || Testvector files: "
                & G_FNAME_PDI & " " & G_FNAME_SDI & " " & G_FNAME_DO severity note;
            write(result_file, "0");
        end if;
        write(logMsg, string'("[Log] Done"));
        writeline(log_file,logMsg);
        file_close(do_file);
        stop_clock <= True;
        wait;
    end process;
    --! =======================================================================


    --! =======================================================================
    --! =================== Test MODE =========================================
    --Simple process to count cycles
    clock_conter: process
    begin
        wait until rising_edge(clk);
        clk_cycle_counter <= clk_cycle_counter + 1;
    end process;
    
    latency_counter : process
    variable latency_start : integer;
    begin
        wait until start_latency_timer = '1';
        latency_done <= '0';
        latency <= 0;
        if pdi_ready /= '1' then -- Wait until first word is read before starting timer
            wait until pdi_ready = '1';
        end if;
        latency_start := clk_cycle_counter;
        wait until rising_edge(clk);
        if do_valid /= '1' then
         --   wait on do;
            wait until do_valid = '1'; -- wait until first word of output
            wait until falling_edge(clk);
        end if;
        latency <= (clk_cycle_counter - latency_start) + 1; -- Add 1 for Fifo write
        latency_done <= '1';
    end process;

    genMeasurementMode : process
        variable seg_cnt, seg_cnt_start : integer := 0;
        variable seg_last : std_logic;
        variable seg_eot : std_logic;
        variable seg_eoi : std_logic;
        variable seg_type : std_logic_vector(3 downto 0);
        variable ins_opcode : std_logic_vector(3 downto 0);
        variable msg_start_time, exec_time : integer;
        variable start_time : time;
        variable pt_size, ct_size, ad_size, hash_size, new_key : integer := 0;
        variable msg_idx: integer := 0;
        variable first_seg : integer := 1;
        variable timingMsg         : line;
        variable line_data : line;
        variable linelength : integer;
        variable read_result    : boolean;
        variable temp_read      : string(1 to 200);
        variable block_size : integer := -1; --block sizes in bytes
        variable block_size_ad : integer := -1;
        variable block_size_hash : integer := -1;
        variable ina, inm, inc, inh : integer := 0;
        variable charindex : integer :=  15; --std_logic_vector(G_PWIDTH - 1 downto 0);
    begin
        if G_TEST_MODE = 4 then
            stall_msg <= '0';
            if first_seg = 1 then
                -- parse block size from do file
                while (not endfile (do_file)) loop
                        readline(do_file, line_data);
                        linelength := line_data'length;
                        read(line_data, temp_read(1 to line_data'length), read_result);
                        if temp_read(1 to 15) = "# block_size   " then
                            while temp_read(charindex) /= '-' loop
                                charindex := charindex + 1;
                            end loop;
                            block_size := (integer'value(temp_read(charindex+1 to linelength))) / 8;
                        elsif temp_read(1 to 15) = "# block_size_ad" then
                            while temp_read(charindex) /= '-' loop
                                charindex := charindex + 1;
                            end loop;
                            block_size_ad := (integer'value(temp_read(charindex+1 to linelength))) / 8;
                        elsif temp_read(1 to 23) = "# block_size_msg_digest" then
                            while temp_read(charindex) /= '-' loop
                                charindex := charindex + 1;
                            end loop;
                            if temp_read(linelength-3 to linelength) /= "None" then
                                block_size_hash := integer'value(temp_read(charindex+1 to linelength))/8;
                            end if;
                            exit;
                         end if;
                end loop;
                file_close(do_file);
                write(timingMsg, string'("### Timing Results for LWC Core ###"));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Msg ID,New Key,Operation,AD Size,Msg Size,Na,Nm,Nc,Nh,Bla,Blm,Blc,Blh,Ina,Inm,Inc,Inh,Actual Execution Time,Actual Latency"));
                writeline(timing_csv, timingMsg);
                first_seg := 0;
            else
                write(timingMsg, string'("")); -- new line
                writeline(timing_file, timingMsg);
            end if;
            wait until rising_edge(clk) and pdi_ready = '1' and pdi_valid = '1';
            msg_start_time := 0;
            pt_size:=0; ct_size:=0; ad_size:=0; hash_size:=0; new_key := 0;
            seg_cnt := 0; seg_type := "0000";
            exec_time := 0;
            seg_cnt := 0;
            -- Determine Instruction
            ins_opcode := pdi_data(G_PWIDTH-1 downto G_PWIDTH-4);
            if ins_opcode = INST_ENC or ins_opcode = INST_DEC or ins_opcode = INST_HASH or ins_opcode = INST_ACTKEY then
              msg_start_time := clk_cycle_counter;
              start_time := time(now);
                if ins_opcode = INST_ACTKEY then
                    new_key := 1;
                    wait until rising_edge(clk) and pdi_ready = '1' and pdi_valid = '1';
                    ins_opcode := pdi_data(G_PWIDTH-1 downto G_PWIDTH-4);
                end if;
            end if;
                ----- Segment loop-------------
            segment_loop : while True loop
                wait until falling_edge(clk) and pdi_ready = '1' and pdi_valid = '1';
                -- Obtain segment header
                if seg_cnt = 0 then
                    -- parse segment header
                    seg_type := pdi_data(G_PWIDTH-1 downto G_PWIDTH-4);
                    seg_eoi := pdi_data(G_PWIDTH-6);
                    seg_eot := pdi_data(G_PWIDTH-7);
                    seg_last := pdi_data(G_PWIDTH-8);
                    if G_PWIDTH = 8 then
                       wait until falling_edge(clk) and pdi_ready = '1' and pdi_valid = '1'; -- @suppress "Dead code"
                       wait until falling_edge(clk) and pdi_ready = '1' and pdi_valid = '1'; --wait segment length top
                       seg_cnt := to_integer(unsigned(pdi_data & "00000000"));
                       wait until falling_edge(clk) and pdi_ready = '1' and pdi_valid = '1';
                       seg_cnt := seg_cnt + to_integer(unsigned(pdi_data));
                    elsif G_PWIDTH = 16 then -- @suppress "Dead code"
                       wait until falling_edge(clk) and pdi_ready = '1' and pdi_valid = '1'; --wait segment length top
                       seg_cnt := to_integer(unsigned(pdi_data));
                    else --G_PWIDTH 32
                        seg_cnt := to_integer(unsigned(pdi_data(15 downto 0)));
                    end if;
                    seg_cnt_start := seg_cnt;
                    if seg_type = HDR_PT then pt_size := pt_size + seg_cnt;
                    elsif seg_type = HDR_CT then ct_size := ct_size + seg_cnt;
                    elsif seg_type = HDR_AD then ad_size := ad_size + seg_cnt;
                    elsif seg_type = HDR_HASH_MSG then hash_size := hash_size + seg_cnt;
                    end if;
                    -- Need to handle the case when segment header but the len is 0
                    if seg_cnt = 0 and seg_last = '1' and
                                (seg_type = HDR_PT or seg_type = HDR_TAG or seg_type = HDR_HASH_MSG) then

                        wait until falling_edge(clk);
                        stall_msg <= '1'; -- last segment  wait until cipher is done
                        if (do_last /= '1' or (do_data /= SUCCESS_WORD and do_data /= FAILURE_WORD)) then
                                wait until (do_last = '1' and (do_data = SUCCESS_WORD or do_data = FAILURE_WORD));
                        end if;
                        stall_msg <= '0';
                        exec_time := clk_cycle_counter-msg_start_time;
                        msg_idx := msg_idx + 1;
                        exit;
                    end if;
                else
                    if (seg_cnt = seg_cnt_start) and (seg_type = HDR_PT or seg_type = HDR_CT) then 
                        start_latency_timer <= '1';
                    end if;
                    if (seg_cnt <= 4 and G_PWIDTH = 32) or (seg_cnt <= 2 and G_PWIDTH = 16) or (seg_cnt <= 1 and G_PWIDTH = 8) then
                        seg_cnt := 0;
                        if ((seg_type = HDR_PT or seg_type = HDR_TAG or seg_type = HDR_HASH_MSG) and seg_last = '1')then
                            wait until falling_edge(clk);
                            stall_msg <= '1'; -- last segment wait until cipher is done
                            if latency_done /= '1' and start_latency_timer = '1' then
                                wait until latency_done = '1';
                                if (do_last = '1' and (do_data = SUCCESS_WORD or do_data = FAILURE_WORD)) then
                                    stall_msg <= '0';
                                    exec_time := clk_cycle_counter-msg_start_time;
                                    msg_idx := msg_idx + 1;
                                    exit;
                                end if;
                            end if;
                            start_latency_timer <= '0';
                            if (do_last /= '1' or (do_data /= SUCCESS_WORD and do_data /= FAILURE_WORD)) then
                                wait until (do_last = '1' and (do_data = SUCCESS_WORD or do_data = FAILURE_WORD));
                            end if;
                            stall_msg <= '0';
                            exec_time := clk_cycle_counter-msg_start_time;
                            msg_idx := msg_idx + 1;
                            exit;
                        end if;
                    else
                        seg_cnt := seg_cnt - (G_PWIDTH / 8);
                    end if;
                end if;
            end loop segment_loop;
            if ad_size mod block_size_ad > 0 then
                ina := 1;
            else
                ina := 0;
            end if;
            report "MsgId: " & integer'image(msg_idx) & " at " & time'image(start_time);
            write(timingMsg, string'("Msg ID: ") &
                  integer'image(msg_idx) &
                  string'(" at ") &
                  time'image(start_time));
            writeline(timing_file, timingMsg);
            if new_key = 1 then
                report "New Key";
                write(timingMsg, string'("New Key"));
                writeline(timing_file, timingMsg);
            end if;
            if seg_type = HDR_PT or seg_type = HDR_AD then
                if pt_size mod block_size > 0 then
                    inm := 1;
                else
                    inm := 0;
                end if;
                report "Authenticated Encryption";
                report "AD size = " & integer'image(ad_size) & " bytes, PT size = " & integer'image(pt_size) & " bytes";
                report "Na = " & integer'image((ad_size/block_size_ad)) & " Bla = " & 
		                		integer'image(ad_size mod block_size_ad) & " Ina = " & integer'image(ina);
                report "Nm = " & integer'image((pt_size/block_size)) & " Blm = " &
		                		integer'image(pt_size mod block_size) & " Inm = " & integer'image(inm);
                report "Execution time = " & integer'image(exec_time) & " cycles";
                report "Latency = " & integer'image(latency) & " cycles";
                
                write(timingMsg, string'("Authenticated Encryption"));
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("AD size = ") &
                                 integer'image(ad_size) &
                                 string'(" bytes, PT size = ") & 
                                 integer'image(pt_size) &
                                 string'(" bytes"));
                                 
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("Na = ") & integer'image(ad_size/block_size_ad) &
                                 string'(" Bla = ") & integer'image(ad_size mod block_size_ad) &
                                 string'(" Ina = ") & integer'image(ina) &
                                 string'(" Nm = ") & integer'image(pt_size/block_size) &
                                 string'(" Blm = ") & integer'image(pt_size mod block_size) &
                                 string'(" Inm = ") & integer'image(inm));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Execution time = ") &
                                 integer'image(exec_time) & 
                                 string'(" cycles"));
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("Latency = ") &
                                 integer'image(latency) & 
                                 string'(" cycles"));
                writeline(timing_file, timingMsg);
                write(timingMsg,integer'image(msg_idx) &
                                string'(",") &
                                integer'image(new_key) &
                                string'(",AE,") &
                                integer'image(ad_size) &
                                string'(",") &
                                integer'image(pt_size) &
                                string'(",") &
                                integer'image(ad_size/block_size_ad) &
                                string'(",") &
                                integer'image(pt_size/block_size) &
                                string'(",0,0,") &
                                integer'image(ad_size mod block_size_ad) &
                                string'(",") &
                                integer'image(pt_size mod block_size) &
                                string'(",0,0,") &
                                integer'image(ina) &
                                string'(",") &
                                integer'image(inm) &
                                string'(",0,0,") &
                                integer'image(exec_time) &
                                string'(",") &
                                integer'image(latency));
                writeline(timing_csv, timingMsg);
            elsif seg_type = HDR_TAG then
                if ct_size mod block_size > 0 then
                    inc := 1;
                else
                    inc := 0;
                end if;
                report "Authenticated Decryption";
                report "AD size = " & integer'image(ad_size) & " bytes, CT size = " & 
                				integer'image(ct_size) & " bytes";
                report "Na = " & integer'image((ad_size/block_size_ad)) & " Bla = " & 
                				integer'image(ad_size mod block_size_ad) & " Ina = " & integer'image(ina);
                report "Nc = " & integer'image((ct_size/block_size)) & " Blm = " & 
                				integer'image(ct_size mod block_size) & " Inc = " & integer'image(inc);
                report "Execution time = " & integer'image(exec_time) & " cycles";
                report "Latency = " & integer'image(latency) & " cycles";
                write(timingMsg, string'("Authenticated Decryption"));
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("AD size = ") &
                                 integer'image(ad_size) &
                                 string'(" bytes, CT size = ") & 
                                 integer'image(ct_size) &
                                 string'(" bytes"));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Na = ") & integer'image(ad_size/block_size_ad) &
                                 string'(" Bla = ") & integer'image(ad_size mod block_size_ad) &
                                 string'(" Ina = ") & integer'image(ina) &
                                 string'(" Nc = ") & integer'image(ct_size/block_size) &
                                 string'(" Blc = ") & integer'image(ct_size mod block_size) &
                                 string'(" Inc = ") & integer'image(inc));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Execution time = ") &
                                 integer'image(exec_time) & 
                                 string'(" cycles"));
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("Latency = ") &
                                 integer'image(latency) & 
                                 string'(" cycles"));
                writeline(timing_file, timingMsg);
                write(timingMsg,integer'image(msg_idx) &
                                string'(",") &
                                integer'image(new_key) &
                                string'(",AD,") &
                                integer'image(ad_size) &
                                string'(",") &
                                integer'image(ct_size) &
                                string'(",") &
                                integer'image(ad_size/block_size_ad) &
                                string'(",0,") &
                                integer'image(ct_size/block_size) &
                                string'(",0,") &
                                integer'image(ad_size mod block_size_ad) &
                                string'(",0,") &
                                integer'image(ct_size mod block_size) &
                                string'(",0,") &
                                integer'image(ina) &
                                string'(",0,") &
                                integer'image(inc) &
                                string'(",0,") &
                                integer'image(exec_time) &
                                string'(",") &
                                integer'image(latency));
                writeline(timing_csv, timingMsg);
            elsif seg_type = HDR_HASH_MSG then
                if hash_size mod block_size_hash > 0 then
                    inh := 1;
                else
                    inh := 0;
                end if;
                report "Hashing";
                report "Hash msg size = " & integer'image(hash_size) & " bytes";
                report "Nh = " & integer'image((hash_size/block_size_hash)) & " Blh = " &
                				integer'image(hash_size mod block_size_hash) & " Inc = " & integer'image(inh);
                report "Execution time = " & integer'image(exec_time) & " cycles";
                
                write(timingMsg, string'("Hashing"));
                writeline(timing_file, timingMsg);
                
                write(timingMsg, string'("Hash msg size = ") &
                                 integer'image(hash_size) &
                                 string'(" bytes"));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Nh = ") & integer'image(hash_size/block_size_hash) &
                                 string'(" Blh = ") & integer'image(hash_size mod block_size_hash) &
                                 string'(" Inh = ") & integer'image(inh));
                writeline(timing_file, timingMsg);
                write(timingMsg, string'("Execution time = ") &
                                 integer'image(exec_time) & 
                                 string'(" cycles"));
                writeline(timing_file, timingMsg);
                write(timingMsg,integer'image(msg_idx) &
                                string'(",") &
                                integer'image(new_key) &
                                string'(",HASH,0,") &
                                integer'image(hash_size) &
                                string'(",0,0,0,") &
                                integer'image(hash_size/block_size_hash) &
                                string'(",0,0,0,") &
                                integer'image(hash_size mod block_size_hash) &
                                string'(",0,0,0,") &
                                integer'image(inh) &
                                string'(",") & 
                                integer'image(exec_time) &
                                string'(",") &
                                integer'image(latency));
                writeline(timing_csv, timingMsg);
            end if;
         else
             wait;
         end if;
    end process;


--    genInputStall1 : process
--    begin
--        if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
--            wait until rising_edge(clk);
--            wait for 1/4*clk_period;
--            if (pdi_ready = '0') then
--                wait until falling_edge(clk) and pdi_ready = '1';
--            end if;
--            if (pdi_valid = '0') then
--                wait until falling_edge(clk) and pdi_valid = '1';
--            end if;
--            wait for clk_period;
--            stall_pdi_valid <= '1';
--            wait for clk_period*G_TEST_IPSTALL;
--            stall_pdi_valid <= '0';
--        else
--            wait;
--        end if;
--    end process;

--    genInputStall2 : process
--    begin
--        if G_TEST_MODE = 1 or G_TEST_MODE = 2 then
--            wait until rising_edge(clk);
--            wait for 1/4*clk_period;
--            if (sdi_ready = '0') then
--                wait until falling_edge(clk) and sdi_ready = '1';
--            end if;
--            if (sdi_valid = '0') then
--                wait until falling_edge(clk) and sdi_valid = '1';
--            end if;
--            wait for clk_period;
--            stall_sdi_valid <= '1';
--            wait for clk_period*G_TEST_ISSTALL;
--            stall_sdi_valid <= '0';
--        else
--            wait;
--        end if;
--    end process;

--    genOutputStall : process
--    begin
--        if G_TEST_MODE = 1 or G_TEST_MODE = 3 then
--            wait until rising_edge(clk);
--            wait for 1/4*clk_period;
--            if (do_ready = '0') then
--                wait until falling_edge(clk) and do_ready = '1';
--            end if;
--            if (do_valid = '0') then
--                wait until falling_edge(clk) and do_valid = '1';
--            end if;
--            wait for clk_period;
--            stall_do_full <= '1';
--            wait for clk_period*G_TEST_OSTALL;
--            stall_do_full <= '0';
--        else
--            wait;
--        end if;
--    end process;
end;
