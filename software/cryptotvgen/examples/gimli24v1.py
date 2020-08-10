#!/usr/bin/env python3
# -*- coding: utf-8 -*


# Example script to create test vectors for gimli

import os
import sys

from cryptotvgen import cli

if __name__ == '__main__':
    # ========================================================================
    # Create the list of arguments for cryptotvgen
    args = [
        '--aead', 'gimli24v1',              # Library name of AEAD algorithm (variant name)
        '--hash', 'gimli24v1',              # Library name of Hash algorithm (variant name)
        '--io', '32', '32',                 # I/O width: PDI/DO and SDI widt h, respectively.
        '--key_size', '256',                # Key size
        '--npub_size', '128',               # Npub size
        '--nsec_size', '0',                 # Nsec size
        '--message_digest_size', '256',     # Hash tag
        '--tag_size', '128',                # Tag size
        '--block_size',    '128',           # Data block size
        '--block_size_ad', '128',           # AD block size
        # '--ciph_exp',                     # Ciphertext expansion
        # '--add_partial',                  # ciph_exp option: add partial bit
        # '--ciph_exp_noext',               # ciph_exp option: no block extension when a message is a multiple of a block size
        # '--offline',                      # Offline cipher (Adds Length segment as the first input segment)
        '--dest', 'testvectors/gimli24v1',  # destination folder
        '--max_ad', '80',                   # Maximum random AD size
        '--max_d', '80',                    # Maximum random message size
        '--max_io_per_line', '8',           # Max number of w-bit I/O word per line
        '--human_readable',                 # Generate a human readable text file
        '--verify_lib',                     # Verify reference enc/dec in reference code
                                            # Note: (This option performs decryption for
                                            #        each encryption operation used to
                                            #        create the test vector)
    ]
    # ========================================================================
    # Alternative way of creating an option argument
    #   message format
    msg_format = '--msg_format npub ad data tag'.split()
    #   Run routine (add at least one to args array)
    #
    #   Note: All the encrypt and decrypt operation specifiers refer to the
    #   input test vector  for hardware core. The actual process in the
    #   preparation of the test vector is based only on the encryption operation.
    gen_test_routine = '--gen_test_routine 1 20 0'.split()
    gen_random = '--gen_random 10'.split()

    # Format: new key (bool), decrypt (bool), AD_LEN, PT_LEN, HASH (bool)
    gen_custom = ['--gen_custom',   
        '''\
        True,   False,      0,          20,     False:
        1,      0,          5,          10,     0
        ''']
    gen_single = ['--gen_single',
        '1',                                                                # AEAD Encrypt(0)/AEAD Decrypt(1)/Hash(2)
        '000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F', #Key
        '000102030405060708090A0B0C0D0E0F',                                 #Npub
        '000102030405060708090A0B0C0D0E0F',                                 #Nsec (Ignored: nsec_size=0)
        '000102030405060708090A0B0C0D0E0F',                                 #AD
        '000102030405060708090A0B0C0D0E0F',                                 #DATA
        ]

    gen_test_combined = '--gen_test_combined 1 33 0'.split()
    gen_hash = '--gen_hash 1 20 2'.split()
    # ========================================================================
    # Add option arguments together
    args += msg_format
    args += gen_test_combined
    ## Add other test routines below
    # args += gen_hash       
    # ========================================================================
    # Pass help flag through
    try:
        if (sys.argv[1] == '-h'):
            args.append('-h')
    except:
        pass
    # Call program
    cli.run_cryptotvgen(args)
