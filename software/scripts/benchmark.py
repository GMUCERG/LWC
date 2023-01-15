#!/usr/bin/env python3

import csv
import logging
import os
import re
import secrets
import sys
from copy import copy
from functools import reduce
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Union

import click
from cryptotvgen.cli import run_cryptotvgen
from rich.console import Console
from rich.table import Table
from xeda import Design
from xeda.dataclass import Extra, Field
from xeda.dataclass import XedaBaseModel as BaseModel
from xeda.flow_runner import DefaultRunner as FlowRunner

SCRIPT_DIR = Path(__file__).parent.resolve()

console = Console()

logger = logging.getLogger(__name__)
logger.root.setLevel(logging.INFO)


class Lwc(BaseModel):
    """design.lwc"""

    class Config:
        extra = Extra.forbid
        allow_population_by_field_name = True

    class Aead(BaseModel):
        class Config:
            extra = Extra.forbid

        class InputSequence(BaseModel):
            #  input/output types: "ad", "pt", "ct", "data" (pt/ct), "npub", "tag", "length", ...
            encrypt: Sequence[str] = Field(
                ["npub", "ad", "pt"],  # "tag" is not an input in encrypt
                description="Sequence of inputs during encryption",
                alias="enc",
            )
            decrypt: Sequence[str] = Field(
                ["npub", "ad", "ct", "tag"],
                description="Sequence of inputs during decryption",
                alias="dec",
            )

        algorithm: Optional[str] = Field(
            None,
            description="Name of the implemented AEAD algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention",
            examples=["giftcofb128v1", "romulusn1v12", "gimli24v1"],
        )
        key_bits: Optional[int] = Field(description="Size of key in bits.")
        npub_bits: Optional[int] = Field(description="Size of public nonce in bits.")
        tag_bits: Optional[int] = Field(description="Size of tag in bits.")
        input_sequence: InputSequence = Field(
            InputSequence(),  # type: ignore
            description="Order in which different input segment types should be fed to PDI.",
        )
        key_reuse: bool = Field(False, alias="reuse_key")

    class Hash(BaseModel):
        class Config:
            extra = Extra.forbid

        algorithm: str = Field(
            description="Name of the hashing algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention. Empty string if hashing is not supported",
            examples=["", "gimli24v1"],
        )
        digest_bits: Optional[int] = Field(
            description="Size of hash digest (output) in bits."
        )

    class Ports(BaseModel):
        class Config:
            extra = Extra.forbid

        class Pdi(BaseModel):
            bit_width: Optional[int] = Field(
                32,
                ge=8,
                le=32,
                description="Width of each word of PDI data in bits (`w`). The width of 'pdi_data' signal would be `pdi.bit_width × pdi.num_shares` (`w × n`) bits.",
                alias="width",
            )
            num_shares: int = Field(
                1,
                description="Number of PDI shares (`n`)",
                alias="shares",
            )

        class Sdi(BaseModel):
            bit_width: Optional[int] = Field(
                None,
                ge=8,
                le=32,
                description="Width of each word of SDI data in bits (`sw`). The width of `sdi_data` signal would be `sdi.bit_width × sdi.num_shares` (`sw × sn`) bits.",
                alias="width",
            )
            num_shares: int = Field(
                1,
                description="Number of SDI shares (`sn`)",
                alias="shares",
            )

        class Rdi(BaseModel):
            bit_width: int = Field(
                0,
                ge=0,
                # le=2048,
                description="Width of the `rdi` port in bits (`rw`), 0 if the port is not used.",
            )

        pdi: Pdi = Field(Pdi(), description="Public Data Input port")
        sdi: Sdi = Field(Sdi(), description="Secret Data Input port")
        rdi: Optional[Rdi] = Field(None, description="Random Data Input port.")

    class ScaProtection(BaseModel):
        class Config:
            extra = Extra.allow
            allow_population_by_field_name = True

        target: Optional[Sequence[str]] = Field(
            None,
            description="Type of side-channel analysis attack(s) against which this design is assumed to be secure.",
            examples=[["spa", "dpa", "cpa", "timing"], ["dpa", "sifa", "dfia"]],
        )
        masking_schemes: Optional[Sequence[str]] = Field(
            [],
            description='Masking scheme(s) applied in this implementation. Could be name/abbreviation of established schemes (e.g., "DOM", "TI") or reference to a publication.',
            examples=[["TI"], ["DOM", "https://eprint.iacr.org/2022/000.pdf"]],
        )
        order: int = Field(
            ..., description="Claimed order of protectcion. 0 means unprotected."
        )
        notes: Optional[Sequence[str]] = Field(
            [],
            description="Additional notes or comments on the claimed SCA protection.",
        )

    aead: Optional[Aead] = Field(
        None, description="Details about the AEAD scheme and its implementation"
    )
    hash: Optional[Hash] = None
    ports: Ports = Field(Ports(), description="Description of LWC ports.")
    sca_protection: Optional[ScaProtection] = Field(
        None, description="Implemented countermeasures against side-channel attacks."
    )
    block_bits: Union[Dict[str, int], int] = Field(alias="block_size")


class LwcDesign(Design):
    """A Lightweight Cryptography hardware implementations"""

    lwc: Lwc


SCRIPT_DIR = Path(__file__).parent.resolve()


def build_libs(algos: List[str], cref_dir: Union[None, str, os.PathLike, Path] = None):
    args = ["--prepare_libs"] + algos
    if cref_dir is not None:
        if not isinstance(cref_dir, Path):
            cref_dir = Path(cref_dir)
        if cref_dir.exists():
            args += ["--candidates_dir", str(cref_dir)]
    return run_cryptotvgen(args)


def gen_tv(
    lwc: Lwc,
    dest_dir: Union[str, os.PathLike],
    blocks_per_segment=None,
    bench=False,
    cref_dir=None,
):
    args = [
        "--dest",
        str(dest_dir),
        "--max_ad",
        "80",
        "--max_d",
        "80",
        "--max_io_per_line",
        "32",
        "--verify_lib",
    ]
    if cref_dir:
        args += [
            "--candidates_dir",
            str(cref_dir),
        ]
    if lwc.aead:
        assert lwc.aead.algorithm
        args += [
            "--aead",
            lwc.aead.algorithm,
        ]

        def fix_key_names(in_seq):
            return ["data" if i.lower() in ("ct", "pt") else i.lower() for i in in_seq]

        input_sequence = list(lwc.aead.input_sequence.encrypt)
        if (
            "tag" not in input_sequence
        ):  # cryptptvgen's enc_msg_format is output sequence!!! FIXME??!!
            input_sequence.append("tag")
        if input_sequence:
            args += ["--enc_msg_format", *fix_key_names(input_sequence)]
        input_sequence = list(lwc.aead.input_sequence.decrypt)
        if input_sequence:
            args += ["--dec_msg_format", *fix_key_names(input_sequence)]

    if lwc.hash:
        args += [
            "--hash",
            lwc.hash.algorithm,
        ]
    if isinstance(lwc.block_bits, int):
        lwc.block_bits = dict(XT=lwc.block_bits)
    block_bits = {k.upper(): v for k, v in lwc.block_bits.items()}
    logger.info("block_bits: ", block_bits)
    print("block_bits: ", block_bits)
    if "XT" in block_bits:
        block_bits["PT"] = block_bits["XT"]
        block_bits["CT"] = block_bits["XT"]
    elif "PT" in block_bits and (
        not "CT" in block_bits or block_bits["PT"] == block_bits["CT"]
    ):
        block_bits["XT"] = block_bits["PT"]
    elif "CT" in block_bits:
        block_bits["XT"] = block_bits["CT"]
    elif "HM" in block_bits:
        block_bits["XT"] = block_bits["HM"]
    bs = block_bits.get("XT", block_bits.get("PT", 512))
    sdi_width = lwc.ports.sdi.bit_width or lwc.ports.pdi.bit_width
    args += [
        "--io",
        str(lwc.ports.pdi.bit_width),
        str(sdi_width),
    ]
    if lwc.aead and bs:
        args += [
            "--block_size",
            str(bs),
            "--block_size_ad",
            str(block_bits.get("AD", bs)),
        ]
    if lwc.hash:
        args += [
            "--block_size_msg_digest",
            str(block_bits.get("HM", bs)),
        ]

    if blocks_per_segment:
        args += ["--max_block_per_sgmt", str(blocks_per_segment)]

    # gen_hash = '--gen_hash 1 20 2'.split()
    if bench:
        args += ["--gen_benchmark"]
        if lwc.aead and lwc.aead.key_reuse:
            args += ["--with_key_reuse"]
    else:
        args += ["--gen_test_combined", "1", "33", str(0)]  # 0: all random

    print("cryptotvgen", *args)
    return run_cryptotvgen(args, logfile=None)


def xor(l, r):
    return bytes(a ^ b for a, b in zip(l, r))


INS_PREAMBLE = "INS = "
HDR_PREAMBLE = "HDR = "
DAT_PREAMBLE = "DAT = "
STT_PREAMBLE = "STT = "

PREAMBLES_LEN = len(INS_PREAMBLE)


def gen_shared_lines(
    in_lines,
    num_shares,
    w_nbytes,
    keep_comments,
    replace_with_random=False,
):
    num_tests = 0
    shared_lines = []
    all_data = []
    if replace_with_random:
        keep_comments = False
    for line in in_lines:
        line = line.strip()
        if not keep_comments and (line.startswith("#") or not line):
            continue
        if len(line) < PREAMBLES_LEN:
            print("[ERROR] input line is too short")
            continue
        preamble = line[:PREAMBLES_LEN]
        data = line[PREAMBLES_LEN:].strip()
        if preamble == INS_PREAMBLE:
            num_tests += 1
        if (
            preamble == HDR_PREAMBLE or preamble == INS_PREAMBLE
        ):  # set other shares to zeros
            if w_nbytes == 0:
                w_nbytes = (len(data) + 1) // 2
            data = data + ("0" * (num_shares - 1) * len(data))
            line = preamble + data
            all_data.append(data)
        elif preamble == DAT_PREAMBLE:
            data_bytes = bytes.fromhex(data)
            data = ""
            for i in range(0, len(data_bytes), w_nbytes):
                word = data_bytes[i : i + w_nbytes]
                shares = [secrets.token_bytes(w_nbytes) for _ in range(num_shares - 1)]
                if replace_with_random:
                    shares.append(secrets.token_bytes(w_nbytes))
                else:
                    shares.append(reduce(xor, shares + [word]))
                    assert reduce(xor, shares) == word
                data += "".join([x.hex().upper() for x in shares])
            line = preamble + data
            all_data.append(data)
        shared_lines.append(line)
    return shared_lines, all_data


def gen_shares(in_file: Path, num_shares, w_nbytes=0, keep_comments=True):
    out_file = in_file.parent / (in_file.stem + f"_shared_{num_shares}.txt")

    with open(in_file) as f:
        in_lines = f.readlines()

    shared_lines, _ = gen_shared_lines(in_lines, num_shares, w_nbytes, keep_comments)

    with open(out_file, "w") as fo:
        if keep_comments:
            fo.write(
                f"#\n# Shared version of {in_file.name} split into {num_shares} shares\n#\n"
            )
        fo.write("\n".join(shared_lines))
    return out_file


FRESH_RAND_COL_NAME = "fresh rand. bits"
RAND_PER_BYTE_COL_NAME = "rand. bits per byte of data"


@click.command()
@click.argument("toml_path")
@click.option(
    "--debug",
    is_flag=True,
    show_default=True,
    default=False,
    help="run flows in debug mode",
)
@click.option(
    "--sim-flow",
    type=str,
    show_default=True,
    default="vivado_sim",
    help="simulation flow to use",
)
@click.option(
    "--cref-dir",
    type=click.types.Path(file_okay=False, dir_okay=True),
    show_default=True,
    default=None,
    help="Path to C reference source code, with SUPERCOP directory structure.",
)
@click.option(
    "--existing-timing-report",
    type=click.types.Path(file_okay=True, dir_okay=False),
    default=None,
)
@click.option(
    "--existing-timing-tests",
    type=click.types.Path(file_okay=True, dir_okay=False),
    default=None,
)
@click.option(
    "--build",
    is_flag=True,
    show_default=True,
    default=False,
    help="force build reference libraries",
)
def cli(
    toml_path,
    debug,
    sim_flow,
    cref_dir,
    existing_timing_report,
    existing_timing_tests,
    build=False,
):
    """toml_path: Path to design description TOML file."""
    design = LwcDesign.from_toml(toml_path)
    lwc = design.lwc
    pdi_shares = lwc.ports.pdi.num_shares
    sdi_shares = lwc.ports.sdi.num_shares
    design_root_dir = design.design_root
    if not design_root_dir:
        design_root_dir = Path.cwd()

    if existing_timing_report:
        assert (
            existing_timing_tests
        ), "existing_timing_tests should as well be specified!"
        timing_report = Path(existing_timing_report)
        timing_tests_file = Path(existing_timing_tests)
    else:
        tv_dir = design_root_dir / "BENCH_KAT" / design.name
        timing_report = Path.cwd() / (design.name + "_timing.txt")
        if cref_dir is None:
            cref_dir = design.root_path / "cref"
        if not isinstance(cref_dir, Path):
            cref_dir = Path(cref_dir)
        if not cref_dir or not cref_dir.exists():
            print(f"cref_dir={cref_dir} not found! disabled.")
            cref_dir = None
        if build:
            algs = []
            if lwc.aead and lwc.aead.algorithm:
                algs.append(lwc.aead.algorithm)
            if lwc.hash and lwc.hash.algorithm:
                algs.append(lwc.hash.algorithm)
            build_libs(algs, cref_dir)
        gen_tv(design.lwc, tv_dir, bench=True, cref_dir=cref_dir)
        # KATs must exist
        kat_dir = tv_dir / "timing_tests"
        pdi_txt = kat_dir / "pdi.txt"
        sdi_txt = kat_dir / "sdi.txt"
        if pdi_shares > 1 or sdi_shares > 1:
            pdi_txt = gen_shares(pdi_txt, pdi_shares, keep_comments=False)
            sdi_txt = gen_shares(sdi_txt, sdi_shares, keep_comments=False)
        design.tb.parameters = {
            **design.tb.parameters,
            "G_FNAME_PDI": {"file": pdi_txt},
            "G_FNAME_SDI": {"file": sdi_txt},
            "G_FNAME_DO": {"file": kat_dir / "do.txt"},
            "G_FNAME_TIMING": str(timing_report),
            "G_TEST_MODE": 4,
        }
        design.tb.top = ("LWC_TB",)
        design.language.vhdl.standard = "2008"
        settings = {}
        if debug:
            # settings["debug"] = True
            if sim_flow == "ghdl_sim":
                settings["wave"] = Path.cwd() / "benchmark.ghw"
            else:
                settings["vcd"] = Path.cwd() / "benchmark.vcd"
        if sim_flow:
            f = FlowRunner().run_flow(sim_flow, design, settings)
            if not f or not f.succeeded:
                sys.exit("Simulation flow failed")
        timing_tests_file = kat_dir / "timing_tests.csv"

    assert timing_report and timing_report.exists()
    assert timing_tests_file and timing_tests_file.exists()

    msg_cycles: Dict[str, int] = {}
    msg_fresh_rand: Dict[str, int] = {}
    with open(timing_report) as f:
        for l in f.readlines():
            kv = re.split(r"\s*,\s*", l.strip())
            if len(kv) >= 2:
                msg_cycles[kv[0]] = int(kv[1])
            if len(kv) >= 3:
                msg_fresh_rand[kv[0]] = int(kv[2], 16)
    results: List[dict[str, Union[int, float, str]]] = []
    with open(timing_tests_file) as f:
        rows: List[Dict[Any, Any]] = list(csv.DictReader(f))
        for row in rows:
            msgid = row["msgId"]
            assert isinstance(msgid, str)
            row["Cycles"] = msg_cycles[msgid]
            if msgid in msg_fresh_rand:
                row[FRESH_RAND_COL_NAME] = msg_fresh_rand[msgid]
            if row["hash"] == "True":
                row["Op"] = "Hash"
            else:
                row["Op"] = "Dec" if row["decrypt"] == "True" else "Enc"
                # if row["newKey"] == "False":
                #     row["Op"] += ":reuse-key"
            row["Reuse Key"] = (
                True if row["newKey"] == "False" and row["Op"] != "Hash" else False
            )
            row["adBytes"] = int(row["adBytes"])
            row["msgBytes"] = int(row["msgBytes"])
            total_bytes = row["adBytes"] + row["msgBytes"]
            row["Throughput"] = total_bytes / msg_cycles[msgid]
            if FRESH_RAND_COL_NAME in row:
                row[RAND_PER_BYTE_COL_NAME] = row[FRESH_RAND_COL_NAME] / total_bytes
            results.append(row)
            if row["longN+1"] == "True":
                long_row = copy(results[-2])
                # just to silence the type checker:
                assert isinstance(long_row, dict)
                prev_id: str = str(long_row["msgId"])
                prev_ad = int(long_row["adBytes"])
                prev_msg = int(long_row["msgBytes"])
                ad_diff = int(row["adBytes"]) - prev_ad
                msg_diff = int(row["msgBytes"]) - prev_msg
                cycle_diff = msg_cycles[msgid] - msg_cycles[prev_id]
                long_row["adBytes"] = "long" if int(row["adBytes"]) else 0
                long_row["msgBytes"] = "long" if int(row["msgBytes"]) else 0
                long_row["Cycles"] = cycle_diff
                long_row["msgId"] = prev_id + ":" + msgid
                long_row["Throughput"] = (ad_diff + msg_diff) / cycle_diff
                if msgid in msg_fresh_rand:
                    rnd_diff = msg_fresh_rand[msgid] - msg_fresh_rand[prev_id]
                    long_row[FRESH_RAND_COL_NAME] = rnd_diff
                    long_row[RAND_PER_BYTE_COL_NAME] = rnd_diff / (ad_diff + msg_diff)
                results.append(long_row)
    results_file = design.name + "_timing_results.csv"
    fieldnames = [
        "Op",
        "Reuse Key",
        "msgBytes",
        "adBytes",
        "Cycles",
        "Throughput",
    ]
    if msg_fresh_rand:
        fieldnames += [
            FRESH_RAND_COL_NAME,
            RAND_PER_BYTE_COL_NAME,
        ]

    def sorter(x):
        k = [99999 if x[f] == "long" else x[f] for f in fieldnames]
        k.insert(2, 0 if x["msgBytes"] == 0 else 1 if x["adBytes"] == 0 else 2)
        k[0] = ["Enc", "Dec", "Hash"].index(str(k[0]))
        return k

    results = sorted(results, key=sorter)
    with open(results_file, "w") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=fieldnames,
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(results)

    table = Table()

    def tr(f):
        tr_map = {
            "Throughput": "Throughput [B/cycle]",
            "msgBytes": "PT/CT [B]",
            "adBytes": "AD [B]",
        }
        return tr_map.get(f, f)

    for f in fieldnames:
        table.add_column(tr(f), justify="right")
    for row in results:
        row["Reuse Key"] = "✓" if row["Reuse Key"] else ""
        table.add_row(
            *(str(row[fn]) for fn in fieldnames),
            end_section=row["adBytes"] == "long" and row["msgBytes"] == "long",
        )
    console.print(table)
    logger.info("Timing results written to %s", results_file)


if __name__ == "__main__":
    cli()
