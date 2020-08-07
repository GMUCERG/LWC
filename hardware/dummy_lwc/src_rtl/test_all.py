#! /usr/bin/env python3
from pathlib import Path, PurePath, PurePosixPath
import json
import re
import subprocess
import os
import sys

core_path = Path.cwd()
lwc_root = Path('../../..').resolve()
make_cmd = 'gmake'

sources_list = core_path / 'source_list.txt'
variables = {'LWCSRC_DIR': str(lwc_root / 'hardware/LWCsrc')}


def get_lang(file: str):
  for ext in ['vhd', 'vhdl']:
    if file.endswith('.' + ext):
      return 'vhdl'
  if file.endswith('.v'):
      return 'verilog'
  if file.endswith('.sv'):
    return 'system-verilog'


def gen_hdl_prj():
  with open(sources_list, 'r') as f:
    prj = {}
    prj['files'] = []
    data = f.read()
    for var, subst in variables.items():
      data = re.sub(r'\$\(' + var + r'\)', subst, data)
    for file in data.splitlines():
      if not PurePath(file).is_absolute():
        file = str(PurePath(core_path) / file)
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
  verilog_files=[]
  with open(sources_list, 'r') as f:
    prj = {}
    prj['files'] = []
    data = f.read()
    for var, subst in variables.items():
      data = re.sub(r'\$\(' + var + r'\)', subst, data)

    for file in data.splitlines():
      if not PurePath(file).is_absolute():
        file = str(PurePath(core_path) / file)
      if get_lang(file) == 'vhdl':
        vhdl_files.append(file)      
      if get_lang(file) == 'verilog':
        verilog_files.append(file)
  # print(f'VHDL_FILES={vhdl_files}')

  
  orig_design_pkg = Path('design_pkg.vhd').resolve()
  
  for w,ccw in [(32,32), (32,16), (32,8), (16,16), (8,8)]:
    for cfg in ['', 'MS']:
      #TODO impl in python
      replaced_design_pkg = Path(f'design_pkg_{ccw}.vhd').resolve()
      os.system(f"sed 's/:= dummy_lwc_.*/:= dummy_lwc_{ccw};/' {orig_design_pkg} > {replaced_design_pkg}")
      cfg_vhdl_files = [str(replaced_design_pkg) if Path(f).resolve().samefile(orig_design_pkg) else f for f in vhdl_files]
      cp = subprocess.run([make_cmd, 'sim-ghdl',
                           f"VHDL_FILES={' '.join(cfg_vhdl_files)}",
                           f"VERILOG_FILES={' '.join(verilog_files)}",
                           f"CONFIG_LOC=configs/{w}{cfg}config.ini",
                           "REBUILD=1"],
                          )
      cp.check_returncode()

if __name__ == "__main__":
    test_all()
