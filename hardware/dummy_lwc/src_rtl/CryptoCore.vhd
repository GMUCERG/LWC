--------------------------------------------------------------------------------
--! @file       CryptoCore.vhd
--! @brief      Implementation of the dummy_lwc cipher and hash.
--!
--! @author     Patrick Karl <patrick.karl@tum.de>
--! @copyright  Copyright (c) 2019 Chair of Security in Information Technology     
--!             ECE Department, Technical University of Munich, GERMANY
--!             All rights Reserved.
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             unrestricted)                                                  
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.design_pkg.all;
use work.NIST_LWAPI_pkg.all;

entity CryptoCore is
    port(
        clk             : in  std_logic;
        rst             : in  std_logic;
        ---- PreProcessor ===============================================
        --! Key
        key             : in  std_logic_vector(CCSW - 1 downto 0);
        key_valid       : in  std_logic;
        key_ready       : out std_logic;
        --! Data Input
        bdi             : in  std_logic_vector(CCW - 1 downto 0);
        bdi_valid       : in  std_logic;
        bdi_ready       : out std_logic;
        bdi_pad_loc     : in  std_logic_vector(CCW / 8 - 1 downto 0);
        bdi_valid_bytes : in  std_logic_vector(CCW / 8 - 1 downto 0);
        bdi_size        : in  std_logic_vector(3 - 1 downto 0);
        bdi_eot         : in  std_logic;
        bdi_eoi         : in  std_logic;
        bdi_type        : in  std_logic_vector(4 - 1 downto 0);
        decrypt_in      : in  std_logic;
        key_update      : in  std_logic;
        hash_in         : in  std_logic;
        ---- Post Processor =========================================
        --! Data Output
        bdo             : out std_logic_vector(CCW - 1 downto 0);
        bdo_valid       : out std_logic;
        bdo_ready       : in  std_logic;
        bdo_type        : out std_logic_vector(4 - 1 downto 0);
        bdo_valid_bytes : out std_logic_vector(CCW / 8 - 1 downto 0);
        --! The last word of BDO of the currect outout type (i.e., "bdo_eot")
        end_of_block    : out std_logic;
        --! Tag authentication
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in  std_logic;
        msg_auth        : out std_logic
    );
end CryptoCore;

architecture behavioral of CryptoCore is

    --! Constant to check for empty hash
    constant EMPTY_HASH_SIZE_C : std_logic_vector(2 downto 0) := (others => '0');
    -- Counters are specified to be 64-Bit counters for AD/MSG-Bits. We only count
    -- Bytes and prepend three zero bits afterwards to save FFs (thus maximum range is 61).
    --! Width of the ad byte-counter.
    constant AD_CNT_WIDTH_C    : integer range 1 to 61        := AD_CNT_WIDTH - 3;
    --! Width of msg byte-counter
    constant MSG_CNT_WIDTH_C   : integer range 1 to 61        := MSG_CNT_WIDTH - 3;
    --! Width for the msg block counter.
    -- Has to count up to (#MSG_BYTES + DBLK_SIZE/8 - 1) / (DBLK_SIZE/8) which is equal
    -- to MSG_CNT_WIDTH_C - log2ceil(DBLK_SIZE/8) bits. But at least use one bit.
    constant BLOCK_CNT_WIDTH_C : integer                      := maximum(MSG_CNT_WIDTH_C - log2ceil(DBLK_SIZE / 8), 1);

    -- Number of words the respective blocks contain.
    constant NPUB_WORDS_C    : integer := get_words(NPUB_SIZE, CCW);
    constant HASH_WORDS_C    : integer := get_words(HASH_VALUE_SIZE, CCW);
    constant BLOCK_WORDS_C   : integer := get_words(DBLK_SIZE, CCW);
    -- Number of address bits required to address the above blocks when stored as ram.
    constant ADDR_BITS_96_C  : integer := log2ceil(NPUB_WORDS_C);
    constant ADDR_BITS_128_C : integer := log2ceil(BLOCK_WORDS_C);
    constant ADDR_BITS_256_C : integer := log2ceil(HASH_WORDS_C);

    -- TAG Ram signals (also used for hash value)
    signal tag_wen_s     : std_logic;
    signal tag_addr_s    : std_logic_vector(ADDR_BITS_256_C - 1 downto 0);
    signal tag_din_s     : std_logic_vector(CCW - 1 downto 0);
    signal tag_dout_s    : std_logic_vector(CCW - 1 downto 0);
    signal data_to_tag_s : std_logic_vector(CCW - 1 downto 0);

    -- Key Ram signals
    signal key_wen_s  : std_logic;
    signal key_addr_s : std_logic_vector(ADDR_BITS_128_C - 1 downto 0);
    signal key_din_s  : std_logic_vector(CCSW - 1 downto 0);
    signal key_dout_s : std_logic_vector(CCSW - 1 downto 0);

    -- Npub Ram signals
    signal npub_wen_s  : std_logic;
    signal npub_addr_s : std_logic_vector(ADDR_BITS_96_C - 1 downto 0);
    signal npub_din_s  : std_logic_vector(CCW - 1 downto 0);
    signal npub_dout_s : std_logic_vector(CCW - 1 downto 0);
    -- Signal used to 'resize' 96 bit npub to 128 bit block size.
    signal padd_npub_s : std_logic_vector(CCW - 1 downto 0);

    -- State signals
    type state_t is (IDLE, STORE_KEY, RELOAD_KEY, ABSORB_NONCE, ABSORB_AD, ABSORB_MSG,
                     PADD_AD, PADD_MSG, ABSORB_LENGTH, EXTRACT_TAG, VERIFY_TAG, WAIT_ACK,
                     INIT_HASH, ABSORB_HASH_MSG, PADD_HASH_MSG, EXTRACT_HASH_VALUE);
    signal n_state_s, state_s : state_t;

    -- Concatenated length according to specification
    signal len_s               : std_logic_vector(DBLK_SIZE - 1 downto 0);
    signal len_word_s          : std_logic_vector(CCW - 1 downto 0);
    -- Number of ad / msg bytes and their corresponding bit vectors (required for casting...)
    signal ad_byte_cnt_s       : unsigned(AD_CNT_WIDTH_C - 1 downto 0);
    signal ad_byte_cnt_s_next  : unsigned(AD_CNT_WIDTH_C - 1 downto 0);
    signal ad_bit_cnt_vec_s    : std_logic_vector(DBLK_SIZE / 2 - 1 downto 0);
    signal msg_byte_cnt_s      : unsigned(MSG_CNT_WIDTH_C - 1 downto 0);
    signal msg_byte_cnt_s_next : unsigned(MSG_CNT_WIDTH_C - 1 downto 0);
    signal msg_bit_cnt_vec_s   : std_logic_vector(DBLK_SIZE / 2 - 1 downto 0);
    -- Counter for blocks will be casted to block number block_num_s according to specification
    -- Counter for blocks will be casted to block number block_num_s according to specification
    signal block_cnt_s         : unsigned(BLOCK_CNT_WIDTH_C - 1 downto 0);
    signal block_cnt_s_next    : unsigned(BLOCK_CNT_WIDTH_C - 1 downto 0);
    signal block_num_s         : std_logic_vector(DBLK_SIZE - 1 downto 0);
    signal block_num_word_s    : std_logic_vector(CCW - 1 downto 0);

    -- Word counter for address generation. Increases every time a word is transferred.
    signal word_cnt_s      : integer range 0 to HASH_WORDS_C - 1;
    signal word_cnt_s_next : integer range 0 to HASH_WORDS_C - 1;
    signal ram_addr_s      : std_logic_vector(ADDR_BITS_256_C - 1 downto 0);

    -- Internal Port signals
    signal key_s             : std_logic_vector(CCSW - 1 downto 0);
    signal key_ready_s       : std_logic;
    signal bdi_ready_s       : std_logic;
    signal bdi_s             : std_logic_vector(CCW - 1 downto 0);
    signal bdi_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 downto 0);
    signal bdi_pad_loc_s     : std_logic_vector(CCWdiv8 - 1 downto 0);

    signal bdo_s             : std_logic_vector(CCW - 1 downto 0);
    signal bdo_valid_bytes_s : std_logic_vector(CCWdiv8 - 1 downto 0);
    signal bdo_valid_s       : std_logic;
    signal bdo_type_s        : std_logic_vector(3 downto 0);
    signal end_of_block_s    : std_logic;
    signal msg_auth_valid_s  : std_logic;

    -- Internal flags
    signal bdi_partial_s                : std_logic;
    signal n_decrypt_s, decrypt_s       : std_logic;
    signal n_hash_s, hash_s             : std_logic;
    signal n_empty_hash_s, empty_hash_s : std_logic;
    signal n_msg_auth_s, msg_auth_s     : std_logic;
    signal n_eoi_s, eoi_s               : std_logic;
    signal n_update_key_s, update_key_s : std_logic;

begin

    ----------------------------------------------------------------------------
    -- I/O Mappings
    -- Algorithm is specified in Big Endian. However, this is a Little Endian
    -- implementation so reverse_bytes/bit functions are used to reorder affected signals.
    ----------------------------------------------------------------------------
    key_s             <= reverse_bytes(key);
    bdi_s             <= reverse_bytes(bdi);
    bdi_valid_bytes_s <= reverse_bits(bdi_valid_bytes);
    bdi_pad_loc_s     <= reverse_bits(bdi_pad_loc);
    key_ready         <= key_ready_s;
    bdi_ready         <= bdi_ready_s;
    bdo               <= reverse_bytes(bdo_s);
    bdo_valid_bytes   <= reverse_bits(bdo_valid_bytes_s);
    bdo_valid         <= bdo_valid_s;
    bdo_type          <= bdo_type_s;
    end_of_block      <= end_of_block_s;
    msg_auth          <= msg_auth_s;
    msg_auth_valid    <= msg_auth_valid_s;

    -- Utility signal: Indicates whether the input word is fully filled or not.
    -- If '1', word is only partially filled.
    -- Used to determine whether 0x80 padding word can be inserted into this last word.
    bdi_partial_s <= lwc_or_reduce(bdi_pad_loc_s);

    ----------------------------------------------------------------------------
    --! Tag RAM instantiation - used to calculate tag and hash_value
    ----------------------------------------------------------------------------
    i_tag_ram : entity work.RAM1RW
        generic map(
            DataWidth => CCW,
            AddrWidth => ADDR_BITS_256_C
        )
        port map(
            clk  => clk,
            wen  => tag_wen_s,
            addr => tag_addr_s,
            din  => tag_din_s,
            dout => tag_dout_s
        );

    -- tag_wen_s set in decoder process for control logic.

    -- Address is same for every ram... Just the number of already written words.
    tag_addr_s <= ram_addr_s;

    ----------------------------------------------------------------------------
    --! Key RAM instantiation
    ----------------------------------------------------------------------------
    -- required for later CT generation
    i_key_ram : entity work.RAM1RW
        generic map(
            DataWidth => CCSW,
            AddrWidth => ADDR_BITS_128_C
        )
        port map(
            clk  => clk,
            wen  => key_wen_s,
            addr => key_addr_s,
            din  => key_din_s,
            dout => key_dout_s
        );
    -- Only key is stored in ram. Could directly set key on key_ram port, however
    -- for consistency, we use this assignment.
    key_din_s  <= key_s;
    -- Only write into key ram if actual data transfer happens.
    key_wen_s  <= key_valid and key_ready_s;
    -- Address is same for every ram... Just the number of already written words.
    key_addr_s <= ram_addr_s(ADDR_BITS_128_C - 1 downto 0);

    ---------------------------------------------------------------------------
    --! NPub RAM instantiation
    ----------------------------------------------------------------------------
    -- required for later CT generation
    i_npub_ram : entity work.RAM1RW
        generic map(
            DataWidth => CCW,
            AddrWidth => ADDR_BITS_96_C
        )
        port map(
            clk  => clk,
            wen  => npub_wen_s,
            addr => npub_addr_s,
            din  => npub_din_s,
            dout => npub_dout_s
        );
    -- Only Npub is stored in ram.
    npub_din_s <= bdi_s;

    -- Write into ram if transferred data is actually npub
    npub_wen_s  <= bdi_valid and bdi_ready_s when (bdi_type = HDR_NPUB and state_s = ABSORB_NONCE) else
                   '0';
    -- Address is same for every ram... Just the number of already written words.
    npub_addr_s <= ram_addr_s(ADDR_BITS_96_C - 1 downto 0);

    -- Since the Npub ram is smaller than a block (96 Bit < 128 Bit), the remaining
    -- Words are just set to zero.
    padd_npub_s <= npub_dout_s when (word_cnt_s < NPUB_WORDS_C) else (others => '0');

    ----------------------------------------------------------------------------
    --! Bdo multiplexer
    ----------------------------------------------------------------------------
    p_bdo_mux : process(state_s, bdi_s, key_dout_s, word_cnt_s, bdi_valid_bytes_s, bdi_valid, bdi_eot, --
        decrypt_s, tag_dout_s, padd_npub_s, block_num_word_s)
    begin
        end_of_block_s    <= '0';
        bdo_s             <= (others => '0');
        bdo_valid_bytes_s <= (others => '0');
        bdo_valid_s       <= '0';
        bdo_type_s        <= HDR_TAG;
        case state_s is
            -- Directly connect bdi and bdo signals and encryp/decrypt data.
            -- Set bdo_type depending on mode.
            when ABSORB_MSG =>
                bdo_s             <= bdi_s xor key_dout_s xor padd_npub_s xor block_num_word_s;
                bdo_valid_bytes_s <= bdi_valid_bytes_s;
                bdo_valid_s       <= bdi_valid;
                end_of_block_s    <= bdi_eot;
                if (decrypt_s = '1') then
                    bdo_type_s <= HDR_PT;
                else
                    bdo_type_s <= HDR_CT;
                end if;

            -- Connect bdo with tag_ram to extract computed tag/hash_value depending
            -- on mode. Set end_of_block_s on either the last word of the tag block
            -- or the hash_value block.
            when EXTRACT_TAG =>
                bdo_s             <= tag_dout_s;
                bdo_valid_bytes_s <= (others => '1');
                bdo_valid_s       <= '1';
                bdo_type_s        <= HDR_TAG;
                if word_cnt_s = BLOCK_WORDS_C - 1 then
                    end_of_block_s <= '1';
                end if;

            when EXTRACT_HASH_VALUE =>
                bdo_s             <= tag_dout_s;
                bdo_valid_bytes_s <= (others => '1');
                bdo_valid_s       <= '1';
                bdo_type_s        <= HDR_HASH_VALUE;
                if word_cnt_s = HASH_WORDS_C - 1 then
                    end_of_block_s <= '1';
                end if;

            when others =>
                null;

        end case;
    end process p_bdo_mux;

    ----------------------------------------------------------------------------
    --! Registers for state and internal signals
    ----------------------------------------------------------------------------
    GEN_p_reg_SYNC_RST : if not ASYNC_RSTN generate
        p_reg : process(clk)
        begin
            if rising_edge(clk) then
                if (rst = '1') then
                    msg_auth_s   <= '1';
                    eoi_s        <= '0';
                    update_key_s <= '0';
                    decrypt_s    <= '0';
                    hash_s       <= '0';
                    empty_hash_s <= '0';
                    state_s      <= IDLE;
                else
                    msg_auth_s   <= n_msg_auth_s;
                    eoi_s        <= n_eoi_s;
                    update_key_s <= n_update_key_s;
                    decrypt_s    <= n_decrypt_s;
                    hash_s       <= n_hash_s;
                    empty_hash_s <= n_empty_hash_s;
                    state_s      <= n_state_s;
                end if;
            end if;
        end process p_reg;
    end generate GEN_p_reg_SYNC_RST;

    GEN_p_reg_ASYNC_RSTN : if ASYNC_RSTN generate
        p_reg : process(clk, rst)
        begin
            if (rst = '0') then
                msg_auth_s   <= '1';
                eoi_s        <= '0';
                update_key_s <= '0';
                decrypt_s    <= '0';
                hash_s       <= '0';
                empty_hash_s <= '0';
                state_s      <= IDLE;
            elsif rising_edge(clk) then
                msg_auth_s   <= n_msg_auth_s;
                eoi_s        <= n_eoi_s;
                update_key_s <= n_update_key_s;
                decrypt_s    <= n_decrypt_s;
                hash_s       <= n_hash_s;
                empty_hash_s <= n_empty_hash_s;
                state_s      <= n_state_s;
            end if;
        end process p_reg;
    end generate GEN_p_reg_ASYNC_RSTN;

    ----------------------------------------------------------------------------
    --! Next_state FSM
    ----------------------------------------------------------------------------
    p_next_state : process(state_s, key_valid, bdi_valid, bdi_ready_s, bdi_eot, bdi_eoi, eoi_s, --
        bdi_type, word_cnt_s, hash_in, decrypt_s, bdo_valid_s, bdo_ready, msg_auth_valid_s, --
        msg_auth_ready, bdi_partial_s)
    begin
        n_state_s <= state_s;
        case state_s is
            when IDLE =>
                -- Wake up as soon as valid bdi or key is signaled.
                if key_valid = '1' then
                    n_state_s <= STORE_KEY;
                elsif bdi_valid = '1' then
                    -- hash_in (and decrypt_in) are only valid when bdi_valid is asserted (it will
                    --    maintaint its value for the entire duration of the bdi operation)
                    if hash_in = '1' then
                        n_state_s <= INIT_HASH;
                    else
                        n_state_s <= RELOAD_KEY;
                    end if;
                end if;

            -- Initialize hash with zero so we don't need padding after receiving
            -- non-full hash_msg block. Additionally no distinction between empty
            -- hash or regular hash is required when extracting hash from ram.
            when INIT_HASH =>
                if word_cnt_s = HASH_WORDS_C - 1 then
                    if eoi_s = '1' then
                        n_state_s <= EXTRACT_HASH_VALUE;
                    else
                        n_state_s <= ABSORB_HASH_MSG;
                    end if;
                end if;

            -- Wait until the new key is completely received or until the old
            -- key is transferred from key_ram to tag_ram.
            -- It is assumed, that key is only updated if Npub follows. Otherwise
            -- state transition back to IDLE is required to prevent deadlock in case
            -- bdi data follows that is not of type npub.
            when STORE_KEY =>
                if key_valid = '1' and word_cnt_s = BLOCK_WORDS_C - 1 then
                    n_state_s <= ABSORB_NONCE;
                end if;

            when RELOAD_KEY =>
                if word_cnt_s = BLOCK_WORDS_C - 1 then
                    n_state_s <= ABSORB_NONCE;
                end if;

            -- Wait until the whole nonce block is received. If no AD
            -- follows, directly go to extracting/verifying tag.
            when ABSORB_NONCE =>
                if bdi_valid = '1' and bdi_ready_s = '1' and word_cnt_s = NPUB_WORDS_C - 1 then
                    if bdi_eoi = '1' then
                        if (decrypt_s = '1') then
                            n_state_s <= VERIFY_TAG;
                        else
                            n_state_s <= EXTRACT_TAG;
                        end if;
                    else
                        n_state_s <= ABSORB_AD;
                    end if;
                end if;

            -- In case input is plaintext or ciphertext, no ad is processed.
            -- Wait until last word of AD is signaled. If padding is required
            -- (word_cnt_s < BLOCK_WORDS_C - 1) and 0x80 padding is not inserted
            -- in last word yet (bdi_partial_s = '0') go to padding state, else
            -- either go to absorb msg or directly aborb length depending on presence of msg data.
            when ABSORB_AD =>
                if (bdi_valid = '1' and (bdi_type = HDR_PT or bdi_type = HDR_CT)) then
                    n_state_s <= ABSORB_MSG;
                elsif (bdi_valid = '1' and bdi_ready_s = '1' and bdi_eot = '1') then
                    if (word_cnt_s < BLOCK_WORDS_C - 1 and bdi_partial_s = '0') then
                        n_state_s <= PADD_AD;
                    elsif (bdi_eoi = '1') then
                        n_state_s <= ABSORB_LENGTH;
                    else
                        n_state_s <= ABSORB_MSG;
                    end if;
                end if;

            -- Since only one cycle is required to insert 0x80 padding byte,
            -- go to absorb msg state or directly absorb length depending on the
            -- presence of msg data.
            when PADD_AD =>
                if (eoi_s = '1') then
                    n_state_s <= ABSORB_LENGTH;
                else
                    n_state_s <= ABSORB_MSG;
                end if;

            -- Read in either plaintext or ciphertext until end of type is
            -- detected. Then check whether padding is necessary or not as previously.
            when ABSORB_MSG =>
                if (bdi_valid = '1' and bdi_ready_s = '1' and bdi_eot = '1') then
                    if (word_cnt_s < BLOCK_WORDS_C - 1 and bdi_partial_s = '0') then
                        n_state_s <= PADD_MSG;
                    else
                        n_state_s <= ABSORB_LENGTH;
                    end if;
                end if;

            -- Next absorb length data.
            when PADD_MSG =>
                n_state_s <= ABSORB_LENGTH;

            -- Wait for end of hash_value. Decide whether extra padding state is
            -- required or directly go to extracting hash_value state.
            when ABSORB_HASH_MSG =>
                if (bdi_valid = '1' and bdi_ready_s = '1' and bdi_eoi = '1') then
                    if (word_cnt_s < HASH_WORDS_C - 1 and bdi_partial_s = '0') then
                        n_state_s <= PADD_HASH_MSG;
                    else
                        n_state_s <= EXTRACT_HASH_VALUE;
                    end if;
                end if;

            -- Only one cycle of padding is needed for inserting the 0x80 byte.
            when PADD_HASH_MSG =>
                n_state_s <= EXTRACT_HASH_VALUE;

            -- When lenght is absorbed, either verify the tag or extract it
            -- from ram depending on decrypt_s.
            when ABSORB_LENGTH =>
                if word_cnt_s = BLOCK_WORDS_C - 1 then
                    if decrypt_s = '1' then
                        n_state_s <= VERIFY_TAG;
                    else
                        n_state_s <= EXTRACT_TAG;
                    end if;
                end if;

            -- Wait until the whole tag block is transferred, then go back to IDLE.
            when EXTRACT_TAG =>
                if bdo_ready = '1' and word_cnt_s = BLOCK_WORDS_C - 1 then
                    n_state_s <= IDLE;
                end if;

            -- Wait until the tag being verified is received, continue
            -- with waiting for acknowledgement on msg_auth_valis.
            when VERIFY_TAG =>
                if bdi_valid = '1' and bdi_ready_s = '1' and word_cnt_s = BLOCK_WORDS_C - 1 then
                    n_state_s <= WAIT_ACK;
                end if;

            -- Wait until message authentication is acknowledged.
            when WAIT_ACK =>
                if msg_auth_valid_s = '1' and msg_auth_ready = '1' then
                    n_state_s <= IDLE;
                end if;

            -- Wait until the whole hash_value is transferred, then go back to IDLE.
            when EXTRACT_HASH_VALUE =>
                if bdo_valid_s = '1' and bdo_ready = '1' and word_cnt_s = HASH_WORDS_C - 1 then
                    n_state_s <= IDLE;
                end if;

        end case;
    end process p_next_state;

    ----------------------------------------------------------------------------
    --! Decoder process for control logic
    ----------------------------------------------------------------------------
    p_decoder : process(state_s, key_valid, key_ready_s, key_update, update_key_s, bdi_s, bdi_valid, bdi_ready_s, --
        bdi_eoi, bdi_valid_bytes_s, bdi_pad_loc_s, bdi_size, bdi_type, eoi_s, hash_in, hash_s, empty_hash_s, decrypt_in, --
        decrypt_s, bdo_s, bdo_ready, msg_auth_s, tag_dout_s, len_word_s, data_to_tag_s, key_din_s, key_dout_s --
        )
    begin
        -- Default values preventing latches
        key_ready_s      <= '0';
        bdi_ready_s      <= '0';
        msg_auth_valid_s <= '0';
        n_msg_auth_s     <= msg_auth_s;
        n_eoi_s          <= eoi_s;
        n_update_key_s   <= update_key_s;
        n_hash_s         <= hash_s;
        n_empty_hash_s   <= empty_hash_s;
        n_decrypt_s      <= decrypt_s;
        data_to_tag_s    <= (others => '0');
        tag_wen_s        <= '0';
        -- Initialize the RAM with the key, afterwards absorb (xor) any incoming
        -- data (Npub, Len, AD, PT).
        tag_din_s        <= data_to_tag_s xor tag_dout_s;

        case state_s is
            -- Default values. If valid input is detected, set internal flags
            -- depending on input and mode.
            when IDLE =>
                n_msg_auth_s   <= '1';
                n_eoi_s        <= '0';
                n_update_key_s <= '0';
                n_hash_s       <= '0';
                n_empty_hash_s <= '0';
                n_decrypt_s    <= '0';
                if (key_valid = '1' and key_update = '1') then
                    n_update_key_s <= '1';
                end if;
                if (bdi_valid = '1' and hash_in = '1') then
                    n_hash_s <= '1';
                    if (bdi_size = EMPTY_HASH_SIZE_C) then
                        n_empty_hash_s <= '1';
                        n_eoi_s        <= '1';
                    end if;
                end if;

            -- If empty hash is detected, acknowledge with one cycle bdi_ready.
            -- Afterwards empty_hash_s flag can be deasserted, it's not needed anymore.
            -- Enable tag_ram.
            when INIT_HASH =>
                tag_wen_s <= '1';
                tag_din_s <= (others => '0');
                if (empty_hash_s = '1') then
                    bdi_ready_s    <= '1';
                    n_empty_hash_s <= '0';
                end if;

            -- If key must be updated, assert key_ready.
            -- If key is updated, write to tag_ram on data transfer, else set
            -- it to '1' because key is directly streamed from key_ram to tag_ram.
            when STORE_KEY =>
                tag_din_s   <= std_logic_vector(resize(unsigned(key_din_s), tag_din_s'length));
                key_ready_s <= '1';
                tag_wen_s   <= key_valid and key_ready_s;

            when RELOAD_KEY =>
                tag_din_s <= std_logic_vector(resize(unsigned(key_dout_s), tag_din_s'length));
                tag_wen_s <= '1';

            -- Store bdi_eoi (will only be effective on last word) m and decrypt_in flag.
            -- Connect bdi_s (npub) to tag_ram.
            when ABSORB_NONCE =>
                bdi_ready_s   <= '1';
                n_eoi_s       <= bdi_eoi;
                n_decrypt_s   <= decrypt_in;
                data_to_tag_s <= bdi_s;
                if (bdi_valid = '1' and bdi_ready_s = '1' and bdi_type = HDR_NPUB) then
                    tag_wen_s <= '1';
                end if;

            -- If pt or ct is detected, don't assert bdi_ready, otherwise first word
            -- gets lost. Store bdi_eoi and connect padded bdi_s (ad) to tag_ram.
            -- padd() returns vector containing bdi_s and inserted 0x80 byte according
            -- to 10* padding.
            when ABSORB_AD =>
                if not (bdi_valid = '1' and (bdi_type = HDR_PT or bdi_type = HDR_CT)) then
                    bdi_ready_s <= '1';
                end if;
                if (bdi_valid = '1' and bdi_ready_s = '1') then
                    n_eoi_s       <= bdi_eoi;
                    data_to_tag_s <= padd(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s);
                    if (bdi_type = HDR_AD) then
                        tag_wen_s <= '1';
                    end if;
                end if;

            -- Set bdi_ready and connect the valid hash_msg bytes to tag_ram for
            -- absorbtion.
            when ABSORB_HASH_MSG =>
                bdi_ready_s <= '1';
                if (bdi_valid = '1' and bdi_ready_s = '1' and bdi_type = HDR_HASH_MSG) then
                    data_to_tag_s <= padd(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s);
                    tag_wen_s     <= '1';
                end if;

            -- Insert 0x80 padding byte (state is only reached if not yet inserted).
            when PADD_AD | PADD_MSG | PADD_HASH_MSG =>
                data_to_tag_s(7 downto 0) <= x"80";
                tag_wen_s                 <= '1';

            -- Write data to tag_ram and generate CT / PT
            -- Depending on encryption or decryption, padded bdi or bdo bytes are
            -- connected to the tag_ram.
            when ABSORB_MSG =>
                bdi_ready_s <= bdo_ready;
                if (bdi_valid = '1' and bdi_ready_s = '1') then
                    if (decrypt_s = '0' and bdi_type = HDR_PT) then
                        data_to_tag_s <= padd(bdi_s, bdi_valid_bytes_s, bdi_pad_loc_s);
                        tag_wen_s     <= '1';
                    elsif (bdi_type = HDR_CT) then
                        data_to_tag_s <= padd(bdo_s, bdi_valid_bytes_s, bdi_pad_loc_s);
                        tag_wen_s     <= '1';
                    end if;
                end if;

            -- Just send the length to tag ram.
            when ABSORB_LENGTH =>
                data_to_tag_s <= len_word_s;
                tag_wen_s     <= '1';

            -- As soon as bdi input doesn't match with calculated tag in ram,
            -- reset msg_auth.
            when VERIFY_TAG =>
                bdi_ready_s <= '1';
                if (bdi_valid = '1' and bdi_ready_s = '1' and bdi_type = HDR_TAG) then
                    if (bdi_s /= tag_dout_s) then
                        n_msg_auth_s <= '0';
                    end if;
                end if;

            -- Signal msg auth valid.
            when WAIT_ACK =>
                msg_auth_valid_s <= '1';

            when others =>
                null;

        end case;
    end process p_decoder;

    ----------------------------------------------------------------------------
    --! Word, Byte and Block counters
    ----------------------------------------------------------------------------
    GEN_p_counters_SYNC_RST : if not ASYNC_RSTN generate
        p_counters : process(clk)
        begin
            if rising_edge(clk) then
                if (rst = '1') then
                    word_cnt_s     <= 0;
                    block_cnt_s    <= to_unsigned(1, block_cnt_s'length);
                    ad_byte_cnt_s  <= (others => '0');
                    msg_byte_cnt_s <= (others => '0');
                else
                    word_cnt_s     <= word_cnt_s_next;
                    block_cnt_s    <= block_cnt_s_next;
                    ad_byte_cnt_s  <= ad_byte_cnt_s_next;
                    msg_byte_cnt_s <= msg_byte_cnt_s_next;
                end if;
            end if;
        end process p_counters;
    end generate GEN_p_counters_SYNC_RST;

    GEN_p_counters_ASYNC_RSTN : if ASYNC_RSTN generate
        p_counters : process(clk, rst)
        begin
            if (rst = '0') then
                word_cnt_s     <= 0;
                block_cnt_s    <= to_unsigned(1, block_cnt_s'length);
                ad_byte_cnt_s  <= (others => '0');
                msg_byte_cnt_s <= (others => '0');
            elsif rising_edge(clk) then
                word_cnt_s     <= word_cnt_s_next;
                block_cnt_s    <= block_cnt_s_next;
                ad_byte_cnt_s  <= ad_byte_cnt_s_next;
                msg_byte_cnt_s <= msg_byte_cnt_s_next;
            end if;
        end process p_counters;
    end generate GEN_p_counters_ASYNC_RSTN;

    p_counters_next : process(state_s, word_cnt_s, block_cnt_s, ad_byte_cnt_s, msg_byte_cnt_s, bdi_valid, bdi_ready_s, --
        key_valid, key_ready_s, bdo_valid_s, bdo_ready, bdi_eot, bdi_partial_s, hash_s, bdi_size, key_update) -- combinational
    begin
        -- defulat: no change
        word_cnt_s_next     <= word_cnt_s;
        block_cnt_s_next    <= block_cnt_s;
        ad_byte_cnt_s_next  <= ad_byte_cnt_s;
        msg_byte_cnt_s_next <= msg_byte_cnt_s;

        case state_s is
            -- Nothing to do here, reset counters
            when IDLE =>
                word_cnt_s_next     <= 0;
                block_cnt_s_next    <= to_unsigned(1, block_cnt_s'length);
                ad_byte_cnt_s_next  <= (others => '0');
                msg_byte_cnt_s_next <= (others => '0');

            -- If key is to be updated, increase counter on every successful
            -- data transfer (valid and ready), else just count the cycles required
            -- to move key from key_ram to tag_ram.
            when STORE_KEY =>
                if key_valid = '1' then
                    if word_cnt_s = BLOCK_WORDS_C - 1 then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            when RELOAD_KEY =>
                if word_cnt_s = BLOCK_WORDS_C - 1 then
                    word_cnt_s_next <= 0;
                else
                    word_cnt_s_next <= word_cnt_s + 1;
                end if;

            -- Every time a word is transferred, increase counter
            -- up to NPUB_WORDS_C
            when ABSORB_NONCE =>
                if (bdi_valid = '1' and bdi_ready_s = '1') then
                    if (word_cnt_s = NPUB_WORDS_C - 1) then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            -- On valid transfer, increase word counter until either
            -- the block size is reached or the last input word is obtained and the 0x80
            -- padding byte can already be inserted (indicated by last transfer being
            -- only partially filled -> bdi_eot and bdi_partial).
            -- Additionally count number of ad bytes.
            when ABSORB_AD =>
                if bdi_valid = '1' and bdi_ready_s = '1' then
                    if word_cnt_s = BLOCK_WORDS_C - 1 or (bdi_eot = '1' and bdi_partial_s = '1') then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                    ad_byte_cnt_s_next <= ad_byte_cnt_s + unsigned(bdi_size);
                end if;

            -- Increase word counter when transferring data.
            -- Reset word counter if block size is reached or the last msg word is received
            -- and only partially filled such that the 0x80 padding byte could be inserted.
            -- Additionally count number of msg bytes.
            when ABSORB_MSG =>
                if bdi_valid = '1' and bdi_ready_s = '1' then
                    if word_cnt_s = BLOCK_WORDS_C - 1 or (bdi_eot = '1' and bdi_partial_s = '1') then
                        word_cnt_s_next  <= 0;
                        block_cnt_s_next <= block_cnt_s + 1;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                    msg_byte_cnt_s_next <= msg_byte_cnt_s + unsigned(bdi_size);
                end if;

            -- Increase word counter when transferring data until either the block size
            -- for hash msg is reached or the last word is transferred and it's only
            -- partially filled (again such that 0x80 can be inserted).
            when ABSORB_HASH_MSG =>
                if (bdi_valid = '1' and bdi_ready_s = '1') then
                    if (word_cnt_s = HASH_WORDS_C - 1 or (bdi_eot = '1' and bdi_partial_s = '1')) then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            -- Reset word counters here. Due to 10* padding, only one 0x80
            -- Byte has to be inserted in this state.
            when PADD_AD | PADD_MSG | PADD_HASH_MSG =>
                word_cnt_s_next <= 0;

            -- Increase word counter up to block size or hash block size
            -- depending on whether input is currently hashed or not.
            when ABSORB_LENGTH | INIT_HASH =>
                if (word_cnt_s = BLOCK_WORDS_C - 1 and hash_s = '0') or (word_cnt_s = HASH_WORDS_C - 1 and hash_s = '1') then
                    word_cnt_s_next <= 0;
                else
                    word_cnt_s_next <= word_cnt_s + 1;
                end if;

            -- Increase word counter on valid bdo transfer until either
            -- block size or hash block size is reached depending on whether
            -- input is hashed or not.
            when EXTRACT_TAG =>
                if bdo_valid_s = '1' and bdo_ready = '1' then
                    if (word_cnt_s = BLOCK_WORDS_C - 1 and hash_s = '0') or (word_cnt_s = HASH_WORDS_C - 1 and hash_s = '1') then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            when EXTRACT_HASH_VALUE =>
                if bdo_valid_s = '1' and bdo_ready = '1' then
                    if word_cnt_s = HASH_WORDS_C - 1 then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            -- Increase word counter when transferring the received data (tag).
            when VERIFY_TAG =>
                if bdi_valid = '1' and bdi_ready_s = '1' then
                    if word_cnt_s = BLOCK_WORDS_C - 1 then
                        word_cnt_s_next <= 0;
                    else
                        word_cnt_s_next <= word_cnt_s + 1;
                    end if;
                end if;

            when others =>
                null;

        end case;
    end process p_counters_next;

    -- Cast the word counter to std_logic_vector for ram connection.
    ram_addr_s <= std_logic_vector(to_unsigned(word_cnt_s, ADDR_BITS_256_C));

    -- Resize the unsigned counters to 61 Bit and prepend three bit null vector to convert bytes to bit.
    ad_bit_cnt_vec_s  <= std_logic_vector(resize(ad_byte_cnt_s, ad_bit_cnt_vec_s'length - 3)) & "000";
    msg_bit_cnt_vec_s <= std_logic_vector(resize(msg_byte_cnt_s, msg_bit_cnt_vec_s'length - 3)) & "000";

    -- Concatenate the lengths (in bits) of ad and pt/ct for tag absorbtion. Reorder due to Endianess.
    -- Extract single word from len_s vector.
    len_s            <= reverse_bytes(msg_bit_cnt_vec_s) & reverse_bytes(ad_bit_cnt_vec_s);
    len_word_s       <= std_logic_vector(shift_right(unsigned(len_s), CCW * word_cnt_s)(CCW - 1 downto 0));
    -- Convert the block counter to a std_logic vector. Reorder due to Endianess.
    -- and extract single word from block_num_s vector.
    block_num_s      <= reverse_bytes(std_logic_vector(resize(block_cnt_s, block_num_s'length)));
    block_num_word_s <= std_logic_vector(shift_right(unsigned(block_num_s), CCW * word_cnt_s)(CCW - 1 downto 0));

end behavioral;
