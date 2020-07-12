#!/usr/bin/env python3

import configparser
import sys
from sys import argv

def quote_strings(x):
    if isinstance(x, str):
        return f'\\"{x}\\"'
    else:
        return str(x)

def ghdl_generics(config):
    return ' '.join([ f"-g{k}={v}" for k, v in config.items('Generics')])

def vcs_generics(config):
    return ' '.join([f"-gv {k}={quote_strings(v)}" for k, v in config.items('Generics')])

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
        elif argv[1] == 'test':
            print("OK")
        else:
            sys.exit(f'[ERROR] config_parser.py: unknown args {argv[1]}\n')
