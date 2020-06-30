import configparser
from sys import argv

def ghdl_generics(config):
    return ' '.join(["-g" + k + "=" + v.strip().strip('"') for k, v in config.items('Generics')])

def vcs_generics(config):
    return ' '.join([f"-gv {k}=\\\"{v}\\\"" for k, v in config.items('Generics')])

if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.optionxform = str
    config.sections()

    if len(argv) < 2 or len(argv) > 3 :
        print('[ERROR] need 1 or 2 args: cmd <config.ini>')
        exit(1)
    
    config_file = argv[2] if len(argv) == 3 else 'config.ini'
    
    config.read(config_file)
    
    if argv[1] == 'ghdl_generics':
        print(ghdl_generics(config))    
    elif argv[1] == 'vcs_generics':
        print(vcs_generics(config))
    else:
        print('[ERROR] unknown arg')