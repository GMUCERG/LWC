#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from .generator import gen_dataset, gen_hash, gen_random, gen_single, gen_test_combined, gen_test_routine, print_header
from .options import get_parser
from .prepare_libs import build_supercop_libs
import textwrap
import os
import sys
import errno

def run_cryptotvgen(args=sys.argv[1:]):
    # Parse options
    parser = get_parser()
    opts = parser.parse_args(args)
    
    if opts.prepare_libs:
        build_supercop_libs(sc_version='20200702', libs=opts.prepare_libs)
        sys.exit()
    
    try:
        routines = opts.routines
    except AttributeError:
        error_txt = textwrap.dedent('''

                    Please specify at least one of the run modes:
                        --prepare_libs, --gen_test_routine, --gen_random, --gen_custom, or --gen_single.

                    ''')
        sys.exit(error_txt)
        
    # Additional error checking
    if (opts.offline):
        opts.msg_format = ['len'] + opts.msg_format
    if (opts.ciph_exp_noext and not opts.ciph_exp):
        parser.error('Option --ciph_ext_noext requires --ciph_exp')
    if (opts.add_partial and not opts.ciph_exp):
        parser.error('Option --add_partial requires --ciph_exp')

    if not os.path.exists(opts.dest):
        try:
            os.makedirs(opts.dest)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise

    # Generate Input Test Vectors
    dataset = []
    msg_no = 1
    key_no = 1
    gen_single_index = 0
    

    for routine in opts.routines:
        if routine == 0:
            data = gen_random(opts, msg_no, key_no)
        elif routine == 1:
            data = gen_dataset(opts, opts.gen_custom, msg_no, key_no, opts.gen_custom_mode)
        elif routine == 2:
            data = gen_test_routine(opts, msg_no, key_no)
        elif routine == 3:   # Single
            data = gen_single(opts, msg_no, key_no, gen_single_index)
            gen_single_index += 1
        elif routine == 4:   # Hash
            data = gen_hash(opts, msg_no)
        else:                # Combined AEAD and Hash
            data = gen_test_combined(opts, msg_no, key_no)

        dataset += data[0]
        msg_no = data[1]+1
        key_no = data[2]+1

    print_header(opts)
    for tv in dataset:
        tv.gen_tv()
        tv.gen_nist_tv()
        tv.gen_cc_hls()

    # Add EOF tag
    for file_name in [opts.pdi_file, opts.do_file, opts.sdi_file]:
        file_path = os.path.join(opts.dest, file_name)
        with open(file_path, 'a') as f:
            f.write('###EOF\n')

    print("Done! Please visit destination folder\n\t"
          "{}\n"
          "for generated files (pdi.txt, sdi.txt, and do.txt)".format(os.path.abspath(opts.dest)))

if __name__ == '__main__':
    import sys
    run_cryptotvgen(sys.argv[1:])

