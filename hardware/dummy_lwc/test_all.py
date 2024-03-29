#!/usr/bin/env python3

import csv
import logging
import os
import re
from argparse import ArgumentParser
from copy import deepcopy
from pathlib import Path
from typing import Dict, List, Mapping, Optional, Union

from cryptotvgen import cli
from xeda.design import Design, DesignSource
from xeda.flow_runner import DefaultRunner
from xeda.flows import GhdlSim, VivadoSim, YosysSynth

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

xeda_runner = DefaultRunner()


script_dir = Path(__file__).parent.resolve()
print(f"script_dir={script_dir}")

ghdl_settings = {
    "warn_flags": [
        "-Wno-runtime-error",
        "--warn-binding",
        "--warn-default-binding",
        "--warn-reserved",
        "--warn-library",
        "--warn-vital-generic",
        "--warn-shared",
        # '--warn-runtime-error',
        # '--warn-static',
        "--warn-body",
        "--warn-specs",
        "--warn-unused",
        "--warn-parenthesis",
    ],
    "wave": False,
}

# TODO use pytest?

# SETTINGS
# TODO add argeparse for settings?
core_src_path = script_dir
lwc_root = script_dir.parents[1]
vivado_sim = False

sim_flow = VivadoSim if vivado_sim else GhdlSim

tvgen_cand_dir = lwc_root / "software" / "dummy_lwc_ref"


def build_libs():
    args = ["--prepare_libs", "--candidates_dir", str(tvgen_cand_dir)]
    return cli.run_cryptotvgen(args)


gen_tv_subfolder = Path("generated_tv").resolve()
gen_configs_subfolder = Path("generated_config").resolve()
gen_configs_subfolder.mkdir(exist_ok=True)


def gen_tv(
    w: int,
    blocks_per_segment: Optional[int],
    dest_dir: Union[str, os.PathLike],
    design: Design,
    bench: bool,
):
    """generate testvectors using cryptotvgen"""
    args = [
        "--candidates_dir",
        str(tvgen_cand_dir),
        # '--lib_path', str(tvgen_cand_dir / 'lib'),
        "--aead",
        design.lwc["aead"]["algorithm"],
        "--hash",
        design.lwc["hash"]["algorithm"],
        "--io",
        str(w),
        str(w),
        # '--key_size', '128',
        # '--npub_size', '96',
        # '--nsec_size', '0',
        # '--message_digest_size', '256',
        # '--tag_size', '128',
        "--block_size",
        "128",
        "--block_size_ad",
        "128",
        "--block_size_msg_digest",
        "128",
        "--dest",
        str(dest_dir),
        "--max_ad",
        "80",
        "--max_d",
        "80",
        "--max_io_per_line",
        "8",
        "--verify_lib",
    ]

    if blocks_per_segment:
        args += ["--max_block_per_sgmt", str(blocks_per_segment)]

    msg_format = "--msg_format npub ad data tag".split()

    # gen_hash = '--gen_hash 1 20 2'.split()
    args += msg_format
    if bench:
        args += ["--gen_benchmark", "--with_key_reuse"]
    else:
        args += ["--gen_test_combined", "1", "33", str(0)]  # 0: all random

    # TODO
    # args += gen_hash
    print(args)

    return cli.run_cryptotvgen(args, logfile=None)  # type: ignore


def gen_from_template(orig_filename, gen_filename, changes):
    """create a modified version of orig_filename baseon regex changes"""
    with open(orig_filename, "r") as orig:
        content = orig.read()
        for old, repl in changes:
            content = re.sub(old, repl, content)
    with open(gen_filename, "w") as gen:
        gen.write(content)


def measure_timing(design: Design):
    """measure number of cycles for different operations and input sizes"""
    design = deepcopy(design)  # passed by reference, don't change the original
    w = 32
    ccw = 32
    design.name = f"generated_timing_w{w}_ccw{ccw}"
    kat_dir = Path("generated_tv")
    gen_tv(w, None, kat_dir, design, True)
    kat_subdir = kat_dir / "timing_tests"
    timing_report = Path.cwd() / (design.name + "_timing.txt")
    design.tb.parameters = {
        **design.tb.parameters,
        "G_FNAME_PDI": {"file": kat_subdir / "pdi.txt"},
        "G_FNAME_SDI": {"file": kat_subdir / "sdi.txt"},
        "G_FNAME_DO": {"file": kat_subdir / "do.txt"},
        "G_FNAME_TIMING": str(timing_report),
        "G_TEST_MODE": 4,
    }

    f = xeda_runner.run_flow(sim_flow, design)
    assert f.results["success"]

    assert timing_report.exists()

    msg_cycles: Dict[str, int] = {}
    with open(timing_report) as f:
        for l in f.readlines():
            kv = re.split(r"\s*,\s*", l.strip())
            if len(kv) == 2:
                msg_cycles[kv[0]] = int(kv[1])
    results: List[Mapping[str, Union[int, str]]] = []
    with open(kat_subdir / "timing_tests.csv") as f:
        reader = csv.DictReader(f)
        for row in reader:
            msgid = row["msgId"]
            row["cycles"] = str(msg_cycles[msgid])
            if row["hash"] == "True":
                row["op"] = "Hash"
            else:
                row["op"] = "Dec" if row["decrypt"] == "True" else "Enc"
                if row["newKey"] == "False":
                    row["op"] += ":reuse-key"
            row[
                "throughput"
            ] = f"{(int(row['adBytes']) + int(row['msgBytes'])) / msg_cycles[msgid]:0.3f}"
            results.append(row)
            if row["longN+1"] == "True":
                long_row = results[-2]
                # just to silence the type checker:
                assert isinstance(long_row, dict)
                prev_id: str = str(long_row["msgId"])
                prev_ad = int(long_row["adBytes"])
                prev_msg = int(long_row["msgBytes"])
                ad_diff = int(row["adBytes"]) - prev_ad
                msg_diff = int(row["msgBytes"]) - prev_msg
                cycle_diff = msg_cycles[msgid] - msg_cycles[prev_id]
                long_row["adBytes"] = "long" if int(long_row["adBytes"]) else 0
                long_row["msgBytes"] = "long" if int(long_row["msgBytes"]) else 0
                long_row["cycles"] = cycle_diff
                long_row["msgId"] = prev_id + ":" + msgid
                long_row["throughput"] = f"{(ad_diff + msg_diff) / cycle_diff:0.3f}"
                results.append(long_row)
    results_file = design.name + "_timing_results.csv"
    with open(results_file, "w") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["op", "msgBytes", "adBytes", "cycles", "throughput"],
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(results)
    logger.info("Timing results written to %s", results_file)


def variant_test(design: Design, vhdl_std, w, ccw, ms, async_rstn):
    """generate modified sources and run test(s)"""
    # TODO find in design.rtl.sources
    orig_design_pkg = None
    orig_lwc_config = None
    for src in design.rtl.sources:
        if "design_pkg" in src.file.name.lower():
            orig_design_pkg = src.file
        elif src.file.name.lower().startswith("LWC_config".lower()):
            orig_lwc_config = src.file
    assert orig_design_pkg
    assert orig_lwc_config

    generated_sources = core_src_path / "generated_srcs"
    generated_sources.mkdir(exist_ok=True)
    replaced_lwc_config = (
        generated_sources / f'LWC_config_W{w}{"_ASYNC_RSTN" if async_rstn else ""}.vhd'
    ).resolve()

    gen_from_template(
        orig_lwc_config,
        replaced_lwc_config,
        [
            (r"(constant\s+W\s*:\s*positive\s*:=\s*)\d+(\s*;)", f"\\g<1>{w}\\g<2>"),
            (
                r"(constant\s+ASYNC_RSTN\s*:\s+boolean\s*:=\s*)\w+(\s*;)",
                f"\\g<1>{async_rstn}\\g<2>",
            ),
        ],
    )
    bench = w == ccw and not async_rstn and vhdl_std == "08" and not ms
    logger.info(
        f"*** Testing VHDL:20{vhdl_std} multi-segment:{ms} W:{w} CCW:{ccw} ASYNC_RSTN:{async_rstn} benchmark-KATs:{bench} ***"
    )
    kat_dir = gen_tv_subfolder / f'TV{"_MS" if ms else ""}_{w}'

    replaced_design_pkg = (generated_sources / f"design_pkg_{ccw}.vhd").resolve()

    gen_from_template(
        orig_design_pkg,
        replaced_design_pkg,
        [(r"(constant\s+CCW\s*:\s*\w+\s*:=\s*)\d+(\s*;)", f"\\g<1>{ccw}\\g<2>")],
    )
    design = deepcopy(design)

    replace_files_map = {
        orig_design_pkg: replaced_design_pkg,
        orig_lwc_config: replaced_lwc_config,
    }

    def replace_file(ds: DesignSource) -> DesignSource:
        for orig, replacement in replace_files_map.items():
            if ds.file.resolve().samefile(orig):
                return DesignSource(replacement)
        return ds

    gen_tv(w, 2 if ms else None, kat_dir, design, bench)

    design.rtl.sources = [replace_file(f) for f in design.rtl.sources]
    design.tb.sources = [replace_file(f) for f in design.tb.sources]

    design.language.vhdl.standard = vhdl_std
    design.name = (
        f"generated_dummy_{vhdl_std}_W{w}_CCW{ccw}{'_ASYNC_RSTN' if async_rstn else ''}"
    )
    if bench:
        kat_dir = kat_dir / "kats_for_verification"
    design.tb.parameters = {
        **design.tb.parameters,
        "G_FNAME_PDI": {"file": kat_dir / "pdi.txt"},
        "G_FNAME_SDI": {"file": kat_dir / "sdi.txt"},
        "G_FNAME_DO": {"file": kat_dir / "do.txt"},
        "G_TEST_MODE": 1, # if bench else 0,
        "G_MAX_FAILURES": 0,
        "G_TIMEOUT_CYCLES": 1000,
        "G_RANDOM_STALL": True,
    }

    f = xeda_runner.run_flow(
        sim_flow, design, flow_settings=ghdl_settings if sim_flow == GhdlSim else {}
    )
    assert f.results["success"]


def synth_test(design):
    f = xeda_runner.run_flow(YosysSynth, design, {"fpga": {"vendor": "xilinx"}})
    assert f.results["success"]


def test_all(args):
    design = Design.from_toml(script_dir / "dummy_lwc_w32_ccw32.toml")
    try:
        synth_test(design)
    except:
        logger.warning("synth_test failed. Continuing...")
    # first try with original settings
    if args.test_base_design:
        f = xeda_runner.run_flow(sim_flow, design)
        assert f.results["success"]

    if args.benchmark:
        measure_timing(design)

    param_variants = [(32, 32), (32, 16), (32, 8), (16, 16), (8, 8)]

    for vhdl_std in ["08"]:  # disabling VHDL < 2008 tests TODO
        for ms in [False, True]:
            for w, ccw in param_variants:
                for async_rstn in [False, True]:
                    variant_test(design, vhdl_std, w, ccw, ms, async_rstn)


if __name__ == "__main__":
    argparser = ArgumentParser()
    argparser.add_argument("--build-libs", default=True)
    argparser.add_argument("--benchmark", default=True)
    argparser.add_argument("--test-base-design", default=True)

    args = argparser.parse_args()
    if args.build_libs:
        build_libs()
    test_all(args)
