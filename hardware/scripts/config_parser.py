import configparser

def ghdl_generics(config):
    return ' '.join(["-g" + k + "=" + v.strip().strip('"') for k, v in config.items('Generics')])

if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.optionxform = str
    config.sections()
    config.read('config.ini')
    print(ghdl_generics(config))
