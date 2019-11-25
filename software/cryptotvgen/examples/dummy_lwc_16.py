#!/usr/bin/env python3
# -*- coding: utf-8 -*

import os
import sys


try:
    from cryptotvgen import cryptotvgen
except ImportError:
    print("================================================================")
    print("Warning: cryptotvgen not installed!!!! Use source package instead.")
    print("================================================================")
    sys.path.append(os.path.abspath('..'))
    from cryptotvgen import cryptotvgen

if __name__ == '__main__':
    # ========================================================================
    # Create the list of arguments for cryptotvgen
    args = [
        os.path.realpath('../../prepare_src/libs'),     # Library path
        '--aead', 'dummy_lwc--ref',                     # Library name of AEAD algorithm (<algorithm_name>--<implementation_name>)
        '--hash', 'dummy_lwc--ref',                     # Library name of Hash algorithm (<algorithm_name>--<implementation_name>)
        '--io', '16', '16',                             # I/O width: PDI/DO and SDI width, respectively.
        '--key_size', '128',                            # Key size
        '--npub_size', '96',                            # Npub size
        '--nsec_size', '0',                             # Nsec size
        '--message_digest_size', '256',                 # Hash tag
        '--tag_size', '128',                            # Tag size
        '--block_size',    '128',                       # Data block size
        '--block_size_ad', '128',                       # AD block size
        # '--ciph_exp',                                 # Ciphertext expansion
        # '--add_partial',                              # ciph_exp option: add partial bit
        # '--ciph_exp_noext',                           # ciph_exp option: no block extension when a message is a multiple of a block size
        # '--offline',                                  # Offline cipher (Adds Length segment as the first input segment)
        '--dest', 'testvectors/dummy_lwc_16',           # destination folder
        '--max_ad', '80',                               # Maximum random AD size
        '--max_d', '80',                                # Maximum random message size
        '--max_io_per_line', '8',                       # Max number of w-bit I/O word per line
        '--human_readable',                             # Generate a human readable text file
        '--verify_lib',                                 # Verify reference enc/dec in reference code
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

    # new key (bool), decrypt (bool), AD_LEN, PT_LEN, hash-mode (bool)
    gen_custom = ['--gen_custom',
        '''\
        True,   False,      0,          20,         False:
        0,      1,          100,        500,        0
        ''']
    gen_single = ['--gen_single',
        '1',                                # AEAD Encrypt(0)/AEAD Decrypt(1)/Hash(2)
        '000102030405060708090A0B0C0D0E0F', #Key
        '000102030405060708090A0B',         #Npub
        '000102030405060708090A0B0C0D0E0F', #Nsec (Ignored: nsec_size=0)
        '000102030405060708090A0B0C0D0E0F', #AD
        '000102030405060708090A0B0C0D0E0F', #DATA
        ]
    gen_single_hash = ['--gen_single',
        '2',                                # AEAD Encrypt(0)/AEAD Decrypt(1)/Hash(2)
        '00000000000000000000000000000000', #Key
        '000000000000000000000000',         #Npub
        '00000000000000000000000000000000', #Nsec (Ignored: nsec_size=0)
        '00000000000000000000000000000000', #AD
        '000102030405060708090A0B0C0D0E0F', #DATA
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
    cryptotvgen(args)
