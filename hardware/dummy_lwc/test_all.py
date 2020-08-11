#! /usr/bin/env python3
from pathlib import Path, PurePath, PurePosixPath
import json
import re
import subprocess
import os
import sys

script_dir = Path(__file__).parent.resolve()

try:
    import cryptotvgen
    from cryptotvgen import cli
except ImportError as e:
    print('cryptotvgen needs to be installed first!')
    print(' go to `LWC/software/cryptotvgen` directory and run `pip install .` or `pip install -e .` and then try running the script again.')
    raise e


# TODO use pytest?

# SETTINGS
# TODO add argeparse for settings?
core_src_path = script_dir / 'src_rtl'
lwc_root = script_dir.parents[1]
make_cmd = 'gmake'

print(f'script_dir={script_dir}')

sources_list = core_src_path / 'source_list.txt'
variables = {'LWCSRC_DIR': str(lwc_root / 'hardware' / 'LWCsrc')}
# END OF SETTINGS

cnd_dir = script_dir.parents[1] / 'software'

def build_libs():
    args = [
        '--prepare_libs',
        '--candidates_dir', str(lwc_root / 'software')
    ]
    cli.run_cryptotvgen(args)

def gen_tv(ccw, blocks_per_segment=None):
    dest_dir = f'KAT/KAT{"_MS" if blocks_per_segment else ""}_{ccw}'
    args = [
        '--lib_path', str(cnd_dir / 'lib'),
        '--aead', 'dummy_lwc',
        '--hash', 'dummy_lwc',
        '--io', str(ccw), str(ccw),
        '--key_size', '128',
        '--npub_size', '96',
        '--nsec_size', '0',
        '--message_digest_size', '256',
        '--tag_size', '128',
        '--block_size',    '128',
        '--block_size_ad', '128',
        '--dest', dest_dir,
        '--max_ad', '80',
        '--max_d', '80',
        '--max_io_per_line', '8',
        '--verify_lib',
    ]

    if blocks_per_segment:
        args += ['--max_block_per_sgmt', str(blocks_per_segment)]

    msg_format = '--msg_format npub ad data tag'.split()

    gen_test_combined = '--gen_test_combined 1 33 0'.split()
    # gen_hash = '--gen_hash 1 20 2'.split()
    args += msg_format
    args += gen_test_combined

    # TODO
    # args += gen_hash

    cli.run_cryptotvgen(args)


def get_lang(file: str):
    for ext in ['vhd', 'vhdl']:
        if file.endswith('.' + ext):
            return 'vhdl'
    if file.endswith('.v'):
        return 'verilog'
    if file.endswith('.sv'):
        return 'system-verilog'

# TODO
def gen_hdl_prj():
    with open(sources_list, 'r') as f:
        prj = {}
        prj['files'] = []
        data = f.read()
        for var, subst in variables.items():
            data = re.sub(r'\$\(' + var + r'\)', subst, data)
        for file in data.splitlines():
            if not PurePath(file).is_absolute():
                file = str(PurePath(core_src_path) / file)
            prj['files'].append({'file': file, 'language': get_lang(file)})
        prj["options"] = {
            "ghdl_analysis": [
                "--workdir=work",
                "-fexplicit"
            ]}
        with open('hdl-prj.json', 'w') as prj_file:
            json.dump(prj, prj_file, indent=2)


def test_all():
    vhdl_files = []
    verilog_files = []
    with open(sources_list, 'r') as f:
        prj = {}
        prj['files'] = []
        data = f.read()
        for var, subst in variables.items():
            data = re.sub(r'\$\(' + var + r'\)', subst, data)

        for file in data.splitlines():
            if not PurePath(file).is_absolute():
                file = str(PurePath(core_src_path) / file)
            if get_lang(file) == 'vhdl':
                vhdl_files.append(file)
            if get_lang(file) == 'verilog':
                verilog_files.append(file)
    # print(f'VHDL_FILES={vhdl_files}')

    orig_design_pkg = (core_src_path / 'design_pkg.vhd').resolve()

    param_variants = [(32, 32), (32, 16), (32, 8), (16, 16), (8, 8)]

    for ms in [False, True]:
        for w, ccw in param_variants:
            gen_tv(ccw, 2 if ms else None)
            # TODO impl in python
            replaced_design_pkg = (core_src_path / f'design_pkg_{ccw}.vhd').resolve()
            os.system(f"sed 's/:= dummy_lwc_.*/:= dummy_lwc_{ccw};/' {orig_design_pkg} > {replaced_design_pkg}")
            cfg_vhdl_files = [str(replaced_design_pkg) if Path(
                f).resolve().samefile(orig_design_pkg) else f for f in vhdl_files]
            cmd = [make_cmd, 'sim-ghdl',
                   f"VHDL_FILES={' '.join(cfg_vhdl_files)}",
                   f"VERILOG_FILES={' '.join(verilog_files)}",
                   f"CONFIG_LOC=configs/{w}{'MS' if ms else ''}config.ini",
                   "REBUILD=1"]
            print(f'running `{" ".join(cmd)}` in {core_src_path}')
            cp = subprocess.run(cmd, cwd=core_src_path)
            cp.check_returncode()


if __name__ == "__main__":
    build_libs()
    test_all()
