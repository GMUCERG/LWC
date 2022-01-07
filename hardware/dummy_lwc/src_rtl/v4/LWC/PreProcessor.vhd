--------------------------------------------------------------------------------
--! @file       PreProcessor.vhd
--! @brief      Pre-processor for NIST LWC API
--!
--! @author     Michael Tempelmeier
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!
--! @author     Farnoud Farahmand
--! @copyright  Copyright (c) 2019 Cryptographic Engineering Research Group
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
--! Description
--!
--!
--!
--!
--!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity PreProcessor is
    generic(
        G_OFFLINE : boolean := False
    );
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        --! Public Data input (pdi) ========================================
        pdi_data        : in  STD_LOGIC_VECTOR(W - 1 downto 0);
        pdi_valid       : in  std_logic;
        pdi_ready       : out std_logic;
        --! Secret Data input (sdi) ========================================
        sdi_data        : in  STD_LOGIC_VECTOR(SW - 1 downto 0);
        sdi_valid       : in  std_logic;
        sdi_ready       : out std_logic;
        --! Crypto Core ====================================================
        key             : out std_logic_vector(CCSW - 1 downto 0);
        key_valid       : out std_logic;
        key_ready       : in  std_logic;
        bdi             : out std_logic_vector(CCW - 1 downto 0);
        bdi_valid       : out std_logic;
        bdi_ready       : in  std_logic;
        bdi_pad_loc     : out std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_valid_bytes : out std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_size        : out std_logic_vector(2 downto 0);
        bdi_eot         : out std_logic;
        bdi_eoi         : out std_logic;
        bdi_type        : out std_logic_vector(3 downto 0);
        decrypt         : out std_logic;
        hash            : out std_logic;
        key_update      : out std_logic;
        ---! Header FIFO ===================================================
        cmd             : out std_logic_vector(W - 1 downto 0);
        cmd_valid       : out std_logic;
        cmd_ready       : in  std_logic
    );
end entity PreProcessor;

architecture PreProcessor of PreProcessor is
    -- Constants
    constant zero_data : std_logic_vector(W - 1 downto 0) := (others => '0');

    --! Segment counter
    signal ld_en_SegLenCnt      : std_logic;
    signal dec_seglen_ctr       : std_logic;
    signal last_flit_of_segment : std_logic;
    signal dout_SegLenCnt       : std_logic_vector(15 downto 0);
    signal load_SegLenCnt       : std_logic_vector(15 downto 0);

    --! Multiplexer
    signal sel_sdi_length : boolean;

    --! Flags
    signal bdi_valid_bytes_p : std_logic_vector(3 downto 0);
    signal bdi_pad_loc_p     : std_logic_vector(3 downto 0);

    --!for simulation only
    signal received_wrong_header : boolean;

    --Registers
    signal eoi_flag, nx_eoi_flag         : std_logic;
    signal eot_flag, nx_eot_flag         : std_logic;
    signal hash_flag, nx_hash_flag       : std_logic;
    signal decrypt_flag, nx_decrypt_flag : std_logic;

    --Controller
    signal bdi_eoi_internal                                       : std_logic;
    signal bdi_eot_internal                                       : std_logic;
    signal pdi_ready_internal                                     : std_logic;
    signal sdi_ready_internal                                     : std_logic;
    signal pdi_fire                                               : boolean;
    signal sdi_fire                                               : boolean;
    signal opcode_is_actkey, opcode_is_hash, opcode_is_enc_or_dec : boolean;
    signal bdi_valid_p                                            : std_logic;
    signal bdi_ready_p                                            : std_logic;
    signal key_valid_p                                            : std_logic;
    signal key_ready_p                                            : std_logic;
    signal bdi_size_p                                             : std_logic_vector(2 downto 0);

    alias pdi_opcode  : std_logic_vector(3 downto 0) is pdi_data(W - 1 downto W - 4);
    alias pdi_cmd_eoi : std_logic is pdi_data(W - 6);
    alias pdi_cmd_eot : std_logic is pdi_data(W - 7);
    alias sdi_opcode  : std_logic_vector(3 downto 0) is sdi_data(W - 1 downto W - 4);

    ---STATES
    type t_state32 is (S_INST, S_INST_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB, S_HDR_LENGTH, S_LD_LENGTH,
                       S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
                       S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH);

    type t_state16 is (S_INST, S_INST_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB, S_HDR_LENGTH, S_HDR_LENGTH_LEN, S_LD_LENGTH,
                       S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
                       S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH,
                       S_HDR_KEYLEN, S_HDR_NPUBLEN, S_HDR_ADLEN, S_HDR_MSGLEN, --
                       S_HDR_TAGLEN, S_HDR_HASHLEN); --

    type t_state8 is (S_INST, S_INST_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_NPUB, S_LD_NPUB, -- S_HDR_LENGTH, S_LD_LENGTH, TODO
                      S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG,
                      S_HDR_HASH, S_LD_HASH, S_EMPTY_HASH,
                      S_HDR_RESKEY, S_HDR_KEYLEN_MSB, S_HDR_KEYLEN_LSB,
                      S_HDR_RESNPUB, S_HDR_NPUBLEN_MSB, S_HDR_NPUBLEN_LSB,
                      S_HDR_RESAD, S_HDR_ADLEN_MSB, S_HDR_ADLEN_LSB,
                      S_HDR_RESMSG, S_HDR_MSGLEN_MSB, S_HDR_MSGLEN_LSB,
                      S_HDR_RESTAG, S_HDR_TAGLEN_MSB, S_HDR_TAGLEN_LSB,
                      S_HDR_RESHASH, S_HDR_HASHLEN_MSB, S_HDR_HASHLEN_LSB);

begin

    --! for simulation only
    -- synthesis translate_off
    process(clk)
    begin
        if rising_edge(clk) then
            assert not received_wrong_header report "Received unexpected header" severity failure;
        end if;
    end process;
    -- synthesis translate_on

    --! Segment Length Counter
    process(clk)
    begin
        if rising_edge(clk) then
            if ld_en_SegLenCnt = '1' then
                dout_SegLenCnt <= load_SegLenCnt;
            elsif dec_seglen_ctr = '1' then
                dout_SegLenCnt <= std_logic_vector(unsigned(dout_SegLenCnt) - (W / 8));
            end if;
        end if;
    end process;

    -- if there are (G_W/8) or less bytes left, we processthe last flit
    last_flit_of_segment <= '1' when (to_integer(to_01(unsigned(dout_SegLenCnt))) <= (W / 8)) else '0';

    -- set valid bytes
    with (to_integer(to_01(unsigned(dout_SegLenCnt)))) select bdi_valid_bytes_p <=
        "1110" when 3,
        "1100" when 2,
        "1000" when 1,
        "0000" when 0,
        "1111" when others;

    -- set padding location
    with (to_integer(to_01(unsigned(dout_SegLenCnt)))) select bdi_pad_loc_p <=
        "0001" when 3,
        "0010" when 2,
        "0100" when 1,
        "1000" when 0,
        "0000" when others;

    --! Registers
    process(clk)
    begin
        if rising_edge(clk) then
            hash_flag    <= nx_hash_flag;
            decrypt_flag <= nx_decrypt_flag;
            eoi_flag     <= nx_eoi_flag;
            eot_flag     <= nx_eot_flag;
        end if;
    end process;

    --! output assignment
    hash      <= hash_flag;
    decrypt   <= decrypt_flag;
    cmd       <= pdi_data;
    pdi_ready <= pdi_ready_internal;
    sdi_ready <= sdi_ready_internal;

    pdi_fire <= pdi_valid = '1' and pdi_ready_internal = '1';
    sdi_fire <= sdi_valid = '1' and sdi_ready_internal = '1';

    bdi_eoi_internal <= eoi_flag and last_flit_of_segment;
    bdi_eot_internal <= eot_flag and last_flit_of_segment;

    opcode_is_actkey     <= pdi_opcode = INST_ACTKEY;
    opcode_is_hash       <= pdi_opcode = INST_HASH;
    opcode_is_enc_or_dec <= pdi_opcode(3 downto 1) = INST_ENC(3 downto 1);

    -- ====================================================================================================
    --! 32 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_32BIT : if (W = 32) generate

        --! 32 Bit specific declarations
        signal nx_state, pr_state : t_state32;

        ---ALIAS
        alias pdi_seg_length : std_logic_vector(15 downto 0) is pdi_data(15 downto 0);
        alias sdi_seg_length : std_logic_vector(15 downto 0) is sdi_data(15 downto 0);

    begin

        --! Multiplexer
        load_SegLenCnt <= sdi_seg_length when sel_sdi_length else pdi_seg_length;

        --set size: internally we deal with 32 bits only
        bdi_size_p <= dout_SegLenCnt(2 downto 0) when last_flit_of_segment = '1' else "100";

        --! KEY PISO
        -- for ccsw > SW: a piso is used for width conversion
        keyPISO : entity work.KEY_PISO(behavioral)
            port map(
                clk          => clk,
                rst          => rst,
                data_s       => key,
                data_valid_s => key_valid,
                data_ready_s => key_ready,
                data_p       => sdi_data,
                data_valid_p => key_valid_p,
                data_ready_p => key_ready_p
            );

        --! DATA PISO
        -- for ccw > W: a piso is used for width conversion
        bdiPISO : entity work.DATA_PISO(behavioral)
            port map(
                clk           => clk,
                rst           => rst,
                data_size_p   => bdi_size_p,
                data_size_s   => bdi_size,
                data_s        => bdi,
                data_valid_s  => bdi_valid,
                data_ready_s  => bdi_ready,
                data_p        => pdi_data,
                data_valid_p  => bdi_valid_p,
                data_ready_p  => bdi_ready_p,
                valid_bytes_p => bdi_valid_bytes_p,
                valid_bytes_s => bdi_valid_bytes,
                pad_loc_p     => bdi_pad_loc_p,
                pad_loc_s     => bdi_pad_loc,
                eoi_p         => bdi_eoi_internal,
                eoi_s         => bdi_eoi,
                eot_p         => bdi_eot_internal,
                eot_s         => bdi_eot
            );

        --! State register
        GEN_proc_SYNC_RST : if (not ASYNC_RSTN) generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        pr_state <= S_INST;
                    else
                        pr_state <= nx_state;
                    end if;
                end if;
            end process;
        end generate GEN_proc_SYNC_RST;
        GEN_proc_ASYNC_RSTN : if (ASYNC_RSTN) generate
            process(clk, rst)
            begin
                if rst = '0' then
                    pr_state <= S_INST;
                elsif rising_edge(clk) then
                    pr_state <= nx_state;
                end if;
            end process;
        end generate GEN_proc_ASYNC_RSTN;

        --! next state function
        -- VHDL 2008+ --
        -- process(all)
        process(pr_state, last_flit_of_segment, decrypt_flag, key_ready_p, --
            bdi_ready_p, eot_flag, pdi_seg_length, sdi_opcode, cmd_ready, pdi_fire, --
            sdi_fire, sdi_valid, pdi_valid, eoi_flag, hash_flag, pdi_opcode, opcode_is_actkey, opcode_is_enc_or_dec, opcode_is_hash)
        begin
            -- DEFAULT Values
            -- external interface
            sdi_ready_internal    <= '0';
            pdi_ready_internal    <= '0';
            -- LWC core
            key_valid_p           <= '0';
            key_update            <= '0';
            bdi_valid_p           <= '0';
            bdi_type              <= "0000";
            -- header-FIFO
            cmd_valid             <= '0';
            -- multiplexer
            sel_sdi_length        <= false;
            -- counter
            ld_en_SegLenCnt       <= '0';
            dec_seglen_ctr        <= '0';
            -- register
            nx_eoi_flag           <= eoi_flag;
            nx_eot_flag           <= eot_flag;
            nx_hash_flag          <= hash_flag;
            nx_decrypt_flag       <= decrypt_flag;
            nx_state              <= pr_state;
            -- for simulation only
            received_wrong_header <= false;

            --We don't allow for parallel key loading in a lightweight enviroment
            -- TODO implement, at least as an option. The overhead should be negligable -- kamyar

            case pr_state is
                -- receive PDI instruction
                when S_INST =>
                    cmd_valid          <= pdi_valid and not to_std_logic(opcode_is_actkey);
                    pdi_ready_internal <= cmd_ready or to_std_logic(opcode_is_actkey);

                    if pdi_fire then
                        if opcode_is_actkey then
                            nx_hash_flag <= '0';
                            nx_state     <= S_INST_KEY;
                        elsif opcode_is_enc_or_dec then
                            nx_decrypt_flag <= pdi_opcode(0);
                            nx_hash_flag    <= '0';
                            if G_OFFLINE then
                                nx_state <= S_HDR_LENGTH;
                            else
                                nx_state <= S_HDR_NPUB;
                            end if;
                        else
                            received_wrong_header <= not opcode_is_hash;
                            nx_hash_flag          <= '1';
                            nx_state              <= S_HDR_HASH;
                        end if;
                    end if;

                -- receive SDI instruction
                when S_INST_KEY =>
                    sdi_ready_internal <= '1';
                    key_update         <= '0';
                    if sdi_fire then
                        received_wrong_header <= sdi_opcode /= INST_LDKEY;
                        nx_state              <= S_HDR_KEY;
                    end if;

                -- receive key header from SDI
                when S_HDR_KEY =>
                    sdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= sdi_valid;
                    sel_sdi_length     <= true;
                    if sdi_fire then
                        received_wrong_header <= sdi_opcode /= HDR_KEY;
                        nx_state              <= S_LD_KEY;
                    end if;

                -- receive key data from SDI
                when S_LD_KEY =>
                    sdi_ready_internal <= key_ready_p;
                    key_valid_p        <= sdi_valid;
                    key_update         <= '1';
                    if sdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_INST;
                        end if;
                    end if;

                when S_HDR_LENGTH =>
                    pdi_ready_internal <= '1';
                    if pdi_fire then
                        ld_en_SegLenCnt       <= '1';
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        received_wrong_header <= pdi_opcode /= HDR_LENGTH;
                        nx_state              <= S_LD_LENGTH;
                    end if;

                when S_LD_LENGTH =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_valid_p        <= pdi_valid;
                    bdi_type           <= HDR_LENGTH;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_HDR_NPUB;
                        end if;
                    end if;

                -- NPUB
                when S_HDR_NPUB =>
                    pdi_ready_internal <= '1';
                    if pdi_fire then
                        ld_en_SegLenCnt       <= '1';
                        received_wrong_header <= pdi_opcode /= HDR_NPUB;
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        nx_state              <= S_LD_NPUB;
                    end if;

                when S_LD_NPUB =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_valid_p        <= pdi_valid;
                    bdi_type           <= HDR_NPUB;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_HDR_AD;
                        end if;
                    end if;

                -- AD
                when S_HDR_AD =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if pdi_fire then
                        received_wrong_header <= pdi_opcode /= HDR_AD;
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        if pdi_seg_length = x"0000" then
                            if pdi_cmd_eoi = '1' then
                                if decrypt_flag = '1' then
                                    nx_state <= S_HDR_TAG;
                                else
                                    nx_state <= S_INST;
                                end if;
                            else
                                nx_state <= S_HDR_MSG;
                            end if;
                        else
                            nx_state <= S_LD_AD;
                        end if;
                    end if;

                when S_LD_AD =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_valid_p        <= pdi_valid;
                    bdi_type           <= HDR_AD;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready_p;

                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            if eot_flag = '1' then
                                nx_state <= S_HDR_MSG;
                            else
                                nx_state <= S_HDR_AD;
                            end if;
                        end if;
                    end if;

                -- Plaintext or Ciphertext
                when S_HDR_MSG =>
                    pdi_ready_internal <= cmd_ready;
                    cmd_valid          <= pdi_valid;
                    if pdi_fire then
                        received_wrong_header <= pdi_opcode /= HDR_PT and pdi_opcode /= HDR_CT;
                        ld_en_SegLenCnt       <= '1';
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        if pdi_seg_length = x"0000" and eot_flag = '1' then
                            if decrypt_flag = '1' then
                                nx_state <= S_HDR_TAG;
                            else
                                nx_state <= S_INST;
                            end if;
                        else
                            nx_state <= S_LD_MSG;
                        end if;
                    end if;

                when S_LD_MSG =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_valid_p        <= pdi_valid;
                    if decrypt_flag = '1' then
                        bdi_type <= HDR_CT;
                    else
                        bdi_type <= HDR_PT;
                    end if;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            if eot_flag = '1' then
                                if decrypt_flag = '1' then
                                    nx_state <= S_HDR_TAG;
                                else
                                    nx_state <= S_INST;
                                end if;
                            else
                                nx_state <= S_HDR_MSG;
                            end if;
                        end if;
                    end if;

                -- TAG for AEAD
                when S_HDR_TAG =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if pdi_fire then
                        received_wrong_header <= pdi_opcode /= HDR_TAG;
                        nx_state              <= S_LD_TAG;
                    end if;

                when S_LD_TAG =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_type           <= HDR_TAG;
                    bdi_valid_p        <= pdi_valid;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_INST;
                        end if;
                    end if;

                --HASH
                when S_HDR_HASH =>
                    pdi_ready_internal <= '1';
                    if pdi_fire then
                        received_wrong_header <= pdi_opcode /= HDR_HASH_MSG;
                        ld_en_SegLenCnt       <= '1';
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        if pdi_seg_length = x"0000" then
                            nx_state <= S_EMPTY_HASH;
                        else
                            nx_state <= S_LD_HASH;
                        end if;
                    end if;

                when S_EMPTY_HASH =>
                    bdi_valid_p <= '1';
                    bdi_type    <= HDR_HASH_MSG;
                    if bdi_ready_p = '1' then
                        nx_state <= S_INST;
                    end if;

                when S_LD_HASH =>
                    pdi_ready_internal <= bdi_ready_p;
                    bdi_valid_p        <= pdi_valid;
                    bdi_type           <= HDR_HASH_MSG;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready_p;
                    if pdi_fire and last_flit_of_segment = '1' then
                        if eot_flag = '1' then
                            nx_state <= S_INST;
                        else
                            nx_state <= S_HDR_HASH;
                        end if;
                    end if;

            end case;
        end process;

    end generate;

    -- ====================================================================================================
    --! 16 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_16BIT : if (W = 16) generate

        --! 16 Bit specific declarations
        signal bdi_size_not_last  : std_logic_vector(2 downto 0);
        --Registers
        signal nx_state, pr_state : t_state16;

        alias pdi_seg_length : std_logic_vector(15 downto 0) is pdi_data(15 downto 0);
        alias sdi_seg_length : std_logic_vector(15 downto 0) is sdi_data(15 downto 0);

    begin

        --! Logics
        bdi_size <= dout_SegLenCnt(2 downto 0) when last_flit_of_segment = '1' else bdi_size_not_last;

        with (W / 8) select bdi_size_not_last <=
            "100" when 4,
            "010" when 2,
            "001" when 1,
            "000" when others;

        bdi_pad_loc     <= bdi_pad_loc_p(3 downto 4 - CCWdiv8);
        bdi_valid_bytes <= bdi_valid_bytes_p(3 downto 4 - CCWdiv8);
        load_SegLenCnt  <= sdi_seg_length when sel_sdi_length else pdi_seg_length;

        bdi_eoi <= bdi_eoi_internal;
        bdi_eot <= bdi_eot_internal;

        --! Assigning Data to buses
        bdi <= pdi_data(CCW - 1 downto 0);
        key <= sdi_data(CCSW - 1 downto 0);

        --! State register
        GEN_proc_SYNC_RST : if (not ASYNC_RSTN) generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if (rst = '1') then
                        pr_state <= S_INST;
                    else
                        pr_state <= nx_state;
                    end if;
                end if;
            end process;
        end generate GEN_proc_SYNC_RST;
        GEN_proc_ASYNC_RSTN : if (ASYNC_RSTN) generate
            process(clk, rst)
            begin
                if (rst = '0') then
                    pr_state <= S_INST;
                elsif rising_edge(clk) then
                    pr_state <= nx_state;
                end if;
            end process;
        end generate GEN_proc_ASYNC_RSTN;

        --!next state function
        process(pr_state, sdi_valid, sdi_fire, pdi_valid, sdi_data, pdi_data, pdi_fire, last_flit_of_segment, decrypt_flag, key_ready, --
            bdi_ready, cmd_ready, eot_flag, hash_flag, eoi_flag, opcode_is_actkey, opcode_is_enc_or_dec, opcode_is_hash)
        begin
            --DEFAULT Values
            --external interface
            sdi_ready_internal    <= '0';
            pdi_ready_internal    <= '0';
            -- CryptoCore
            key_valid             <= '0';
            bdi_valid             <= '0';
            bdi_type              <= "0000";
            key_update            <= '0';
            -- Header-FIFO
            cmd_valid             <= '0';
            -- Multiplexer
            sel_sdi_length        <= false;
            -- Segment counter
            ld_en_SegLenCnt       <= '0';
            dec_seglen_ctr        <= '0';
            -- Registers default feedback
            nx_hash_flag          <= hash_flag;
            nx_decrypt_flag       <= decrypt_flag;
            nx_eoi_flag           <= eoi_flag;
            nx_eot_flag           <= eot_flag;
            nx_state              <= pr_state;
            -- for simulation only
            received_wrong_header <= false;

            case pr_state is

                -- receive PDI instruction
                when S_INST =>
                    cmd_valid          <= pdi_valid and not to_std_logic(opcode_is_actkey);
                    pdi_ready_internal <= cmd_ready or to_std_logic(opcode_is_actkey);

                    if pdi_fire then
                        if opcode_is_actkey then
                            nx_hash_flag <= '0';
                            nx_state     <= S_INST_KEY;
                        elsif opcode_is_enc_or_dec then
                            nx_decrypt_flag <= pdi_opcode(0);
                            nx_hash_flag    <= '0';
                            if G_OFFLINE then
                                nx_state <= S_HDR_LENGTH;
                            else
                                nx_state <= S_HDR_NPUB;
                            end if;
                        else
                            received_wrong_header <= not opcode_is_hash;
                            nx_hash_flag          <= '1';
                            nx_state              <= S_HDR_HASH;
                        end if;
                    end if;

                -- receive key instruction from SDI
                when S_INST_KEY =>
                    sdi_ready_internal <= '1';
                    key_update         <= '0';
                    if sdi_fire then
                        received_wrong_header <= sdi_opcode /= INST_LDKEY;
                        nx_state              <= S_HDR_KEY;
                    end if;

                -- receive key header from SDI #1
                when S_HDR_KEY =>
                    sdi_ready_internal <= '1';
                    if sdi_fire then
                        received_wrong_header <= sdi_opcode /= HDR_KEY;
                        nx_state              <= S_HDR_KEYLEN;
                    end if;

                -- receive key header from SDI #2
                when S_HDR_KEYLEN =>
                    sdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= sdi_valid;
                    sel_sdi_length     <= true;
                    if sdi_fire then
                        nx_state <= S_LD_KEY;
                    end if;

                -- receive key data from SDI
                when S_LD_KEY =>
                    sdi_ready_internal <= key_ready;
                    key_valid          <= sdi_valid;
                    key_update         <= '1';
                    dec_seglen_ctr     <= sdi_valid and key_ready;
                    if sdi_fire and last_flit_of_segment = '1' then
                        nx_state <= S_INST;
                    end if;

                when S_HDR_LENGTH =>
                    pdi_ready_internal <= '1';
                    if pdi_fire then
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        received_wrong_header <= pdi_opcode /= HDR_LENGTH;
                        nx_state              <= S_HDR_LENGTH_LEN;
                    end if;

                when S_HDR_LENGTH_LEN =>
                    pdi_ready_internal <= '1';
                    if pdi_fire then
                        ld_en_SegLenCnt <= '1';
                        nx_eoi_flag     <= pdi_cmd_eoi;
                        nx_eot_flag     <= pdi_cmd_eot;
                        nx_state        <= S_LD_LENGTH;
                    end if;

                when S_LD_LENGTH =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_LENGTH;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_HDR_NPUB;
                        end if;
                    end if;

                ---NPUB
                when S_HDR_NPUB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if pdi_valid = '1' then
                        received_wrong_header <= pdi_opcode /= HDR_NPUB;
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        nx_state              <= S_HDR_NPUBLEN; -- *16
                    end if;

                when S_HDR_NPUBLEN =>
                    pdi_ready_internal <= '1';
                    if pdi_valid = '1' then
                        ld_en_SegLenCnt <= '1';
                        nx_state        <= S_LD_NPUB;
                    end if;

                when S_LD_NPUB =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_NPUB;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_HDR_AD;
                        end if;
                    end if;

                --AD
                when S_HDR_AD =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if pdi_valid = '1' then
                        received_wrong_header <= pdi_opcode /= HDR_AD;
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        nx_state              <= S_HDR_ADLEN;
                    end if;

                when S_HDR_ADLEN =>
                    pdi_ready_internal <= '1';
                    if pdi_valid = '1' then
                        ld_en_SegLenCnt <= '1';
                        if pdi_seg_length = x"0000" then
                            if pdi_cmd_eoi = '1' then
                                if decrypt_flag = '1' then
                                    nx_state <= S_HDR_TAG;
                                else
                                    nx_state <= S_INST;
                                end if;
                            else
                                nx_state <= S_HDR_MSG;
                            end if;
                        else
                            nx_state <= S_LD_AD;
                        end if;
                    end if;

                when S_LD_AD =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_AD;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            if eot_flag = '1' then
                                nx_state <= S_HDR_MSG;
                            else
                                nx_state <= S_HDR_AD;
                            end if;
                        end if;
                    end if;

                -- Plaintext or Ciphertext
                when S_HDR_MSG =>
                    pdi_ready_internal <= cmd_ready;
                    cmd_valid          <= pdi_valid;
                    if pdi_fire then
                        received_wrong_header <= pdi_opcode /= HDR_PT and pdi_opcode /= HDR_CT;
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        nx_state              <= S_HDR_MSGLEN;
                    end if;

                when S_HDR_MSGLEN =>
                    pdi_ready_internal <= cmd_ready;
                    cmd_valid          <= pdi_valid;

                    if pdi_fire then
                        ld_en_SegLenCnt <= '1';
                        if (pdi_data = zero_data and eot_flag = '1') then
                            if (decrypt_flag = '1') then
                                nx_state <= S_HDR_TAG;
                            else
                                nx_state <= S_INST;
                            end if;
                        else
                            nx_state <= S_LD_MSG;
                        end if;
                    end if;

                when S_LD_MSG =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    if (decrypt_flag = '1') then
                        bdi_type <= HDR_CT;
                    else
                        bdi_type <= HDR_PT;
                    end if;

                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            if eot_flag = '1' then
                                if decrypt_flag = '1' then
                                    nx_state <= S_HDR_TAG;
                                else
                                    nx_state <= S_INST;
                                end if;
                            else
                                nx_state <= S_HDR_MSG;
                            end if;
                        end if;
                    end if;

                --TAG
                when S_HDR_TAG =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                    if pdi_valid = '1' then
                        received_wrong_header <= pdi_opcode /= HDR_TAG;
                        nx_state              <= S_HDR_TAGLEN;
                    end if;

                when S_HDR_TAGLEN =>
                    pdi_ready_internal <= '1';
                    if pdi_valid = '1' then
                        ld_en_SegLenCnt <= '1';
                        nx_state        <= S_LD_TAG;
                    end if;

                when S_LD_TAG =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_TAG;

                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            nx_state <= S_INST;
                        end if;
                    end if;

                --HASH
                when S_HDR_HASH =>
                    pdi_ready_internal <= '1';
                    if pdi_valid = '1' then
                        received_wrong_header <= pdi_opcode /= HDR_HASH_MSG;
                        ld_en_SegLenCnt       <= '1';
                        nx_eoi_flag           <= pdi_cmd_eoi;
                        nx_eot_flag           <= pdi_cmd_eot;
                        nx_state              <= S_HDR_HASHLEN;
                    end if;

                when S_HDR_HASHLEN =>
                    pdi_ready_internal <= '1';
                    if pdi_valid = '1' then
                        ld_en_SegLenCnt <= '1';
                        if pdi_seg_length = x"0000" then
                            nx_state <= S_EMPTY_HASH;
                        else
                            nx_state <= S_LD_HASH;
                        end if;
                    end if;

                when S_EMPTY_HASH =>
                    bdi_valid <= '1';
                    bdi_type  <= HDR_HASH_MSG;
                    if bdi_ready = '1' then
                        nx_state <= S_INST;
                    end if;

                when S_LD_HASH =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_HASH_MSG;
                    if pdi_fire then
                        dec_seglen_ctr <= '1';
                        if last_flit_of_segment = '1' then
                            if (eot_flag = '1') then
                                nx_state <= S_INST;
                            else
                                nx_state <= S_HDR_HASH;
                            end if;
                        end if;
                    end if;

            end case;
        end process;

    end generate;

    -- ====================================================================================================
    --! 08 bit specific FSM -------------------------------------------------------------------------------
    -- ====================================================================================================

    FSM_8BIT : if (W = 8) generate
        --! 8 Bit specific declarations
        signal nx_state, pr_state          : t_state8;
        signal bdi_size_not_last           : std_logic_vector(2 downto 0);
        -- Registers
        signal data_seg_length             : std_logic_vector(7 downto 0);
        signal dout_LenReg, nx_dout_LenReg : std_logic_vector(7 downto 0);

    begin

        --! Logics
        data_seg_length <= sdi_data(7 downto 0) when sel_sdi_length else pdi_data(7 downto 0);
        load_SegLenCnt  <= dout_LenReg & data_seg_length;
        bdi_size        <= dout_SegLenCnt(2 downto 0) when last_flit_of_segment = '1' else bdi_size_not_last;

        with (W / 8) select bdi_size_not_last <=
            "100" when 4,
            "010" when 2,
            "001" when 1,
            "000" when others;

        bdi_pad_loc((W / 8) - 1 downto 0) <= bdi_pad_loc_p(3 downto 4 - (W / 8));

        bdi_valid_bytes((W / 8) - 1 downto 0) <= bdi_valid_bytes_p(3 downto 4 - (W / 8));

        bdi_eoi <= bdi_eoi_internal;
        bdi_eot <= bdi_eot_internal;

        ---!Assigning Data to buses
        bdi <= pdi_data;
        key <= sdi_data;

        --! Length register
        LenReg : process(clk)
        begin
            if rising_edge(clk) then
                dout_LenReg <= nx_dout_LenReg;
            end if;
        end process;

        --! State register
        GEN_proc_SYNC_RST : if not ASYNC_RSTN generate
            process(clk)
            begin
                if rising_edge(clk) then
                    if rst = '1' then
                        pr_state <= S_INST;
                    else
                        pr_state <= nx_state;
                    end if;
                end if;
            end process;
        end generate GEN_proc_SYNC_RST;
        GEN_proc_ASYNC_RSTN : if ASYNC_RSTN generate
            process(clk, rst)
            begin
                if rst = '0' then
                    pr_state <= S_INST;
                elsif rising_edge(clk) then
                    pr_state <= nx_state;
                end if;
            end process;
        end generate GEN_proc_ASYNC_RSTN;

        --!next state function
        process(pr_state, sdi_valid, pdi_valid, sdi_data, pdi_data, last_flit_of_segment, decrypt_flag, --
            key_ready, bdi_ready, cmd_ready, dout_LenReg, bdi_eoi_internal, eot_flag)
        begin
            nx_state <= pr_state;

            case pr_state is

                ---MODE SET
                when S_INST =>
                    if (pdi_valid = '1') then
                        if (pdi_opcode = INST_ACTKEY) then
                            nx_state <= S_INST_KEY;
                        elsif (pdi_opcode(3 downto 1) = INST_ENC(3 downto 1)) and (cmd_ready = '1') then
                            nx_state <= S_HDR_NPUB;
                        elsif (pdi_opcode = INST_HASH and cmd_ready = '1') then
                            nx_state <= S_HDR_HASH;
                        else
                            nx_state <= S_INST;
                        end if;
                    end if;

                ---load key
                when S_INST_KEY =>
                    if (sdi_valid = '1' and sdi_data(W - 1 downto W - 4) = INST_LDKEY) then
                        nx_state <= S_HDR_KEY;
                    end if;

                when S_HDR_KEY =>
                    if (sdi_valid = '1' and sdi_data(W - 1 downto W - 4) = HDR_KEY) then
                        nx_state <= S_HDR_RESKEY;
                    end if;

                when S_HDR_RESKEY =>
                    if (sdi_valid = '1') then
                        nx_state <= S_HDR_KEYLEN_MSB;
                    end if;

                when S_HDR_KEYLEN_MSB =>
                    if (sdi_valid = '1') then
                        nx_state <= S_HDR_KEYLEN_LSB;
                    end if;

                when S_HDR_KEYLEN_LSB =>
                    if (sdi_valid = '1') then
                        nx_state <= S_LD_KEY;
                    end if;

                when S_LD_KEY =>
                    if (sdi_valid = '1' and key_ready = '1' and last_flit_of_segment = '1') then
                        nx_state <= S_INST;
                    end if;

                ---NPUB
                when S_HDR_NPUB =>
                    if (pdi_valid = '1' and pdi_opcode = HDR_NPUB) then
                        nx_state <= S_HDR_RESNPUB;
                    end if;

                when S_HDR_RESNPUB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_NPUBLEN_MSB;
                    end if;

                when S_HDR_NPUBLEN_MSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_NPUBLEN_LSB;
                    end if;

                when S_HDR_NPUBLEN_LSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_LD_NPUB;
                    end if;

                when S_LD_NPUB =>
                    if (pdi_valid = '1' and bdi_ready = '1' and last_flit_of_segment = '1') then
                        nx_state <= S_HDR_AD;
                    end if;

                --AD
                when S_HDR_AD =>
                    if (pdi_valid = '1' and pdi_opcode = HDR_AD) then
                        nx_state <= S_HDR_RESAD;
                    end if;

                when S_HDR_RESAD =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_ADLEN_MSB;
                    end if;

                when S_HDR_ADLEN_MSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_ADLEN_LSB;
                    end if;

                when S_HDR_ADLEN_LSB =>
                    if (pdi_valid = '1') then
                        if (dout_LenReg = x"00" and pdi_data(7 downto 0) = x"00" and eot_flag = '1') then
                            if (bdi_eoi_internal = '1') then
                                if (decrypt_flag = '1') then
                                    nx_state <= S_INST;
                                else
                                    nx_state <= S_HDR_TAG;
                                end if;
                            else
                                nx_state <= S_HDR_MSG;
                            end if;
                        else
                            nx_state <= S_LD_AD;
                        end if;
                    end if;

                when S_LD_AD =>
                    if (pdi_valid = '1' and bdi_ready = '1' and last_flit_of_segment = '1') then
                        if (eot_flag = '1') then --eot
                            nx_state <= S_HDR_MSG;
                        else
                            nx_state <= S_HDR_AD;
                        end if;
                    end if;

                --MSG OR CIPHER TEXT
                when S_HDR_MSG =>
                    if (pdi_valid = '1' and cmd_ready = '1' and (pdi_opcode = HDR_PT or pdi_opcode = HDR_CT)) then
                        nx_state <= S_HDR_RESMSG;
                    end if;

                when S_HDR_RESMSG =>
                    if (pdi_valid = '1' and cmd_ready = '1') then
                        nx_state <= S_HDR_MSGLEN_MSB;
                    end if;

                when S_HDR_MSGLEN_MSB =>
                    if (pdi_valid = '1' and cmd_ready = '1') then
                        nx_state <= S_HDR_MSGLEN_LSB;
                    end if;

                when S_HDR_MSGLEN_LSB =>
                    if (pdi_valid = '1' and cmd_ready = '1') then
                        if (dout_LenReg = x"00" and pdi_data(7 downto 0) = x"00" and eot_flag = '1') then
                            if (decrypt_flag = '1') then
                                nx_state <= S_HDR_TAG;
                            else
                                nx_state <= S_INST;
                            end if;
                        else
                            nx_state <= S_LD_MSG;
                        end if;
                    end if;

                when S_LD_MSG =>
                    if (pdi_valid = '1' and bdi_ready = '1' and last_flit_of_segment = '1') then
                        if (eot_flag = '1') then
                            if (decrypt_flag = '1') then
                                nx_state <= S_HDR_TAG;
                            else
                                nx_state <= S_INST;
                            end if;
                        else
                            nx_state <= S_HDR_MSG;
                        end if;
                    end if;

                --TAG
                when S_HDR_TAG =>
                    if (pdi_valid = '1' and pdi_opcode = HDR_TAG) then
                        nx_state <= S_HDR_RESTAG;
                    end if;

                when S_HDR_RESTAG =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_TAGLEN_MSB;
                    end if;

                when S_HDR_TAGLEN_MSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_TAGLEN_LSB;
                    end if;

                when S_HDR_TAGLEN_LSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_LD_TAG;
                    end if;

                when S_LD_TAG =>
                    if (pdi_valid = '1' and last_flit_of_segment = '1') then
                        if (bdi_ready = '1') then
                            nx_state <= S_INST;
                        else
                            nx_state <= S_LD_TAG;
                        end if;
                    end if;

                --HASH
                when S_HDR_HASH =>
                    if (pdi_valid = '1' and pdi_opcode(3 downto 1) = HDR_HASH_MSG(3 downto 1)) then
                        nx_state <= S_HDR_RESHASH;
                    end if;

                when S_HDR_RESHASH =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_HASHLEN_MSB;
                    end if;

                when S_HDR_HASHLEN_MSB =>
                    if (pdi_valid = '1') then
                        nx_state <= S_HDR_HASHLEN_LSB;
                    end if;

                when S_HDR_HASHLEN_LSB =>
                    if (pdi_valid = '1') then
                        if (dout_LenReg = x"00" and pdi_data(7 downto 0) = x"00") then
                            nx_state <= S_EMPTY_HASH;
                        else
                            nx_state <= S_LD_HASH;
                        end if;
                    end if;

                when S_EMPTY_HASH =>
                    if (bdi_ready = '1') then
                        nx_state <= S_INST;
                    end if;

                when S_LD_HASH =>
                    if (pdi_valid = '1' and bdi_ready = '1' and last_flit_of_segment = '1') then
                        if (eot_flag = '1') then
                            nx_state <= S_INST;
                        else
                            nx_state <= S_HDR_HASH;
                        end if;
                    end if;

            end case;
        end process;

        --!output state function
        -- process(all)
        process(pr_state, sdi_valid, pdi_valid, key_ready, bdi_ready, cmd_ready, pdi_data, decrypt_flag, hash_flag, data_seg_length, dout_LenReg, eoi_flag, eot_flag)
        begin
            -- DEFAULT Values
            -- external interface
            sdi_ready_internal <= '0';
            pdi_ready_internal <= '0';
            -- CryptoCore
            key_valid          <= '0';
            key_update         <= '0';
            bdi_valid          <= '0';
            bdi_type           <= "0000";
            -- Header-FIFO
            cmd_valid          <= '0';
            -- segment counter
            ld_en_SegLenCnt    <= '0';
            dec_seglen_ctr     <= '0';
            --Register
            nx_hash_flag       <= hash_flag;
            nx_decrypt_flag    <= decrypt_flag;
            nx_dout_LenReg     <= dout_LenReg;
            nx_eoi_flag        <= eoi_flag;
            nx_eot_flag        <= eot_flag;
            -- Multiplexer
            sel_sdi_length     <= false;

            case pr_state is

                ---MODE
                when S_INST =>
                    nx_hash_flag <= '0';
                    if (pdi_opcode(3 downto 1) = INST_ENC(3 downto 1)) then
                        if (pdi_valid = '1') then
                            nx_decrypt_flag <= pdi_data(W - 4);
                        end if;
                        cmd_valid          <= pdi_valid;
                        pdi_ready_internal <= cmd_ready;
                        nx_hash_flag       <= '0';
                    elsif (pdi_opcode = INST_ACTKEY) then
                        pdi_ready_internal <= '1';
                        nx_hash_flag       <= '0';
                    elsif (pdi_opcode = INST_HASH) then
                        nx_hash_flag       <= '1';
                        if (pdi_valid = '1') then
                            nx_decrypt_flag <= pdi_data(W - 4);
                        end if;
                        cmd_valid          <= pdi_valid;
                        pdi_ready_internal <= cmd_ready;
                    end if;

                when S_INST_KEY =>
                    sdi_ready_internal <= '1';
                    key_update         <= '0';

                when S_HDR_KEY =>
                    sdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= sdi_valid;
                    sel_sdi_length     <= true;
                    if (sdi_valid = '1') then
                        nx_eoi_flag <= pdi_cmd_eoi;
                        nx_eot_flag <= pdi_cmd_eot;
                    end if;

                when S_HDR_RESKEY =>
                    sdi_ready_internal <= '1';
                    sel_sdi_length     <= true;

                when S_HDR_KEYLEN_MSB =>
                    sdi_ready_internal <= '1';
                    sel_sdi_length     <= true;
                    if (sdi_valid = '1') then
                        nx_dout_LenReg <= data_seg_length;
                    end if;

                when S_HDR_KEYLEN_LSB =>
                    sdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= sdi_valid;
                    sel_sdi_length     <= true;

                when S_LD_KEY =>
                    sdi_ready_internal <= key_ready;
                    key_valid          <= sdi_valid;
                    key_update         <= '1';
                    dec_seglen_ctr     <= sdi_valid and key_ready;

                ---NPUB
                when S_HDR_NPUB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if (pdi_valid = '1') then
                        nx_eoi_flag <= pdi_cmd_eoi;
                        nx_eot_flag <= pdi_cmd_eot;
                    end if;

                when S_HDR_RESNPUB =>
                    pdi_ready_internal <= '1';

                when S_HDR_NPUBLEN_MSB =>
                    pdi_ready_internal <= '1';
                    if (pdi_valid = '1') then
                        nx_dout_LenReg <= data_seg_length;
                    end if;

                when S_HDR_NPUBLEN_LSB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                when S_LD_NPUB =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_NPUB;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready;

                ---AD
                when S_HDR_AD =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if (pdi_valid = '1') then
                        nx_eoi_flag <= pdi_cmd_eoi;
                        nx_eot_flag <= pdi_cmd_eot;
                    end if;

                when S_HDR_RESAD =>
                    pdi_ready_internal <= '1';

                when S_HDR_ADLEN_MSB =>
                    pdi_ready_internal <= '1';
                    if (pdi_valid = '1') then
                        nx_dout_LenReg <= data_seg_length;
                    end if;

                when S_HDR_ADLEN_LSB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                when S_LD_AD =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_AD;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready;

                --MSG
                when S_HDR_MSG =>
                    if (pdi_opcode = HDR_PT or pdi_opcode = HDR_CT) then
                        cmd_valid <= pdi_valid;
                    end if;
                    pdi_ready_internal <= cmd_ready;
                    ld_en_SegLenCnt    <= pdi_valid and cmd_ready;
                    if ((pdi_valid = '1') and (cmd_ready = '1')) then
                        nx_eoi_flag <= pdi_cmd_eoi;
                        nx_eot_flag <= pdi_cmd_eot;
                    end if;

                when S_HDR_RESMSG =>
                    pdi_ready_internal <= cmd_ready;
                    cmd_valid          <= pdi_valid;

                when S_HDR_MSGLEN_MSB =>
                    pdi_ready_internal <= cmd_ready;
                    if ((pdi_valid = '1') and (cmd_ready = '1')) then
                        nx_dout_LenReg <= data_seg_length;
                    end if;
                    cmd_valid          <= pdi_valid;

                when S_HDR_MSGLEN_LSB =>
                    pdi_ready_internal <= cmd_ready;
                    ld_en_SegLenCnt    <= pdi_valid and cmd_ready;
                    cmd_valid          <= pdi_valid;

                when S_LD_MSG =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    if (decrypt_flag = '1') then
                        bdi_type <= HDR_CT;
                    else
                        bdi_type <= HDR_PT;
                    end if;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready;

                --HASH
                when S_HDR_HASH =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;
                    if (pdi_valid = '1') then
                        nx_eoi_flag <= pdi_cmd_eoi;
                        nx_eot_flag <= pdi_cmd_eot;
                    end if;

                when S_HDR_RESHASH =>
                    pdi_ready_internal <= '1';

                when S_HDR_HASHLEN_MSB =>
                    pdi_ready_internal <= '1';
                    if (pdi_valid = '1') then
                        nx_dout_LenReg <= data_seg_length;
                    end if;

                when S_HDR_HASHLEN_LSB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                when S_EMPTY_HASH =>
                    bdi_valid <= '1';
                    bdi_type  <= HDR_HASH_MSG;

                when S_LD_HASH =>
                    pdi_ready_internal <= bdi_ready;
                    bdi_valid          <= pdi_valid;
                    bdi_type           <= HDR_HASH_MSG;
                    dec_seglen_ctr     <= pdi_valid and bdi_ready;

                --TAG
                when S_HDR_TAG =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                when S_HDR_RESTAG =>
                    pdi_ready_internal <= '1';

                when S_HDR_TAGLEN_MSB =>
                    pdi_ready_internal <= '1';
                    if (pdi_valid = '1') then
                        nx_dout_LenReg <= data_seg_length;
                    end if;

                when S_HDR_TAGLEN_LSB =>
                    pdi_ready_internal <= '1';
                    ld_en_SegLenCnt    <= pdi_valid;

                when S_LD_TAG =>
                    bdi_type <= HDR_TAG;
                    if (decrypt_flag = '1') then
                        bdi_valid          <= pdi_valid;
                        pdi_ready_internal <= bdi_ready;
                        dec_seglen_ctr     <= pdi_valid and bdi_ready;
                    end if;

            end case;
        end process;

    end generate;

end PreProcessor;
