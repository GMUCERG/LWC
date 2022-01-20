--===============================================================================================--
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
--!
--! @author     Kamyar Mohajerani
--! @copyright  Copyright (c) 2022 Cryptographic Engineering Research Group
--!             ECE Department, George Mason University Fairfax, VA, U.S.A.
--!             All rights Reserved.
--!
--! @license    This project is released under the GNU Public License.
--!             The license and distribution terms for this file may be
--!             found in the file LICENSE in this distribution or at
--!             http://www.gnu.org/licenses/gpl-3.0.txt
--!
--! @note       This is publicly available encryption source code that falls
--!             under the License Exception TSU (Technology and software-
--!             unrestricted)
---------------------------------------------------------------------------------------------------
--! Description
--!
--!
--===============================================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;
use work.LWC_pkg.all;

entity PreProcessor is
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        --! Public Data input (pdi) ===========================================
        pdi_data        : in  STD_LOGIC_VECTOR(PDI_SHARES * W - 1 downto 0);
        pdi_valid       : in  std_logic;
        pdi_ready       : out std_logic;
        --! Secret Data input (sdi) ===========================================
        sdi_data        : in  STD_LOGIC_VECTOR(PDI_SHARES * SW - 1 downto 0);
        sdi_valid       : in  std_logic;
        sdi_ready       : out std_logic;
        --! Crypto Core =======================================================
        key_data        : out std_logic_vector(PDI_SHARES * CCSW - 1 downto 0);
        key_valid       : out std_logic;
        key_ready       : in  std_logic;
        --
        key_update      : out std_logic;
        --
        bdi_data        : out std_logic_vector(PDI_SHARES * CCW - 1 downto 0);
        bdi_valid_bytes : out std_logic_vector(CCW / 8 - 1 downto 0);
        bdi_pad_loc     : out std_logic_vector(CCW / 8 - 1 downto 0);
        bdi_size        : out std_logic_vector(2 downto 0);
        bdi_eot         : out std_logic;
        bdi_eoi         : out std_logic;
        bdi_type        : out std_logic_vector(3 downto 0);
        bdi_valid       : out std_logic;
        bdi_ready       : in  std_logic;
        --
        decrypt         : out std_logic;
        hash            : out std_logic;
        ---! Instruction/Header FIFO ==========================================
        cmd_data        : out std_logic_vector(W - 1 downto 0);
        cmd_valid       : out std_logic;
        cmd_ready       : in  std_logic
    );

end entity PreProcessor;

architecture PreProcessor of PreProcessor is
    --======================================== Constants ========================================--
    constant SEGLEN_BITS  : positive := 16;
    constant LOG2_W_DIV_8 : natural  := log2ceil(W / 8);
    constant HDR_LEN_BITS : positive := minimum(W, SEGLEN_BITS);
    constant W_S          : positive := PDI_SHARES * W;
    constant SW_S         : positive := SDI_SHARES * SW;
    constant CCW_S        : positive := PDI_SHARES * CCW;
    constant CCSW_S       : positive := SDI_SHARES * CCSW;

    --========================================== Types ==========================================--
    type t_state is (S_INST, S_INST_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_LENGTH, S_LD_LENGTH,
                     S_HDR_NPUB, S_LD_NPUB, S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG,
                     S_LD_TAG, S_HDR_HASH, S_LD_HASHMSG, S_EMPTY_HASH);

    --======================================= Registers =========================================--
    signal state                            : t_state; -- FSM state
    signal segment_counter                  : unsigned(SEGLEN_BITS - 1 downto 0);
    signal eoi_flag, eot_flag, decrypt_flag : std_logic; -- flags

    --========================================= Wires ===========================================--
    signal nx_decrypt_flag                            : std_logic;
    signal bdi_eoi_p, bdi_eot_p                       : std_logic;
    -- for reading 'out' ports in VHDL < 2008
    signal pdi_ready_o, sdi_ready_o                   : std_logic;
    signal bdi_valid_p, bdi_ready_p                   : std_logic;
    signal key_valid_p, key_ready_p                   : std_logic;
    signal bdi_size_p                                 : std_logic_vector(2 downto 0);
    signal bdi_pad_loc_p                              : std_logic_vector(W / 8 - 1 downto 0);
    signal op_is_actkey, op_is_hash, op_is_enc_or_dec : boolean;
    signal reset_hdr_counter, hdr_first, hdr_last     : boolean;
    signal reading_pdi_hdr, reading_pdi_data          : boolean;
    signal reading_sdi_hdr, reading_sdi_data          : boolean;
    signal pdi_fire, sdi_fire                         : boolean; -- fire = valid AND ready
    signal seglen                                     : std_logic_vector(SEGLEN_BITS - 1 downto 0);
    signal hdr_seglen                                 : std_logic_vector(HDR_LEN_BITS - 1 downto 0);
    signal seglen_is_zero                             : boolean;
    signal last_flit_of_segment                       : boolean;
    signal bdi_valid_bytes_p                          : std_logic_vector(W / 8 - 1 downto 0);
    signal nx_state                                   : t_state; -- next FSM state
    --! for simulation only
    signal received_wrong_header                      : boolean;

    --========================================= Aliases =========================================--
    alias pdi_hdr            : std_logic_vector(W - 1 downto 0) is pdi_data(W_S - 1 downto W_S - W);
    alias pdi_hdr_opcode     : std_logic_vector(3 downto 0) is pdi_hdr(W - 1 downto W - 4);
    alias pdi_hdr_eoi        : std_logic is pdi_hdr(W - 6);
    alias pdi_hdr_eot        : std_logic is pdi_hdr(W - 7);
    alias pdi_hdr_last       : std_logic is pdi_hdr(W - 8);
    alias pdi_hdr_seglen     : std_logic_vector(HDR_LEN_BITS - 1 downto 0) is pdi_hdr(HDR_LEN_BITS - 1 downto 0);
    alias sdi_hdr            : std_logic_vector(W - 1 downto 0) is sdi_data(W_S - 1 downto W_S - W);
    alias sdi_hdr_opcode     : std_logic_vector(3 downto 0) is sdi_hdr(W - 1 downto W - 4);
    alias sdi_hdr_seglen     : std_logic_vector(HDR_LEN_BITS - 1 downto 0) is sdi_hdr(HDR_LEN_BITS - 1 downto 0);
    alias segment_counter_hi : unsigned(SEGLEN_BITS - LOG2_W_DIV_8 - 1 downto 0) is segment_counter(SEGLEN_BITS - 1 downto LOG2_W_DIV_8);
    alias segment_counter_lo : unsigned(LOG2_W_DIV_8 - 1 downto 0) is segment_counter(LOG2_W_DIV_8 - 1 downto 0);

begin
    --======================================== Instances ========================================--
    keyPISO : entity work.KEY_PISO
        port map(
            clk          => clk,
            rst          => rst,
            -- PISO Input
            data_p       => sdi_data,
            data_valid_p => key_valid_p,
            data_ready_p => key_ready_p,
            -- PISO Output
            data_s       => key_data,
            data_valid_s => key_valid,
            data_ready_s => key_ready
        );

    bdiPISO : entity work.DATA_PISO
        port map(
            clk           => clk,
            rst           => rst,
            -- PISO Input
            data_p        => pdi_data,
            valid_bytes_p => bdi_valid_bytes_p,
            data_size_p   => bdi_size_p,
            pad_loc_p     => bdi_pad_loc_p,
            eot_p         => bdi_eot_p,
            eoi_p         => bdi_eoi_p,
            data_valid_p  => bdi_valid_p,
            data_ready_p  => bdi_ready_p,
            -- PISO Output
            data_s        => bdi_data,
            valid_bytes_s => bdi_valid_bytes,
            data_size_s   => bdi_size,
            pad_loc_s     => bdi_pad_loc,
            eot_s         => bdi_eot,
            eoi_s         => bdi_eoi,
            data_valid_s  => bdi_valid,
            data_ready_s  => bdi_ready
        );

    --===========================================================================================--
    --================================ Width-specific generation ================================--
    W32_GEN : if W = 32 generate
    begin
        hdr_first <= true;
        hdr_last  <= true;
    end generate;
    WNOT32_GEN : if W /= 32 generate
        --============================== Wires ==============================--
        signal hdr_counter : unsigned(log2ceil(32 / W) - 1 downto 0);
    begin
        process(clk)
        begin
            if rising_edge(clk) then
                if reset_hdr_counter then
                    hdr_counter <= (others => '0');
                elsif (reading_sdi_hdr and sdi_fire) or (reading_pdi_hdr and pdi_fire) then
                    hdr_counter <= hdr_counter + 1;
                end if;
            end if;
        end process;
        hdr_first <= hdr_counter = 0;
        hdr_last  <= hdr_counter = 32 / W - 1;
    end generate;
    --
    W8_GEN : if W = 8 generate
        --============================ Registers ============================--
        signal seglen_msb8 : std_logic_vector(7 downto 0);
    begin
        process(clk)
        begin
            if rising_edge(clk) then
                if sdi_fire or pdi_fire then
                    seglen_msb8 <= hdr_seglen(7 downto 0);
                end if;
            end if;
        end process;
        seglen <= seglen_msb8 & hdr_seglen(7 downto 0);
    end generate;
    WNOT8_GEN : if W /= 8 generate
        seglen <= hdr_seglen;
    end generate;

    --============================================================================================--
    --! State register is the only register that requires reset
    GEN_SYNC_RST : if not ASYNC_RSTN generate
        process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    state <= S_INST;
                else
                    state <= nx_state;
                end if;
            end if;
        end process;
    end generate GEN_SYNC_RST;
    GEN_ASYNC_RSTN : if ASYNC_RSTN generate
        process(clk, rst)
        begin
            if rst = '0' then
                state <= S_INST;
            elsif rising_edge(clk) then
                state <= nx_state;
            end if;
        end process;
    end generate GEN_ASYNC_RSTN;

    process(clk)
    begin
        if rising_edge(clk) then
            if hdr_last and ((reading_pdi_hdr and pdi_fire) or (reading_sdi_hdr and sdi_fire)) then
                segment_counter <= unsigned(seglen);
            elsif (reading_pdi_data and pdi_fire) or (reading_sdi_data and sdi_fire) then
                segment_counter_hi <= segment_counter_hi - 1;
            end if;
            decrypt_flag <= nx_decrypt_flag;
            if reading_pdi_hdr and hdr_first then
                eoi_flag <= pdi_hdr_eoi;
                eot_flag <= pdi_hdr_eot;
            end if;
            --! for simulation only
            -- synthesis translate_off
            assert not received_wrong_header
            report "[PreProcessor] Received unexpected header at state: " & t_state'image(state)
            severity failure;
            -- synthesis translate_on
        end if;
    end process;

    --===========================================================================================--
    last_flit_of_segment <= is_zero(segment_counter_hi(segment_counter_hi'length - 1 downto 1)) and --
                            (segment_counter_hi(0) = '0' or is_zero(segment_counter_lo));

    -- bdi number of valid bytes as a binary integer
    bdi_size_p <= std_logic_vector(resize(segment_counter_hi(0) & segment_counter_lo, bdi_size_p'length)) when last_flit_of_segment else --
                  std_logic_vector(to_unsigned(W / 8, bdi_size_p'length));
    -- bdi padding location
    bdi_pad_loc_p     <= reverse_bits(to_1H(bdi_size_p, bdi_pad_loc_p'length));
    -- bdi valid bytes
    bdi_valid_bytes_p <= reverse_bits(std_logic_vector(unsigned(reverse_bits(bdi_pad_loc_p)) - 1));

    pdi_fire  <= pdi_valid = '1' and pdi_ready_o = '1';
    sdi_fire  <= sdi_valid = '1' and sdi_ready_o = '1';
    bdi_eoi_p <= eoi_flag and to_std_logic(last_flit_of_segment);
    bdi_eot_p <= eot_flag and to_std_logic(last_flit_of_segment);

    op_is_actkey      <= pdi_hdr_opcode = INST_ACTKEY;
    op_is_hash        <= pdi_hdr_opcode(3) = '1'; -- INST_HASH
    op_is_enc_or_dec  <= pdi_hdr_opcode(3 downto 1) = INST_ENC(3 downto 1);
    hdr_seglen        <= sdi_hdr_seglen when reading_sdi_hdr else pdi_hdr_seglen;
    seglen_is_zero    <= is_zero(seglen);
    reset_hdr_counter <= state = S_INST;

    decrypt   <= decrypt_flag;
    pdi_ready <= pdi_ready_o;
    sdi_ready <= sdi_ready_o;
    cmd_data  <= pdi_hdr;

    --===========================================================================================--
    --= When using VHDL 2008+ change to
    -- process(all)
    process(state, decrypt_flag, eot_flag, --
        pdi_hdr_opcode, pdi_valid, pdi_fire, sdi_hdr_opcode, sdi_valid, sdi_fire, key_ready_p, --
        last_flit_of_segment, cmd_ready, bdi_ready_p, reading_pdi_hdr, reading_sdi_hdr, --
        seglen_is_zero, hdr_first, hdr_last, op_is_actkey, op_is_enc_or_dec, op_is_hash)
    begin
        -- Default Values
        sdi_ready_o           <= to_std_logic(reading_sdi_hdr);
        pdi_ready_o           <= to_std_logic(reading_pdi_hdr);
        key_valid_p           <= '0';
        key_update            <= '0';
        bdi_valid_p           <= '0';
        cmd_valid             <= '0';
        hash                  <= '0';
        -- let synthesis tool choose an optimized default value
        bdi_type              <= (others => '-');
        reading_pdi_hdr       <= false;
        reading_pdi_data      <= false;
        reading_sdi_hdr       <= false;
        reading_sdi_data      <= false;
        -- default input of registers: feedback of their current values
        nx_state              <= state;
        nx_decrypt_flag       <= decrypt_flag;
        -- for simulation only
        received_wrong_header <= false;

        -- TODO: Parallel key loading not currently supported
        case state is
            -- receive PDI instruction
            when S_INST =>
                cmd_valid   <= pdi_valid and not to_std_logic(op_is_actkey);
                pdi_ready_o <= cmd_ready or to_std_logic(op_is_actkey);
                if pdi_fire then
                    if op_is_actkey then
                        nx_state <= S_INST_KEY;
                    elsif op_is_hash then
                        nx_state <= S_HDR_HASH;
                    else
                        received_wrong_header <= not op_is_enc_or_dec;
                        nx_decrypt_flag       <= pdi_hdr_opcode(0);
                        if G_OFFLINE then
                            nx_state <= S_HDR_LENGTH;
                        else
                            nx_state <= S_HDR_NPUB;
                        end if;
                    end if;
                end if;

            -- receive SDI instruction
            when S_INST_KEY =>
                sdi_ready_o <= '1';
                if sdi_fire then
                    received_wrong_header <= sdi_hdr_opcode /= INST_LDKEY;
                    nx_state              <= S_HDR_KEY;
                end if;

            -- receive key header from SDI
            when S_HDR_KEY =>
                reading_sdi_hdr <= true;
                if sdi_fire then
                    if hdr_first then
                        received_wrong_header <= sdi_hdr_opcode /= HDR_KEY;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_KEY;
                    end if;
                end if;

            -- receive key data from SDI
            when S_LD_KEY =>
                sdi_ready_o      <= key_ready_p;
                key_valid_p      <= sdi_valid;
                reading_sdi_data <= true;
                key_update       <= '1';
                if sdi_fire then
                    if last_flit_of_segment then
                        nx_state <= S_INST;
                    end if;
                end if;

            -- Read "length segment" header
            when S_HDR_LENGTH =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_LENGTH;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_LENGTH;
                    end if;
                end if;

            -- Read data of "length segment" type
            when S_LD_LENGTH =>
                pdi_ready_o      <= bdi_ready_p;
                bdi_valid_p      <= pdi_valid;
                bdi_type         <= HDR_LENGTH;
                reading_pdi_data <= true;
                if pdi_fire then
                    if last_flit_of_segment then
                        nx_state <= S_HDR_NPUB;
                    end if;
                end if;

            -- NPUB header
            when S_HDR_NPUB =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_NPUB;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_NPUB;
                    end if;
                end if;

            -- Read NPUB data
            when S_LD_NPUB =>
                pdi_ready_o      <= bdi_ready_p;
                bdi_valid_p      <= pdi_valid;
                bdi_type         <= HDR_NPUB;
                reading_pdi_data <= true;
                if pdi_fire and last_flit_of_segment then
                    nx_state <= S_HDR_AD;
                end if;

            -- AD header
            when S_HDR_AD =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_AD;
                    end if;
                    if hdr_last then
                        if seglen_is_zero then
                            if pdi_hdr_eoi = '1' then
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
                end if;

            -- Read Associated Data
            when S_LD_AD =>
                pdi_ready_o      <= bdi_ready_p;
                bdi_valid_p      <= pdi_valid;
                bdi_type         <= HDR_AD;
                reading_pdi_data <= true;
                if pdi_fire then
                    if last_flit_of_segment then
                        if eot_flag = '1' then
                            nx_state <= S_HDR_MSG;
                        else
                            nx_state <= S_HDR_AD;
                        end if;
                    end if;
                end if;

            -- Plaintext or ciphertext header
            when S_HDR_MSG =>
                pdi_ready_o     <= cmd_ready;
                cmd_valid       <= pdi_valid;
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_PT and pdi_hdr_opcode /= HDR_CT;
                    end if;
                    if hdr_last then
                        if seglen_is_zero and eot_flag = '1' then
                            if decrypt_flag = '1' then
                                nx_state <= S_HDR_TAG;
                            else
                                nx_state <= S_INST;
                            end if;
                        else
                            nx_state <= S_LD_MSG;
                        end if;
                    end if;
                end if;

            -- Read plaintext or ciphertext data
            when S_LD_MSG =>
                pdi_ready_o      <= bdi_ready_p;
                bdi_valid_p      <= pdi_valid;
                reading_pdi_data <= true;
                if decrypt_flag = '1' then
                    bdi_type <= HDR_CT;
                else
                    bdi_type <= HDR_PT;
                end if;
                if pdi_fire and last_flit_of_segment then
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

            -- Read TAG header (only during decryption)
            when S_HDR_TAG =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_TAG;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_TAG;
                    end if;
                end if;

            -- Read TAG data (only during decryption)
            when S_LD_TAG =>
                reading_pdi_data <= true;
                pdi_ready_o      <= bdi_ready_p;
                bdi_type         <= HDR_TAG;
                bdi_valid_p      <= pdi_valid;
                if pdi_fire and last_flit_of_segment then
                    nx_state <= S_INST;
                end if;

            -- receive Hash header
            when S_HDR_HASH =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_hdr_opcode /= HDR_HASH_MSG;
                    end if;
                    if hdr_last then
                        if seglen_is_zero then
                            nx_state <= S_EMPTY_HASH;
                        else
                            nx_state <= S_LD_HASHMSG;
                        end if;
                    end if;
                end if;

            -- Empty Hash message is sent to CryptoCore
            when S_EMPTY_HASH =>
                hash        <= '1';
                bdi_valid_p <= '1';
                bdi_type    <= HDR_HASH_MSG;
                if bdi_ready_p = '1' then
                    nx_state <= S_INST;
                end if;

            -- receive Hash message and send it to CryptoCore
            when S_LD_HASHMSG =>
                hash             <= '1';
                pdi_ready_o      <= bdi_ready_p;
                bdi_valid_p      <= pdi_valid;
                bdi_type         <= HDR_HASH_MSG;
                reading_pdi_data <= true;
                if pdi_fire and last_flit_of_segment then
                    if eot_flag = '1' then
                        nx_state <= S_INST;
                    else
                        nx_state <= S_HDR_HASH;
                    end if;
                end if;

        end case;
    end process;

end PreProcessor;
