#!/usr/bin/env python3
"""Deterministic clean build -> Z80 machine code / Spectrum TAP / symbols."""
from pathlib import Path
import json, subprocess,sys,hashlib
from tools.asset_pack import run as pack
from tools.tap_writer import create_tap
ROOT=Path(__file__).resolve().parent
ORDER=[
  'engine/runtime.asm',
  'engine/quality.asm',
  'engine/video.asm',
  'engine/map.asm',
  'engine/sprites.asm',
  'engine/pixel_sprites.asm',
  'engine/actors.asm',
  'engine/starfield.asm',
  'engine/scroll.asm',
  'engine/keyboard.asm',
  'engine/audio.asm',
  'game/demo.asm',
  'engine/video_state.asm',
  'build/assets.asm',
  'build/pixel_assets.asm'
]

def build():
    cfg=json.loads((ROOT/'project.json').read_text())
    assert cfg['code_org']==32768 and cfg['stack_top']==32752, 'Current memory map fixed; update loader and tests if relocating'
    pack()
    source='; GENERATED concatenation from modular sources. Edit modules, not build/starter.asm\n'+ '\n'.join((ROOT/part).read_text() for part in ORDER)
    (ROOT/'build/starter.asm').write_text(source)
    subprocess.run([sys.executable,str(ROOT/'tools/z80_assembler.py'),str(ROOT/'build/starter.asm'),str(ROOT/'build/starter.bin')],check=True)
    code=(ROOT/'build/starter.bin').read_bytes()
    assert len(code)<0x7FE0, 'Code overflows ZX Spectrum RAM before ROM!'
    assert 0x8000+len(code)<0xFF00, 'reserve small interrupt-safe upper memory margin'
    dest=ROOT/'build'/cfg['tap_filename']
    create_tap(code,cfg['name'],dest,0x8000)
    h=hashlib.sha256(dest.read_bytes()).hexdigest()
    (ROOT/'build/checksums.sha256').write_text(f'{h}  {dest.name}\n')
    print(f'OK {dest} sha256={h}')
    return dest

if __name__=='__main__':build()
