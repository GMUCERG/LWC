#!/usr/bin/env python3
# requires  Python 3.6+

import secrets
import argparse
from pathlib import Path
from functools import reduce
import sys

parser = argparse.ArgumentParser(
    description='Generates shared testvectors and RDI')


def xor(l, r):
    return bytes(a ^ b for a, b in zip(l, r))


def gen_shares(in_file, num_shares, w_nbytes=0):
    in_path = Path(in_file.name)
    out_file = in_path.parent / (in_path.stem + f"_shared_{num_shares}.txt")
    print(out_file, num_shares)
    with open(out_file, 'w') as o:
        o.write(
            f"#\n# Shared version of {in_path.name} split into {num_shares} shares\n#\n")
        for line in in_file.readlines():
            if len(line) > 6:
                preamble = line[:6]
                data = line[6:].strip()
                if preamble == "HDR = " or preamble == "INS = ":  # set other shares to zeros
                    line = preamble + data + \
                        ("0" * (num_shares - 1) * len(data)) + "\n"
                    if w_nbytes == 0:
                        w_nbytes = (len(data) + 1) // 2
                elif preamble == "DAT = ":
                    data_bytes = bytes.fromhex(data)
                    data_str = ""
                    for i in range(0, len(data_bytes), w_nbytes):
                        word = data_bytes[i:i+w_nbytes]
                        shares = [secrets.token_bytes(
                            w_nbytes) for _ in range(num_shares - 1)]
                        shares.append(reduce(xor, shares + [word]))
                        # assert reduce(xor, shares) == word
                        data_str += "".join([x.hex().upper() for x in shares])
                    line = preamble + data_str + "\n"
            o.write(line)


parser.add_argument(
    '--rdi-file', default=None, type=argparse.FileType('w'),
    help='path to generated rdi.txt')
parser.add_argument(
    '--pdi-file', default=None, type=argparse.FileType('r'),
    help='path to unshared pdi.txt')
parser.add_argument(
    '--sdi-file', default=None, type=argparse.FileType('r'),
    help='path to unshared sdi.txt')
parser.add_argument('--rdi-width', default=None, required='--rdi-file' in sys.argv, type=int,
                    help='width of RDI data port in bits (RW)')
parser.add_argument('--pdi-width', default=None, type=int,
                    help='width of PDI data port in bits (W)')
parser.add_argument('--sdi-width', default=None, type=int,
                    help='width of SDI data port in bits (SW)')
parser.add_argument('--pdi-shares', default=None, required='--pdi-file' in sys.argv, type=int,
                    help='number of PDI shares')
parser.add_argument('--sdi-shares', default=None, type=int,
                    help='number of SDI shares')
parser.add_argument('--rdi-words', default=200000,
                    type=int, help='number of RDI words')

args = parser.parse_args()

if len(sys.argv)==1:
    parser.print_help()
    parser.exit()

if args.rdi_file:
    if not args.rdi_width:
        print("--rdi-width <RW> (RW > 0) must be specified!")
        exit(1)
    rw_bytes = (args.rdi_width + 7) // 8  # round to bytes
    for i in range(args.rdi_words):
        args.rdi_file.write(secrets.token_hex(rw_bytes).upper() + '\n')
    print(
        f"Generated RDI file: {args.rdi_file.name} RW={args.rdi_width} words={args.rdi_words}")

if args.pdi_file:
    if not args.pdi_shares or args.pdi_shares < 2:
        print("--pdi-shares <N> must be specified and N > 1!")
        exit(1)
    nbytes = 0  # auto
    if args.pdi_width:
        nbytes = (args.pdi_width + 7) // 8
    gen_shares(args.pdi_file, args.pdi_shares, nbytes)

if args.sdi_file:
    if not args.sdi_shares or args.sdi_shares < 2:
        if args.pdi_shares:
            args.sdi_shares = args.pdi_shares
            print(
                f"sdi-shares not specified. Using default value of pdi-shares={args.pdi_shares}")
        else:
            print("--sdi-shares <SN> must be specified and SN >= 1!")
            exit(1)
    nbytes = 0  # auto
    if args.pdi_width:
        nbytes = (args.pdi_width + 7) // 8
    gen_shares(args.sdi_file, args.sdi_shares, nbytes)
