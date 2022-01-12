--------------------------------------------------------------------------------
--! @file       PreProcessor.vhd
--! @brief      Pre-processor for NIST LWC API
--!
--! @author     Michael Tempelmeier
--! @author     Farnoud Farahmand
--! @author     Kamyar Mohajerani
--!
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology
--!             ECE Department, Technical University of Munich, GERMANY
--!
--!             Copyright (c) 2022 Cryptographic Engineering Research Group
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
--------------------------------------------------------------------------------
--! Description
--!
--!
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.NIST_LWAPI_pkg.all;
use work.design_pkg.all;

entity PreProcessor is

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
        key_data        : out std_logic_vector(CCSW - 1 downto 0);
        key_valid       : out std_logic;
        key_ready       : in  std_logic;
        key_update      : out std_logic;
        --
        bdi_data        : out std_logic_vector(CCW - 1 downto 0);
        bdi_valid       : out std_logic;
        bdi_ready       : in  std_logic;
        bdi_pad_loc     : out std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_valid_bytes : out std_logic_vector(CCWdiv8 - 1 downto 0);
        bdi_size        : out std_logic_vector(2 downto 0);
        bdi_eot         : out std_logic;
        bdi_eoi         : out std_logic;
        bdi_type        : out std_logic_vector(3 downto 0);
        --
        decrypt         : out std_logic;
        hash            : out std_logic;
        ---! Header FIFO ===================================================
        cmd_data        : out std_logic_vector(W - 1 downto 0);
        cmd_valid       : out std_logic;
        cmd_ready       : in  std_logic
    );

end entity PreProcessor;

architecture PreProcessor of PreProcessor is
    --================================================== Constants ==================================================--
    constant LOG2_W_DIV_8 : natural  := log2ceil(Wdiv8);
    constant HDR_LEN_BITS : positive := minimum(W, 16);

    --==================================================== Types ====================================================--
    type t_state is (S_INST, S_INST_KEY, S_HDR_KEY, S_LD_KEY, S_HDR_LENGTH, S_LD_LENGTH, S_HDR_NPUB, S_LD_NPUB,
                     S_HDR_AD, S_LD_AD, S_HDR_MSG, S_LD_MSG, S_HDR_TAG, S_LD_TAG, S_HDR_HASH, S_LD_HASHMSG,
                     S_EMPTY_HASH);

    --================================================== Registers ==================================================--
    signal segment_counter                             : unsigned(15 downto 0);
    signal eoi_flag, eot_flag, hash_flag, decrypt_flag : std_logic;
    signal state                                       : t_state;

    -- Wires
    signal nx_hash_flag, nx_decrypt_flag                          : std_logic;
    signal bdi_eoi_internal, bdi_eot_internal                     : std_logic;
    signal pdi_ready_internal, sdi_ready_internal                 : std_logic;
    signal pdi_fire, sdi_fire                                     : boolean;
    signal opcode_is_actkey, opcode_is_hash, opcode_is_enc_or_dec : boolean;
    signal reset_hdr_counter, hdr_first, hdr_2, hdr_last          : boolean;
    signal bdi_valid_p, bdi_ready_p                               : std_logic;
    signal key_valid_p, key_ready_p                               : std_logic;
    signal bdi_size_p                                             : std_logic_vector(2 downto 0);
    signal segment_counter_lo                                     : unsigned(LOG2_W_DIV_8 downto 0);
    signal reading_pdi_data, reading_sdi_data                     : boolean;
    signal reading_sdi_hdr, reading_pdi_hdr                       : boolean;
    signal segment_length                                         : std_logic_vector(15 downto 0);
    signal segment_length_is_zero                                 : boolean;
    signal header_word_seglen                                     : std_logic_vector(HDR_LEN_BITS - 1 downto 0);
    signal last_flit_of_segment                                   : boolean;
    signal seglen_msb8                                            : std_logic_vector(16 - HDR_LEN_BITS - 1 downto 0);
    signal nx_state                                               : t_state;
    signal pdi_valid_bytes                                        : std_logic_vector(Wdiv8 - 1 downto 0);
    signal bdi_pad_loc_p                                          : std_logic_vector(Wdiv8 - 1 downto 0);
    --!for simulation only
    signal received_wrong_header                                  : boolean;

    --=================================================== Aliases ===================================================--
    alias pdi_opcode         : std_logic_vector(3 downto 0) is pdi_data(W - 1 downto W - 4);
    alias pdi_cmd_eoi        : std_logic is pdi_data(W - 6);
    alias pdi_cmd_eot        : std_logic is pdi_data(W - 7);
    alias sdi_opcode         : std_logic_vector(3 downto 0) is sdi_data(W - 1 downto W - 4);
    alias segment_counter_hi : unsigned(15 - LOG2_W_DIV_8 downto 0) is segment_counter(15 downto LOG2_W_DIV_8);
    alias pdi_seg_length     : std_logic_vector(HDR_LEN_BITS - 1 downto 0) is pdi_data(HDR_LEN_BITS - 1 downto 0);
    alias sdi_seg_length     : std_logic_vector(HDR_LEN_BITS - 1 downto 0) is sdi_data(HDR_LEN_BITS - 1 downto 0);

begin

    --================================================== Instances ==================================================--
    --! KEY PISO
    -- for ccsw > SW: a piso is used for width conversion
    keyPISO : entity work.KEY_PISO
        port map(
            clk          => clk,
            rst          => rst,
            data_s       => key_data,
            data_valid_s => key_valid,
            data_ready_s => key_ready,
            data_p       => sdi_data,
            data_valid_p => key_valid_p,
            data_ready_p => key_ready_p
        );

    --! DATA PISO
    -- for ccw > W: a piso is used for width conversion
    bdiPISO : entity work.DATA_PISO
        port map(
            clk           => clk,
            rst           => rst,
            data_size_p   => bdi_size_p,
            data_size_s   => bdi_size,
            data_s        => bdi_data,
            data_valid_s  => bdi_valid,
            data_ready_s  => bdi_ready,
            data_p        => pdi_data,
            data_valid_p  => bdi_valid_p,
            data_ready_p  => bdi_ready_p,
            valid_bytes_p => pdi_valid_bytes,
            valid_bytes_s => bdi_valid_bytes,
            pad_loc_p     => bdi_pad_loc_p,
            pad_loc_s     => bdi_pad_loc,
            eoi_p         => bdi_eoi_internal,
            eoi_s         => bdi_eoi,
            eot_p         => bdi_eot_internal,
            eot_s         => bdi_eot
        );

    --===============================================================================================================--
    hash      <= hash_flag;
    decrypt   <= decrypt_flag;
    cmd_data  <= pdi_data;
    pdi_ready <= pdi_ready_internal;
    sdi_ready <= sdi_ready_internal;

    segment_counter_lo     <= segment_counter(LOG2_W_DIV_8 downto 0);
    header_word_seglen     <= sdi_seg_length when reading_sdi_hdr else pdi_seg_length;
    segment_length         <= seglen_msb8 & header_word_seglen;
    segment_length_is_zero <= is_zero(segment_length);
    reset_hdr_counter      <= state = S_INST;

    W8_GEN : if W = 8 generate
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
                if sdi_fire or pdi_fire then
                    seglen_msb8 <= header_word_seglen;
                end if;
            end if;
        end process;

        hdr_first <= hdr_counter = 0;
        hdr_2     <= hdr_counter = 2;
        hdr_last  <= hdr_counter = 3;
    end generate;

    W16_GEN : if W = 16 generate
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
        hdr_2     <= hdr_counter = 1;
        hdr_last  <= hdr_2;
    end generate;

    W32_GEN : if W = 32 generate
    begin
        hdr_first <= true;
        hdr_2     <= true;
        hdr_last  <= true;
    end generate;

    last_flit_of_segment <= is_zero(segment_counter_hi(segment_counter_hi'length - 1 downto 1)) and --
                            (segment_counter_hi(0) = '0' or is_zero(segment_counter_lo(segment_counter_lo'length - 2 downto 0)));

    bdi_size_p <= std_logic_vector(resize(segment_counter_lo, bdi_size_p'length)) when last_flit_of_segment else --
                  std_logic_vector(to_unsigned(Wdiv8, bdi_size_p'length));
    -- bdi padding location
    bdi_pad_loc_p   <= reverse_bits(to_1H(bdi_size_p, bdi_pad_loc_p'length));
    -- bdi valid bytes
    pdi_valid_bytes <= reverse_bits(std_logic_vector(unsigned(reverse_bits(bdi_pad_loc_p)) - 1));

    pdi_fire <= pdi_valid = '1' and pdi_ready_internal = '1';
    sdi_fire <= sdi_valid = '1' and sdi_ready_internal = '1';

    bdi_eoi_internal <= eoi_flag and to_std_logic(last_flit_of_segment);
    bdi_eot_internal <= eot_flag and to_std_logic(last_flit_of_segment);

    opcode_is_actkey     <= pdi_opcode = INST_ACTKEY;
    opcode_is_hash       <= pdi_opcode(3) = '1'; -- INST_HASH
    opcode_is_enc_or_dec <= pdi_opcode(3 downto 1) = INST_ENC(3 downto 1);

    --===============================================================================================================--
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
                segment_counter <= unsigned(segment_length);
            elsif (reading_pdi_data and pdi_fire) or (reading_sdi_data and sdi_fire) then
                segment_counter_hi <= segment_counter_hi - 1;
            end if;
            hash_flag    <= nx_hash_flag;
            decrypt_flag <= nx_decrypt_flag;
            if reading_pdi_hdr and hdr_first then
                eoi_flag <= pdi_cmd_eoi;
                eot_flag <= pdi_cmd_eot;
            end if;
        end if;
    end process;

    --! for simulation only
    -- synthesis translate_off
    process(clk)
    begin
        if rising_edge(clk) then
            assert not received_wrong_header report "Received unexpected header" severity failure;
        end if;
    end process;
    -- synthesis translate_on

    --===============================================================================================================--
    -- if using VHDL 2008+ --
    -- process(all)
    process(state, last_flit_of_segment, decrypt_flag, key_ready_p, segment_length_is_zero, --
        bdi_ready_p, eot_flag, pdi_seg_length, sdi_opcode, cmd_ready, pdi_fire, reading_pdi_hdr, reading_sdi_hdr, --
        hdr_first, hdr_last, sdi_fire, sdi_valid, pdi_valid, hash_flag, pdi_opcode, opcode_is_actkey, opcode_is_enc_or_dec, opcode_is_hash)
    begin
        -- DEFAULT Values
        sdi_ready_internal    <= to_std_logic(reading_sdi_hdr);
        pdi_ready_internal    <= to_std_logic(reading_pdi_hdr);
        key_valid_p           <= '0';
        key_update            <= '0';
        bdi_valid_p           <= '0';
        cmd_valid             <= '0';
        bdi_type              <= (others => '-');
        reading_pdi_data      <= false;
        reading_sdi_data      <= false;
        reading_sdi_hdr       <= false;
        reading_pdi_hdr       <= false;
        -- default for register input is feedback of its current value
        nx_hash_flag          <= hash_flag;
        nx_decrypt_flag       <= decrypt_flag;
        nx_state              <= state;
        -- for simulation only
        received_wrong_header <= false;

        --We don't allow for parallel key loading in a lightweight enviroment
        -- TODO implement, at least as an option. The overhead should be negligable.
        case state is
            -- receive PDI instruction
            when S_INST =>
                cmd_valid          <= pdi_valid and not to_std_logic(opcode_is_actkey);
                pdi_ready_internal <= cmd_ready or to_std_logic(opcode_is_actkey);
                nx_hash_flag       <= '0';
                if pdi_fire then
                    if opcode_is_actkey then
                        nx_state <= S_INST_KEY;
                    elsif opcode_is_hash then
                        nx_hash_flag <= '1';
                        nx_state     <= S_HDR_HASH;
                    else
                        received_wrong_header <= not opcode_is_enc_or_dec;
                        nx_decrypt_flag       <= pdi_opcode(0);
                        if G_OFFLINE then
                            nx_state <= S_HDR_LENGTH;
                        else
                            nx_state <= S_HDR_NPUB;
                        end if;
                    end if;
                end if;

            -- receive SDI instruction
            when S_INST_KEY =>
                sdi_ready_internal <= '1';
                if sdi_fire then
                    received_wrong_header <= sdi_opcode /= INST_LDKEY;
                    nx_state              <= S_HDR_KEY;
                end if;

            -- receive key header from SDI
            when S_HDR_KEY =>
                reading_sdi_hdr <= true;
                if sdi_fire then
                    if hdr_first then
                        received_wrong_header <= sdi_opcode /= HDR_KEY;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_KEY;
                    end if;
                end if;

            -- receive key data from SDI
            when S_LD_KEY =>
                sdi_ready_internal <= key_ready_p;
                key_valid_p        <= sdi_valid;
                reading_sdi_data   <= true;
                key_update         <= '1';
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
                        received_wrong_header <= pdi_opcode /= HDR_LENGTH;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_LENGTH;
                    end if;
                end if;

            -- Read data of "length segment" type
            when S_LD_LENGTH =>
                pdi_ready_internal <= bdi_ready_p;
                bdi_valid_p        <= pdi_valid;
                bdi_type           <= HDR_LENGTH;
                reading_pdi_data   <= true;
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
                        received_wrong_header <= pdi_opcode /= HDR_NPUB;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_NPUB;
                    end if;
                end if;

            -- Read NPUB data
            when S_LD_NPUB =>
                pdi_ready_internal <= bdi_ready_p;
                bdi_valid_p        <= pdi_valid;
                bdi_type           <= HDR_NPUB;
                reading_pdi_data   <= true;
                if pdi_fire and last_flit_of_segment then
                    nx_state <= S_HDR_AD;
                end if;

            -- AD header
            when S_HDR_AD =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_opcode /= HDR_AD;
                    end if;
                    if hdr_last then
                        if segment_length_is_zero then
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
                end if;

            -- Read Associated Data
            when S_LD_AD =>
                pdi_ready_internal <= bdi_ready_p;
                bdi_valid_p        <= pdi_valid;
                bdi_type           <= HDR_AD;
                reading_pdi_data   <= true;
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
                pdi_ready_internal <= cmd_ready;
                cmd_valid          <= pdi_valid;
                reading_pdi_hdr    <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_opcode /= HDR_PT and pdi_opcode /= HDR_CT;
                    end if;
                    if hdr_last then
                        if segment_length_is_zero and eot_flag = '1' then
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
                pdi_ready_internal <= bdi_ready_p;
                bdi_valid_p        <= pdi_valid;
                reading_pdi_data   <= true;
                if decrypt_flag = '1' then
                    bdi_type <= HDR_CT;
                else
                    bdi_type <= HDR_PT;
                end if;
                if pdi_fire then
                    if last_flit_of_segment then
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

            -- Read TAG header (only during decryption)
            when S_HDR_TAG =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_opcode /= HDR_TAG;
                    end if;
                    if hdr_last then
                        nx_state <= S_LD_TAG;
                    end if;
                end if;

            -- Read TAG data (only during decryption)
            when S_LD_TAG =>
                reading_pdi_data   <= true;
                pdi_ready_internal <= bdi_ready_p;
                bdi_type           <= HDR_TAG;
                bdi_valid_p        <= pdi_valid;
                if pdi_fire then
                    if last_flit_of_segment then
                        nx_state <= S_INST;
                    end if;
                end if;

            -- receive Hash header
            when S_HDR_HASH =>
                reading_pdi_hdr <= true;
                if pdi_fire then
                    if hdr_first then
                        received_wrong_header <= pdi_opcode /= HDR_HASH_MSG;
                    end if;
                    if hdr_last then
                        if segment_length_is_zero then
                            nx_state <= S_EMPTY_HASH;
                        else
                            nx_state <= S_LD_HASHMSG;
                        end if;
                    end if;
                end if;

            -- Empty Hash message is sent to CryptoCore
            when S_EMPTY_HASH =>
                bdi_valid_p <= '1';
                bdi_type    <= HDR_HASH_MSG;
                if bdi_ready_p = '1' then
                    nx_state <= S_INST;
                end if;

            -- receive Hash message and send it to CryptoCore
            when S_LD_HASHMSG =>
                pdi_ready_internal <= bdi_ready_p;
                bdi_valid_p        <= pdi_valid;
                bdi_type           <= HDR_HASH_MSG;
                reading_pdi_data   <= true;
                if pdi_fire then
                    if last_flit_of_segment then
                        if eot_flag = '1' then
                            nx_state <= S_INST;
                        else
                            nx_state <= S_HDR_HASH;
                        end if;
                    end if;
                end if;

        end case;
    end process;

end PreProcessor;
