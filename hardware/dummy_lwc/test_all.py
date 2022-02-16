#! /usr/bin/env python3
from copy import copy
from pathlib import Path
import re
import logging


from cryptotvgen import cli

from xeda.flow_runner import DefaultRunner
from xeda.flows import GhdlSim
from xeda import load_design_from_toml

logger = logging.getLogger()

xeda_runner = DefaultRunner()


logger.setLevel(logging.WARNING)

script_dir = Path(__file__).parent.resolve()
print(f'script_dir={script_dir}')

ghdl_setting_overrides = {'warn_flags': [
    '-Wno-runtime-error',
    '--warn-binding',
    '--warn-default-binding',
    '--warn-reserved',
    '--warn-library',
    '--warn-vital-generic',
    '--warn-shared',
    # '--warn-runtime-error',
    # '--warn-static',
    '--warn-body',
    '--warn-specs',
    '--warn-unused',
    '--warn-parenthesis'
],
    'wave': False
}

# TODO use pytest?

# SETTINGS
# TODO add argeparse for settings?
core_src_path = script_dir
lwc_root = script_dir.parents[1]


tvgen_cand_dir = lwc_root / 'software' / 'dummy_lwc_ref'


def build_libs():
    args = [
        '--prepare_libs',
        '--candidates_dir', str(tvgen_cand_dir)
    ]
    return cli.run_cryptotvgen(args)


gen_tv_subfolder = Path('generated_tv').resolve()
gen_configs_subfolder = Path('generated_config').resolve()
gen_configs_subfolder.mkdir(exist_ok=True)


def gen_tv(ccw, blocks_per_segment, dest_dir, bench=False):
    args = [
        '--lib_path', str(tvgen_cand_dir / 'lib'),
        '--aead', 'dummy_lwc',
        '--hash', 'dummy_lwc',
        '--io', str(ccw), str(ccw),
        '--key_size', '128',
        '--npub_size', '96',
        '--nsec_size', '0',
        '--message_digest_size', '256',
        '--tag_size', '128',
        '--block_size', '128',
        '--block_size_ad', '128',
        '--block_size_msg_digest', '128',
        '--dest', str(dest_dir),
        '--max_ad', '80',
        '--max_d', '80',
        '--max_io_per_line', '8',
        '--verify_lib',
    ]

    if blocks_per_segment:
        args += ['--max_block_per_sgmt', str(blocks_per_segment)]

    msg_format = '--msg_format npub ad data tag'.split()

    # gen_hash = '--gen_hash 1 20 2'.split()
    args += msg_format
    if bench:
        args += ['--gen_benchmark', '--with_key_reuse']
    else:
        args += ['--gen_test_combined', '1', '33', str(0)]  # 0: all random

    # TODO
    # args += gen_hash

    return cli.run_cryptotvgen(args, logfile=None)


def get_lang(file: str):
    for ext in ['vhd', 'vhdl']:
        if file.endswith('.' + ext):
            return 'vhdl'
    if file.endswith('.v'):
        return 'verilog'
    if file.endswith('.sv'):
        return 'system-verilog'


def gen_from_template(orig_filename, gen_filename, changes):
    with open(orig_filename, 'r') as orig:
        content = orig.read()
        for old, repl in changes:
            content = re.sub(old, repl, content)
    with open(gen_filename, 'w') as gen:
        gen.write(content)


def test_all():
    vhdl_files = []
    verilog_files = []
    # print(f'VHDL_FILES={vhdl_files}')

    design = load_design_from_toml(
        script_dir / 'dummy_lwc_w32_ccw32.toml'
    )

    vhdl_files = design.rtl.sources

    orig_design_pkg = Path('src_rtl') / 'v1' / 'design_pkg.vhd'
    orig_lwc_config = Path('src_rtl') / 'LWC_config_32.vhd'

    param_variants = [(32, 32), (32, 16), (32, 8), (16, 16), (8, 8)]

    generated_sources = (core_src_path / 'generated_srcs')
    generated_sources.mkdir(exist_ok=True)

    orig_parameters = copy(design.tb.parameters)

    # first try with original settings
    xeda_runner.run_flow(
        GhdlSim, design
    )

    for vhdl_std in ['08', '02']:
        for ms in [False, True]:
            replace_files_map = {}
            for w, ccw in param_variants:
                for async_rstn in [False, True]:
                    replaced_lwc_config = (
                        generated_sources /
                        f'LWC_config_W{w}{"_ASYNC_RSTN" if async_rstn else ""}.vhd'
                    ).resolve()

                    gen_from_template(orig_lwc_config,
                                      replaced_lwc_config,
                                      [
                                          (r'(constant\s+W\s*:\s*positive\s*:=\s*)\d+(\s*;)',
                                           f'\\g<1>{w}\\g<2>'),
                                          (r'(constant\s+ASYNC_RSTN\s*:\s+boolean\s*:=\s*)\w+(\s*;)',
                                           f'\\g<1>{async_rstn}\\g<2>')
                                      ]
                                      )

                    replace_files_map[orig_lwc_config] = replaced_lwc_config

                    bench = w == ccw and not async_rstn and vhdl_std == "08"
                    print(
                        f'\n\n{"="*12}- Testing VHDL:20{vhdl_std} multi-segment:{ms} W:{w} CCW:{ccw} ASYNC_RSTN:{async_rstn} benchmark-KATs:{bench} -{"="*12}\n'
                    )
                    kat_dir = gen_tv_subfolder / \
                        f'TV{"_MS" if ms else ""}_{w}'

                    replaced_design_pkg = (
                        generated_sources / f'design_pkg_{ccw}.vhd'
                    ).resolve()

                    gen_from_template(
                        orig_design_pkg,
                        replaced_design_pkg,
                        [
                            (r'(constant\s+CCW\s*:\s*\w+\s*:=\s*)\d+(\s*;)',
                             f'\\g<1>{ccw}\\g<2>')
                        ]
                    )
                    replace_files_map[orig_design_pkg] = replaced_design_pkg

                    def replace_file(f):
                        for orig in replace_files_map.keys():
                            if f.file.resolve().samefile(orig):
                                return replace_files_map[orig]
                        return f
                    gen_tv(w, 2 if ms else None, kat_dir, bench)

                    design.rtl.sources = [str(replace_file(f))
                                          for f in vhdl_files]

                    design.language.vhdl.standard = vhdl_std
                    design.name = f"generated_dummy_{vhdl_std}_W{w}_CCW{ccw}{'_ASYNC_RSTN' if async_rstn else ''}"
                    if bench:
                        kat_dir = kat_dir / 'kats_for_verification'
                    design.tb.parameters = {
                        **orig_parameters,
                        'G_FNAME_PDI': {'file': kat_dir / 'pdi.txt'},
                        'G_FNAME_SDI': {'file': kat_dir / 'sdi.txt'},
                        'G_FNAME_DO': {'file': kat_dir / 'do.txt'},
                        'G_TEST_MODE': 1 if bench else 0,
                        'G_MAX_FAILURES': 0,
                        'G_TIMEOUT_CYCLES': 1000,
                        'G_RANDOM_STALL': True,
                    }

                    xeda_runner.run_flow(
                        GhdlSim, design, setting_overrides=ghdl_setting_overrides
                    )


if __name__ == "__main__":
    build_libs()
    test_all()
