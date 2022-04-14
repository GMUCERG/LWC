#! /usr/bin/env python3

import csv
import logging
import os
import re
from copy import copy
from pathlib import Path
from typing import Dict, List, Literal, Mapping, Optional, OrderedDict, Sequence, Union

from cryptotvgen import cli
from pydantic import conint
from rich.console import Console
from rich.table import Table
from xeda import Design
from xeda.dataclass import Extra, Field
from xeda.dataclass import XedaBaseModel as BaseModel
from xeda.flow_runner import DefaultRunner as FlowRunner
from xeda.flows import GhdlSim

console = Console()


class InputSequence(BaseModel):
    encrypt: Optional[Sequence[Literal["ad", "pt", "npub", "tag"]]] = Field(
        ["npub", "ad", "pt", "tag"], description="Sequence of inputs during encryption"
    )
    decrypt: Optional[Sequence[Literal["ad", "ct", "npub", "tag"]]] = Field(
        ["npub", "ad", "ct", "tag"], description="Sequence of inputs during decryption"
    )


class Aead(BaseModel):

    algorithm: str = Field(
        None,
        description="Name of the implemented AEAD algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention",
        examples=["giftcofb128v1", "romulusn1v12", "gimli24v1"],
    )
    key_bits: Optional[int] = Field(description="Size of key in bits.")
    npub_bits: Optional[int] = Field(description="Size of public nonce in bits.")
    tag_bits: Optional[int] = Field(description="Size of tag in bits.")
    input_sequence: Optional[InputSequence] = Field(
        None,
        description="Order in which different input segment types should be fed to PDI.",
    )
    key_reuse: bool = False


class Hash(BaseModel):
    algorithm: str = Field(
        description="Name of the hashing algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention. Empty string if hashing is not supported",
        examples=["", "gimli24v1"],
    )
    digest_bits: Optional[int] = Field(
        description="Size of hash digest (output) in bits."
    )


class Ports(BaseModel):
    class Pdi(BaseModel):
        bit_width: Optional[int] = Field(
            32,
            ge=8,
            le=32,
            description="Width of each word of PDI data in bits (`w`). The width of 'pdi_data' signal would be `pdi.bit_width × pdi.num_shares` (`w × n`) bits.",
        )
        num_shares: int = Field(1, description="Number of PDI shares (`n`)")

    class Sdi(BaseModel):
        bit_width: Optional[int] = Field(
            32,
            ge=8,
            le=32,
            description="Width of each word of SDI data in bits (`sw`). The width of `sdi_data` signal would be `sdi.bit_width × sdi.num_shares` (`sw × sn`) bits.",
        )
        num_shares: int = Field(1, description="Number of SDI shares (`sn`)")

    class Rdi(BaseModel):
        bit_width: int = Field(
            ge=0,
            le=2048,
            description="Width of the `rdi` port in bits (`rw`), 0 if the port is not used.",
        )

    pdi: Pdi = Field(description="Public Data Input port")
    sdi: Sdi = Field(description="Secret Data Input port")
    rdi: Optional[Rdi] = Field(None, description="Random Data Input port.")


class ScaProtection(BaseModel):
    class Config:
        extra = Extra.allow

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
        [], description="Additional notes or comments on the claimed SCA protection."
    )


class Lwc(BaseModel):

    aead: Optional[Aead] = Field(
        None, description="Details about the AEAD scheme and its implementation"
    )
    hash: Optional[Hash] = None
    ports: Ports = Field(..., description="Description of LWC ports.")
    sca_protection: Optional[ScaProtection] = Field(
        None, description="Implemented countermeasures against side-channel attacks."
    )
    block_size: Dict[str, int] = Field({"xt": 128, "ad": 128, "hm": 128})


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

SCRIPT_DIR = Path(__file__).parent.resolve()

CREF_DIR = SCRIPT_DIR / "cref"


class LwcDesign(Design):
    lwc: Lwc


def build_libs(andidates_dir):
    args = ["--prepare_libs", "--candidates_dir", str(andidates_dir)]
    return cli.run_cryptotvgen(args)


def gen_tv(
    lwc: Lwc, dest_dir: Union[str, os.PathLike], blocks_per_segment=None, bench=False
):
    # build_libs(CREF_DIR)
    args = [
        "--candidates_dir",
        str(CREF_DIR),
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
    if lwc.aead:
        args += [
            "--aead",
            lwc.aead.algorithm,
        ]
        if lwc.aead.input_sequence:
            args += ["--msg_format", *lwc.aead.input_sequence]

    if lwc.hash:
        args += [
            "--hash",
            lwc.hash.algorithm,
        ]
    args += [
        "--io",
        str(lwc.ports.pdi.bit_width),
        str(lwc.ports.sdi.bit_width),
        # '--key_size', '128',
        # '--npub_size', '96',
        # '--nsec_size', '0',
        # '--message_digest_size', '256',
        # '--tag_size', '128',
        "--block_size",
        str(lwc.block_size["xt"]),
        "--block_size_ad",
        str(lwc.block_size["ad"]),
        "--block_size_msg_digest",
        str(lwc.block_size["hm"]),
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

    # TODO
    # args += gen_hash

    return cli.run_cryptotvgen(args, logfile=None)


KATS_DIR = SCRIPT_DIR / "GMU_KAT"


def main():
    design = LwcDesign.from_toml(SCRIPT_DIR / "dummy_lwc_w32_ccw32.toml")
    tv_dir = KATS_DIR / design.name
    timing_report = Path.cwd() / (design.name + "_timing.txt")
    gen_tv(design.lwc, tv_dir, bench=True)
    # KATs must exist
    timing_kat_dir = tv_dir / "timing_tests"
    design.tb.parameters = {
        **design.tb.parameters,
        "G_FNAME_PDI": {"file": timing_kat_dir / "pdi.txt"},
        "G_FNAME_SDI": {"file": timing_kat_dir / "sdi.txt"},
        "G_FNAME_DO": {"file": timing_kat_dir / "do.txt"},
        "G_FNAME_TIMING": str(timing_report),
        "G_TEST_MODE": 4,
    }

    f = FlowRunner().run_flow(GhdlSim, design)
    assert f.succeeded

    assert timing_report.exists()

    msg_cycles: Dict[str, int] = {}
    with open(timing_report) as f:
        for l in f.readlines():
            kv = re.split(r"\s*,\s*", l.strip())
            if len(kv) == 2:
                msg_cycles[kv[0]] = int(kv[1])
    results: List[dict[str, Union[int, float, str]]] = []
    with open(timing_kat_dir / "timing_tests.csv") as f:
        for row in csv.DictReader(f):
            msgid = row["msgId"]
            assert isinstance(msgid, str)
            row["Cycles"] = msg_cycles[msgid]
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
            row["Throughput"] = round(
                (row["adBytes"] + row["msgBytes"]) / msg_cycles[msgid], 3
            )
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
                long_row["Throughput"] = round((ad_diff + msg_diff) / cycle_diff, 3)
                results.append(long_row)
    results_file = design.name + "_timing_results.csv"
    fieldnames = ["Op", "Reuse Key", "msgBytes", "adBytes", "Cycles", "Throughput"]

    def sorter(x):
        k = [99999 if x[f] == "long" else x[f] for f in fieldnames]
        k.insert(2, 0 if x["msgBytes"] == 0 else 1 if x["adBytes"] == 0 else 2)
        k[0] = ["Enc", "Dec", "Hash"].index(k[0])
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
    table = Table(*fieldnames)
    for row in results:
        row["Reuse Key"] = "✓" if row["Reuse Key"] else ""
        table.add_row(
            *(str(row[fn]) for fn in fieldnames),
            end_section=row["adBytes"] == "long" and row["msgBytes"] == "long",
        )
    console.print(table)
    logger.info("Timing results written to %s", results_file)


if __name__ == "__main__":
    main()
