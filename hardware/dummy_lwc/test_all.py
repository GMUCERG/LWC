#! /usr/bin/env python3
from pathlib import Path, PurePath, PurePosixPath
import json
import re
import subprocess
import shutil
import sys

script_dir = Path(__file__).parent.resolve()

try:
    import cryptotvgen
    from cryptotvgen import cli
except ImportError as e:
    print('cryptotvgen is not installed!')
    print('Please go to `$(LWC_ROOT)/software/cryptotvgen` directory and run `pip install .` or `pip install -e .` and then try running the script again.')
    raise e


# TODO use pytest?

# SETTINGS
# TODO add argeparse for settings?
core_src_path = script_dir
lwc_root = script_dir.parents[1]
make_cmd = 'make'

print(f'script_dir={script_dir}')

sources_list = core_src_path / 'source_list.txt'
variables = {'LWCSRC_DIR': str(lwc_root / 'hardware' / 'LWCsrc')}
# END OF SETTINGS

cnd_dir = lwc_root / 'software' / 'dummy_lwc_ref'


def build_libs():
    args = [
        '--prepare_libs',
        '--candidates_dir', str(cnd_dir)
    ]
    return cli.run_cryptotvgen(args)


gen_tv_subfolder = Path('generated_tv').resolve()
gen_configs_subfolder = Path('generated_config').resolve()
gen_configs_subfolder.mkdir(exist_ok=True)


def gen_tv(ccw, blocks_per_segment, dest_dir):
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
        '--dest', str(dest_dir),
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

    return cli.run_cryptotvgen(args)


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

    orig_design_pkg = None
    orig_lwapi_pkg = None

    for f in vhdl_files:
        f_path = Path(f).resolve()
        if f_path.name.lower() == 'design_pkg.vhd':
            orig_design_pkg = f_path
        if f_path.name.lower() == 'nist_lwapi_pkg.vhd':
            orig_lwapi_pkg = f_path

    if not orig_design_pkg:
        sys.exit(f"'design_pkg.vhd' not found in VHDL files of sources.list!")
    if not orig_lwapi_pkg:
        sys.exit(f"'NIST_LWAPI_pkg.vhd' not found in VHDL files of sources.list!")

    param_variants = [(32, 32), (32, 16), (32, 8), (16, 16), (8, 8)]

    orig_config_ini = (core_src_path / 'config.ini').resolve()

    def gen_from_template(orig_filename, gen_filename, changes):
        with open(orig_filename, 'r') as orig:
            content = orig.read()
            for old, repl in changes:
                content = re.sub(old, repl, content)
        with open(gen_filename, 'w') as gen:
            gen.write(content)

    # TODO run other targets as well
    make_goal = 'sim-ghdl'

    results_dir = Path('testall_results').resolve()
    results_dir.mkdir(exist_ok=True)
    logs_dir = Path('testall_logs').resolve()
    logs_dir.mkdir(exist_ok=True)

    generated_sources = (core_src_path / 'generated_srcs')
    generated_sources.mkdir(exist_ok=True)


    for vhdl_std in ['93', '08']:
        for ms in [False, True]:
            replace_files_map = {}
            for w, ccw in param_variants:
                replaced_lwapi_pkg = (
                    generated_sources / f'NIST_LWAPI_pkg_W{w}.vhd').resolve()
                lwapi_pkg_changes = [
                    (r'(constant\s+W\s*:\s*integer\s*:=\s*)(\d+)(\s*;)', f'\\g<1>{w}\\g<3>')
                ]
                gen_from_template(orig_lwapi_pkg, replaced_lwapi_pkg, lwapi_pkg_changes)
                replace_files_map[orig_lwapi_pkg] = replaced_lwapi_pkg

                for async_rstn in [False, True]:
                    print(f'\n\n{"="*12}- Testing vhdl_std={vhdl_std} ms={ms} w={w} ccw={ccw} async_rstn={async_rstn} -{"="*12}\n')
                    gen_tv_dir = gen_tv_subfolder / f'TV{"_MS" if ms else ""}_{w}'
                    gen_tv(w, 2 if ms else None, gen_tv_dir)

                    replaced_design_pkg = (
                        generated_sources / f'design_pkg_{ccw}{"_arstn" if async_rstn else ""}.vhd').resolve()
                    design_pkg_changes = [
                        (r'(constant\s+variant\s+:\s+set_selector\s+:=\s+)dummy_lwc_.*;', f'\\g<1>dummy_lwc_{ccw};'),
                        (r'(constant\s+ASYNC_RSTN\s+:\s+boolean\s+:=\s+).*;', f'\\g<1>{async_rstn};')
                    ]
                    gen_from_template(orig_design_pkg, replaced_design_pkg, design_pkg_changes)
                    replace_files_map[orig_design_pkg] = replaced_design_pkg

                    # TODO alternatively, parse config.ini and generate anew
                    generated_config_ini = gen_configs_subfolder / \
                        f"config_{w}{'_MS' if ms else ''}_vhdl{vhdl_std}.ini"
                    config_ini_changes = [
                        (r'(G_W\s*=\s*)\d+', f'\\g<1>{w}'),
                        (r'(G_SW\s*=\s*)\d+', f'\\g<1>{w}'),
                        (r'(G_FNAME_PDI\s*=\s*).*', f'\\g<1>"{gen_tv_dir}/pdi.txt"'),
                        (r'(G_FNAME_SDI\s*=\s*).*', f'\\g<1>"{gen_tv_dir}/sdi.txt"'),
                        (r'(G_FNAME_DO\s*=\s*).*', f'\\g<1>"{gen_tv_dir}/do.txt"'),
                        (r'(G_FNAME_LOG\s*=\s*).*',
                         f'\\g<1>\"{logs_dir}/log_W{w}_CCW{ccw}{"_ASYNCRSTN" if async_rstn else ""}{"_MS" if ms else ""}_VHDL{vhdl_std}.txt\"'),
                        (r'(G_FNAME_RESULT\s*=\s*).*',
                         f'\\g<1>\"{results_dir}/result_W{w}_CCW{ccw}{"_ASYNCRSTN" if async_rstn else ""}{"_MS" if ms else ""}_VHDL{vhdl_std}.txt\"'),
                        (r'(VHDL_STD\s*=\s*).*', f'\\g<1>{vhdl_std}'),
                    ]
                    gen_from_template(orig_config_ini, generated_config_ini, config_ini_changes)

                    def replace_file(f):
                        for orig in replace_files_map.keys():
                            if Path(f).resolve().samefile(orig):
                                return replace_files_map[orig]
                        return f

                    cfg_vhdl_files = [str(replace_file(f)) for f in vhdl_files]

                    cmd = [make_cmd, make_goal,
                           f"VHDL_FILES={' '.join(cfg_vhdl_files)}",
                           f"VERILOG_FILES={' '.join(verilog_files)}",
                           f"CONFIG_LOC={generated_config_ini}",
                           "REBUILD=1"
                           ]
                    print(f'running `{" ".join(cmd)}` in {core_src_path}')
                    cp = subprocess.run(cmd, cwd=core_src_path)
                    cp.check_returncode()
                    cp = subprocess.run([make_cmd, 'clean-ghdl'], cwd=core_src_path)


if __name__ == "__main__":
    build_libs()
    test_all()
