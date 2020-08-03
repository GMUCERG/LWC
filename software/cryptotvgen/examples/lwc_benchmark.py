#!/usr/bin/env python3
# -*- coding: utf-8 -*

import copy
import os
import sys
try:
    from cryptotvgen import cryptotvgen
except:
    sys.exit("cryptotvgen note installed")

# Algorithm information required
dest_folder = "testvectors/dummy_lwc_32"
base_lib_path = os.path.realpath('../../prepare_src/libs') # Library path
aead_lib_name = 'dummy_lwc--ref'  # Library name of AEAD algorithm
# Comment out if not supported
hash_lib_name = 'dummy_lwc--ref'  # Library name of hash algorithm
PDI_width = 32 # I/O width: PDI/DO bits
SDI_width = 32 # I/O width: SDI bits
key_size = 128 # bits
npub_size = 96 # bits
nsec_size = 0  # bits
tag_size = 128 # bits
block_size_message  = 128 # bits
block_size_ad = 128 # bits
block_size_msg_digest = 256 # bits

# Typically message come in the order. Update if necessary(unlikely)
msg_format = '--msg_format npub ad data tag'.split()

def gen_custom_string_aead(new_key, enc_dec):
        # only ad
        gen_string = ""
        gen_string += f"{new_key},{enc_dec},{5*block_size_ad//8},                        0,0:"
        gen_string += f"{new_key},{enc_dec},{4*block_size_ad//8},                        0,0:"
        gen_string += f"{new_key},{enc_dec},                1536,                        0,0:"
        gen_string += f"{new_key},{enc_dec},                  64,                        0,0:"
        gen_string += f"{new_key},{enc_dec},                  16,                        0,0:"
        gen_string += f"{new_key},{enc_dec},                   0,{5*block_size_message//8},0:"
        gen_string += f"{new_key},{enc_dec},                   0,{4*block_size_message//8},0:"
        gen_string += f"{new_key},{enc_dec},                   0,                     1536,0:"
        gen_string += f"{new_key},{enc_dec},                   0,                       64,0:"
        gen_string += f"{new_key},{enc_dec},                   0,                       16,0:"
        gen_string += f"{new_key},{enc_dec},{5*block_size_ad//8},{5*block_size_message//8},0:"
        gen_string += f"{new_key},{enc_dec},{4*block_size_ad//8},{4*block_size_message//8},0:"
        gen_string += f"{new_key},{enc_dec},                1536,                     1536,0:"
        gen_string += f"{new_key},{enc_dec},                  64,                       64,0:"
        gen_string += f"{new_key},{enc_dec},                  16,                       16,0:"
        return gen_string

def gen_custom_string_hash():
        hash_string = ""
        hash_string += f"0,0,{5*block_size_msg_digest//8},0,1:"
        hash_string += f"0,0,{4*block_size_msg_digest//8},0,1:"
        hash_string += f"0,0,1536,0,1:"
        hash_string += f"0,0,64,0,1:"
        hash_string += f"0,0,16,0,1:"
        return hash_string

def finish_custom():
    # Final message must not contain ":" at the end
    return "0,0,0,0,0"

def blanket_message_test():
    return_string = ""
    for ad_size in range(2*block_size_ad//8):
        for mess_size in range(2*block_size_message//8):
            return_string+=f"1,0,{ad_size},{mess_size},0:"
    return return_string

if __name__ == '__main__':
    # Print the help text
    if (len(sys.argv) > 1 and sys.argv[1] == '-h'):
        sys.exit(cryptotvgen(sys.argv))

    # Create the list of arguments for cryptotvgen
    args = [
        base_lib_path, 
        '--aead', aead_lib_name,
        '--io', f'{PDI_width}', f'{SDI_width}',
        '--key_size', f'{key_size}',
        '--npub_size', f'{npub_size}',
        '--nsec_size', f'{nsec_size}',
        '--tag_size', f'{tag_size}',
        '--max_io_per_line', '8',
        '--human_readable', '--verify_lib',
        ]
    if hash_lib_name is not None:
        args += ['--hash', hash_lib_name,]
    orig_args = copy.deepcopy(args)

    # Desired measurements with new key every time
    args += msg_format + ['--dest', os.path.join(dest_folder,"throughput_new_key")]
    gen_cus_string = gen_custom_string_aead(1,0) + gen_custom_string_aead(1,1)
    if hash_lib_name is not None:
        gen_cus_string += gen_custom_string_hash() + finish_custom()
    else:
        gen_cus_string += finish_custom()
    args += ['--gen_custom', gen_cus_string]
    cryptotvgen(args)

    # Desired measurements using the same key every time
    args = orig_args
    args += msg_format + ['--dest', os.path.join(dest_folder,"throughput_reuse_key")]
    # First message is just providing the new key
    gen_cus_string = "1,0,0,0,0:" + gen_custom_string_aead(0,0) + gen_custom_string_aead(0,1)
    gen_cus_string += finish_custom()
    args += ['--gen_custom', gen_cus_string]
    cryptotvgen(args)

    args = orig_args
    args += msg_format + ['--dest', os.path.join(dest_folder,"blanket_support_test")]
    gen_cus_string = blanket_message_test() + finish_custom()
    args += ['--gen_custom', gen_cus_string]
    cryptotvgen(args)

     



