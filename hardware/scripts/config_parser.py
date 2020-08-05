#!/usr/bin/env python3

import configparser
import sys
from sys import argv

def quote_strings(x):
    return f'\\"{x}\\"'

def bool_to_bit(x):
    xl = x.strip().lower()
    if xl == 'false':
        return "1\\'b0"
    if xl == 'true':
        return "1\\'b1"
    return x

def ghdl_generics(config):
    return ' '.join([f"-g{k}={v}" for k, v in config.items('Generics')])

def vcs_generics(config):
    return ' '.join([f"-gv {k}={quote_strings(v)}" for k, v in config.items('Generics')])

# Vivado only support passing numeric generics, either integer or verilog style bit vector
def vivado_generics(config):
    return ' '.join([f"-generic {k}={bool_to_bit(v)}" for k, v in config.items('Generics') if v.isnumeric() or (v.strip().lower() in {'true', 'false'}) ])

def variables(config):
    # TODO rewrite the whole script with hierarchical parsing and better error handling!
    if not config.has_section('Variables'):
        return " "
    return '\n'.join([f"{k}={v}" for k, v in config.items('Variables')])

if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.optionxform = str
    config.sections()

    if len(argv) < 2 or len(argv) > 3 :
        sys.exit('[ERROR] config_parser.py: need either 1 or 2 args: cmd <config.ini>')
    
    config_file = argv[2] if len(argv) == 3 else 'config.ini'
    
    with open(config_file) as cf:
        config.read_file(cf)
        
        if argv[1] == 'ghdl_generics':
            print(ghdl_generics(config))    
        elif argv[1] == 'vcs_generics':
            print(vcs_generics(config))           
        elif argv[1] == 'vivado_generics':
            print(vivado_generics(config))    
        elif argv[1] == 'test':
            print("OK")
        elif argv[1] == 'vars':
            print(variables(config))
        else:
            sys.exit(f'[ERROR] config_parser.py: unknown args {argv[1]}\n')
