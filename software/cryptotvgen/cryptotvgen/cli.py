#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import errno
import os
import pathlib
import sys
import textwrap
from typing import Union

from .generator import (
    determine_params,
    gen_benchmark_routine,
    gen_dataset,
    gen_hash,
    gen_random,
    gen_single,
    gen_test_combined,
    gen_test_routine,
    gen_tv_and_write_files,
)

from .log import setup_logger
from .options import get_parser
from .prepare_libs import ctgen_get_supercop_dir, prepare_libs


## validation can only be safely done when all args are parsed and stored!
def run_cryptotvgen(
    args=None, logfile: Union[None, str, os.PathLike] = "cryptotvgen.log"
):
    """main entry function"""
    if args is None:
        args = []
    # Parse options
    parser = get_parser()
    opts = parser.parse_args(args)

    setup_logger(logfile=logfile)

    if opts.prepare_libs:
        prepare_libs(
            sc_version=opts.supercop_version,
            libs=opts.prepare_libs,
            candidates_dir=opts.candidates_dir,
            lib_path=opts.lib_path,
        )
        return 0
    try:
        routines = opts.routines
    except AttributeError:
        error_txt = textwrap.dedent(
            """

                    Please specify at least one of the run modes:
                        --prepare_libs, --gen_test_routine, --gen_random, --gen_custom, or --gen_single.

                    """
        )
        sys.exit(error_txt)

    if not opts.candidates_dir:
        opts.candidates_dir = ctgen_get_supercop_dir()

    # Automatically fill in any missing parameters from 'api.h'
    determine_params(opts)

    # Additional error checking
    opts.msg_format = list(opts.msg_format)
    if opts.offline:
        opts.msg_format = ["len"] + opts.msg_format
    if opts.ciph_exp_noext and not opts.ciph_exp:
        parser.error("Option --ciph_ext_noext requires --ciph_exp")
    if opts.add_partial and not opts.ciph_exp:
        parser.error("Option --add_partial requires --ciph_exp")

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

    if opts.candidates_dir and not opts.lib_path:
        opts.lib_path = pathlib.Path(opts.candidates_dir) / "lib"

    for routine in opts.routines:
        if routine == 0:
            data = gen_random(opts, msg_no, key_no)
        elif routine == 1:
            data = gen_dataset(
                opts, opts.gen_custom, msg_no, key_no, opts.gen_custom_mode
            )
        elif routine == 2:
            data = gen_test_routine(opts, msg_no, key_no)
        elif routine == 3:  # Single
            data = gen_single(opts, msg_no, key_no, gen_single_index)
            gen_single_index += 1
        elif routine == 4:  # Hash
            data = gen_hash(opts, msg_no)
        elif routine == 5:  # Combined AEAD and Hash
            data = gen_test_combined(opts, msg_no, key_no)
        elif routine == 6:
            gen_benchmark_routine(opts)
            return 0

        dataset += data[0]
        msg_no = data[1] + 1
        key_no = data[2] + 1

    gen_tv_and_write_files(opts, dataset)
    print(
        "Done! Please visit destination folder\n\t"
        "{}\n"
        "for generated files (pdi.txt, sdi.txt, and do.txt)".format(
            os.path.abspath(opts.dest)
        )
    )
    return 0


if __name__ == "__main__":
    run_cryptotvgen(sys.argv[1:])
