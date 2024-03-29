import os
from pathlib import Path
import sys
import logging
import re
import tarfile
import urllib.request
import tempfile
import pathlib
import shutil
import subprocess
import requests


log = logging.getLogger(__name__)

try:
    import importlib.resources as pkg_resources
except ImportError:
    # Try backported to PY<37 `importlib_resources`.
    import importlib_resources as pkg_resources

__all__ = ["ctgen_get_supercop_dir", "prepare_libs"]


AEAD_HEADER = """
    int crypto_aead_encrypt(
        unsigned char *c,unsigned long long *clen,
        const unsigned char *m,unsigned long long mlen,
        const unsigned char *ad,unsigned long long adlen,
        const unsigned char *nsec,
        const unsigned char *npub,
        const unsigned char *k
    );
    int crypto_aead_decrypt(
        unsigned char *m,unsigned long long *mlen,
        unsigned char *nsec,
        const unsigned char *c,unsigned long long clen,
        const unsigned char *ad,unsigned long long adlen,
        const unsigned char *npub,
        const unsigned char *k
    );
"""

HASH_HEADER = """
    int crypto_hash(unsigned char *out, const unsigned char *m, unsigned long long mlen);
"""


lwc_candidates = {
    "hash": [
        "ace",
        "ascon",
        "drygascon",
        "esch",
        "gimli",
        "knot",
        "photonbeetle",
        "saturnin",
        "skinnyhash",
        "subterranean",
        "xoodyak",
    ],
    "aead": [
        "ace",
        "ascon",
        "comet",
        "drygascon",
        "elephant",
        "estate",
        "paefforkskinny",
        "giftcofb",
        "gimli",
        "grain128aead",
        "hyena",
        "isap",
        "knot",
        "twegift64locus",
        "twegift64lotus",
        "mixfeed",
        "orange",
        "oribatida",
        "photonbeetle",
        "pyjamask",
        "romulus",
        "saeaes",
        "saturnin",
        "skinnyaead",
        "schwaemm",
        "spix",
        "spoc",
        "spook",
        "subterranean",
        "sundaegift",
        "tinyjambu",
        "wage",
        "xoodyak",
    ],
}

mkfile_name = "lwc_cffi.mk"


def get_latest_supercop_version_url(sc_version):
    sc_base_url = "https://bench.cr.yp.to/"
    sc_page_url = sc_base_url + "supercop.html"

    log.setLevel(logging.INFO)

    if sc_version == "latest":
        log.info(
            f"Trying to determine the latest version of SUPERCOP from {sc_page_url}..."
        )
        try:
            response = requests.get(sc_page_url)

            if response.status_code == 200:
                log.info(
                    f"Last-Modified timestamp from server: {response.headers['Last-Modified']}"
                )

                match = re.search(
                    r'wget\s+<a\s+.*href="(supercop/supercop-(\d\d\d\d\d+)\.tar(\.[a-z]+)?)"',
                    response.content.decode("utf-8"),
                )
                if match:
                    url = sc_base_url + match.group(1)
                    version = match.group(2)
                    log.info(
                        f"Latest version of SUPERCOP is {version} available from {url}"
                    )
                    return (version, url)
                else:
                    log.error(f"Failed to find URL for downloading the latest SUPERCOP")
            else:
                log.error(
                    f"Error accessing {sc_page_url} Status code: {response.status_code}"
                )
        except Exception:
            log.error(f"Failed to retrieve SUPERCOP webpage: {sc_page_url}")
        return sc_version, None
    else:
        return (sc_version, sc_base_url + f"supercop/supercop-{sc_version}.tar.xz")


def ctgen_get_dir(sub_dir=None):
    data_dir = pathlib.Path.home() / ".cryptotvgen"
    if sub_dir:
        data_dir = data_dir / sub_dir
    if not data_dir.exists():
        data_dir.mkdir(parents=True)
    assert data_dir.exists() and data_dir.is_dir()
    return data_dir


def ctgen_get_supercop_dir():
    return ctgen_get_dir() / "supercop"


def prepare_libs(sc_version, libs, candidates_dir, lib_path):
    log.info(f"candidates_dir={candidates_dir}")
    # default ctgen data dir root, make sure exists or create
    ctgen_includes_dir = ctgen_get_dir("includes")
    ctgen_mkfile = ctgen_get_dir()

    # TODO
    ## only one first available subdirectory pattern in the tar will be used, starting from left
    impl_src_dirs = ["ref", "aadomn/opt32"]  ## aadomn/opt32 for romulusn1plus*

    def build_variants(variants, candidates_dir):
        for vname, vtype in variants:
            log.debug(
                f"running make CRYPTO_VARIANT={vname} CRYPTO_TYPE={vtype} in {candidates_dir}"
            )
            for src_dir in impl_src_dirs:
                src_path = Path(candidates_dir) / ("crypto_" + vtype) / vname / src_dir
                log.info(f"building sources in {src_path}")
                if src_path.exists() and src_path.is_dir():
                    cmd = [
                        "make",
                        "-f",
                        str(ctgen_mkfile / mkfile_name),
                        f"CRYPTO_VARIANT={vname}",
                        f"CRYPTO_TYPE={vtype}",
                        f"CANDIDATE_PATH=.",
                        f"IMPL_SRC_DIR={src_dir}",
                    ]
                    if lib_path:
                        lib_path_rel = os.path.relpath(lib_path, candidates_dir)
                        log.info(
                            f"binaries will be available in lib_path={lib_path_rel}"
                        )
                        cmd.append(f"LIB_PATH={lib_path_rel}")
                    cp = subprocess.run(cmd, cwd=candidates_dir)
                    try:
                        cp.check_returncode()
                    except:
                        log.critical(
                            f'`{" ".join(cmd)}` failed! (exit code: {cp.returncode})'
                        )
                        sys.exit(1)

    def filter_variants(variants):
        if not libs or libs == "all" or libs == ["all"]:
            log.info(
                f"building all libs in `crypto_aead` and `crypto_hash` subfolders of candidates_dir={candidates_dir} \n variants={variants}"
            )
        else:
            variants = [v for v in variants if any(v[0].startswith(l) for l in libs)]
            log.info(f"building only the following variants: {variants}")
        return variants  # TODO

    def get_sc_tar(sc_version):
        sc_version, sc_url = get_latest_supercop_version_url(sc_version)
        if not sc_url:
            sys.exit(f"Failed to open SUPERCOP archive version: {sc_version}")
        sc_filename = f"supercop-{sc_version}.tar.xz"
        cache_dir = ctgen_get_dir("cache")
        tar_path = cache_dir / sc_filename
        if tar_path.exists():
            log.warn(f"Using already cached version of supercop at {tar_path}")
            return tarfile.open(tar_path), sc_version
        log.info(f"Downloading supercop from {sc_url}")
        tar_path = urllib.request.urlretrieve(sc_url, filename=tar_path)[0]
        log.info(f"Download successfull! Archive saved to {tar_path}")
        return tarfile.open(tar_path), sc_version

    with open(ctgen_includes_dir / "crypto_aead.h", "w") as f:
        f.write(AEAD_HEADER)
    with open(ctgen_includes_dir / "crypto_hash.h", "w") as f:
        f.write(HASH_HEADER)
    (ctgen_includes_dir / "crypto_aead.h").touch()
    (ctgen_includes_dir / "crypto_hash.h").touch()

    mk_content = pkg_resources.read_text(__package__, mkfile_name)
    with open(ctgen_mkfile / mkfile_name, "w") as f:
        f.write(mk_content)

    variants = set()

    if not candidates_dir:
        candidates_dir = ctgen_get_supercop_dir()
        sc_tar, sc_version = get_sc_tar(sc_version)

        incl_candidates = set()
        extract_list = []

        crypto_dir_regexps = {
            crypto_type: [
                re.compile(f"supercop-{sc_version}/crypto_{crypto_type}/([^/]+)/.*/")
            ]
            for crypto_type in lwc_candidates.keys()
        }

        # TODO make this more efficient, though unlikely to be a performance bottleneck

        def match_tarinfo(tarinfo):
            for crypto_type in lwc_candidates.keys():
                for regexp in crypto_dir_regexps[crypto_type]:
                    match = regexp.match(tarinfo.name)
                    if match:
                        variant_name = match.group(1)
                        for cnd in lwc_candidates[crypto_type]:
                            if variant_name.startswith(cnd):
                                variants.add((variant_name, crypto_type))
                                extract_list.append(tarinfo)
                                incl_candidates.add(cnd)
                                return

        log.info(
            "decompressing archive and determining the list of files to extract..."
        )
        for tarinfo in sc_tar:
            match_tarinfo(tarinfo)

        candidates_not_found = (
            set(lwc_candidates["aead"] + lwc_candidates["hash"]) - incl_candidates
        )
        assert (
            not candidates_not_found
        ), f"The following candidates were not found in the SUPERCOP archive: {candidates_not_found}"

        log.info("extracting files...")
        tmp_dir = tempfile.mkdtemp()
        sc_tar.extractall(path=tmp_dir, members=extract_list)
        log.info("extraction complete")

        if os.path.exists(candidates_dir):
            shutil.rmtree(candidates_dir)
        shutil.copytree(
            str(pathlib.Path(tmp_dir) / f"supercop-{sc_version}"),
            str(candidates_dir),
            symlinks=True,
        )
        shutil.rmtree(tmp_dir)
        log.info("moved sources to cryptotvgen data dir")
    else:
        candidates_dir = pathlib.Path(candidates_dir)
        for crypto_type in ["aead", "hash"]:
            try:
                dir_iter = (candidates_dir / f"crypto_{crypto_type}").iterdir()
                for sub in dir_iter:
                    log.debug(f"sub={sub}")
                    if sub.is_dir():
                        for impl_dir in impl_src_dirs:
                            impl = sub / impl_dir
                            if impl.exists() and impl.is_dir():
                                vname = sub.name
                                log.debug(f"found variant:{vname} ({crypto_type})")
                                variants.add((vname, crypto_type))
            except FileNotFoundError as e:
                log.warn(
                    f"{e}\ncandidates_dir={candidates_dir} does not have a crypto_{crypto_type}/{impl_src_dirs} sub directory!\n"
                )

    variants = filter_variants(variants)

    build_variants(variants, candidates_dir)
