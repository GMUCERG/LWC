import os
import sys
import logging
import re
import shutil
import tarfile
import urllib.request
import tempfile
import pathlib
import shutil
import subprocess
try:
    import importlib.resources as pkg_resources
except ImportError:
    # Try backported to PY<37 `importlib_resources`.
    import importlib_resources as pkg_resources

# TODO change `print`s to appropriate log functions


lwc_candidates = {'hash': ['ace', 'ascon', 'drygascon', 'esch', 'gimli', 'knot', 'photonbeetle',
                           'saturnin', 'skinnyhash', 'subterranean', 'xoodyak'],
                  'aead': ['ace', 'ascon', 'comet', 'drygascon', 'elephant', 'estate', 'paefforkskinny', 'giftcofb', 'gimli',
                           'grain128aead', 'hyena', 'isap', 'knot', 'twegift64locus', 'twegift64lotus', 'mixfeed', 'orange',
                           'oribatida', 'photonbeetle', 'pyjamask', 'romulus', 'saeaes', 'saturnin', 'skinnyaead',
                           'schwaemm', 'spix', 'spoc', 'spook', 'subterranean', 'sundaegift', 'tinyjambu', 'wage', 'xoodyak']}

mkfile_name = 'lwc_cffi.mk'


def ctgen_get_dir(sub_dir=None):
    data_dir = pathlib.Path.home() / '.cryptotvgen'
    if sub_dir:
        data_dir = data_dir / sub_dir
    if not data_dir.exists():
        data_dir.mkdir(parents=True)
    assert data_dir.exists() and data_dir.is_dir()
    return data_dir


def prepare_libs(sc_version, libs, candidates_dir, lib_path):
    # default ctgen data dir root, make sure exists or create
    ctgen_candidates_dir = ctgen_get_dir()

    # TODO
    impl_src_dir = 'ref'

    def build_variants(variants, candidates_dir):
        for vname, vtype in variants:
            # print(f'running make CRYPTO_VARIANT={vname} CRYPTO_TYPE={vtype} in {candidates_dir}')
            cmd = ['make', '-f',  str(ctgen_candidates_dir / mkfile_name), '-C', str(candidates_dir),
                   f'CRYPTO_VARIANT={vname}', f'CRYPTO_TYPE={vtype}', f'CANDIDATE_PATH={candidates_dir}',
                   f'IMPL_SRC_DIR={impl_src_dir}']
            if lib_path:
                print(f"binaries will be available in lib_path={lib_path}")
                cmd.append(f'LIB_PATH={lib_path}')
            cp = subprocess.run(cmd, cwd=candidates_dir)
            try:
                cp.check_returncode()
            except:
                print(f'`{" ".join(cmd)}` failed! (exit code: {cp.returncode})')
                sys.exit(1)
                
    def filter_variants(variants):

        if libs == 'all' or libs == ['all']:
            print(f'building all libs in `crypto_aead` and `crypto_hash` subfolders of candidates_dir={candidates_dir}: variants={variants}')
        else:
            variants = [v for v in variants if any(v[0].startswith(l) for l in libs)]
            print(f'building only the following variants: {variants}')
        return variants  # TODO

    def generate_artifacats():
        ctgen_includes_dir = ctgen_get_dir('includes')

        # TODO add function defs common to cffi
        (ctgen_includes_dir / 'crypto_aead.h').touch()
        (ctgen_includes_dir / 'crypto_hash.h').touch()

        mk_content = pkg_resources.read_text(__package__, mkfile_name)
        with open(ctgen_candidates_dir / mkfile_name, 'w') as f:
            f.write(mk_content)

    def get_sc_tar(version):
        sc_filename = f'supercop-{sc_version}.tar.xz'
        print(f'supercop version: {version}')
        cache_dir = ctgen_get_dir('cache')
        sc_url = f'https://bench.cr.yp.to/supercop/{sc_filename}'
        tar_path = cache_dir / sc_filename
        if tar_path.exists():
            print(f'using cached version of supercop at {tar_path}')
            return tarfile.open(tar_path)
        print(f'Downloading supercop from {sc_url}')
        tar_path = urllib.request.urlretrieve(sc_url, filename=tar_path)[0]
        print(f'Download successfull!')
        return tarfile.open(tar_path)
    



            
    generate_artifacats()

    variants = set()

    if not candidates_dir:
        candidates_dir = ctgen_candidates_dir
        sc_tar = get_sc_tar(sc_version)

        incl_candidates = set()
        extract_list = []

        crypto_dir_regexps = {crypto_type: re.compile(f'supercop-{sc_version}/crypto_{crypto_type}/([^/]+)/{impl_src_dir}/')
                              for crypto_type in lwc_candidates.keys()}

        # TODO make this more efficient, though unlikely to be a performance bottleneck

        def match_tarinfo(tarinfo):
            for crypto_type in lwc_candidates.keys():
                match = crypto_dir_regexps[crypto_type].match(tarinfo.name)
                if match:
                    variant_name = match.group(1)
                    for cnd in lwc_candidates[crypto_type]:
                        if variant_name.startswith(cnd):
                            variants.add((variant_name, crypto_type))
                            extract_list.append(tarinfo)
                            incl_candidates.add(cnd)
                            return

        print('decompressing archive and determining the list of files to extract...')
        for tarinfo in sc_tar:
            match_tarinfo(tarinfo)

        candidates_not_found = set(lwc_candidates['aead'] + lwc_candidates['hash']) - incl_candidates
        assert not candidates_not_found, f"The following candidates were not found in the SUPERCOP archive: {candidates_not_found}"

        print('extracting files...')
        tmp_dir = tempfile.mkdtemp()
        sc_tar.extractall(path=tmp_dir, members=extract_list)
        print('extraction complete')

        shutil.copytree(str(pathlib.Path(tmp_dir) / f'supercop-{sc_version}'),
                        str(candidates_dir), dirs_exist_ok=True)
        shutil.rmtree(tmp_dir)
        print('moved sources to cryptotvgen data dir')
    else:
        candidates_dir = pathlib.Path(candidates_dir)
        for crypto_type in ['aead', 'hash']:
            try:
                dir_iter = (candidates_dir / f'crypto_{crypto_type}').iterdir()
                for sub in dir_iter:
                    if sub.is_dir():
                        impl = sub / impl_src_dir
                        vname = sub.name
                        if impl.exists() and impl.is_dir():
                            print(f"found variant:{vname} ({crypto_type})")
                            variants.add((vname, crypto_type))
            except FileNotFoundError as e:
                sys.exit(f"{e}\ncandidates_dir={candidates_dir} does not have a crypto_{crypto_type}/{impl_src_dir} sub directory!\n")

    variants = filter_variants(variants)

    build_variants(variants, candidates_dir)
