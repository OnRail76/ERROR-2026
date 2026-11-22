#!/usr/bin/env python3
"""Portable preshifted 16x16 1-bit sprites, 8 phases, packed mask+ink.
Porting strategy derived from the 8-phase pre-shift table in HALCONES 1.3.2.
Uses only user-owned editable assets and produces real Z80 source, not art mockups.
"""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]

def generated_sprites(sprites):
    lines=['; GENERATED: 16x16 preshifted sprites, 8 x-phases, mask/ink interleaved.']
    names=[]
    for name, record in sprites.items():
        p=record['pixels']
        if len(p)!=16 or any(len(row)!=16 for row in p):
            continue
        assert all(set(row)<=set('.#') for row in p)
        names.append(name)
        ptr='pixel_sprite_'+name
        lines.append(ptr+'_phases:')
        lines.append(' dw '+','.join(ptr+'_phase'+str(i) for i in range(8)))
        for shift in range(8):
            lines.append(ptr+'_phase'+str(shift)+':')
            width=2 if shift==0 else 3
            for row in p:
                word=sum((1 << (15-i)) for i,ch in enumerate(row) if ch=='#')
                expanded=(word << (8-shift))
                byte_pieces=[(expanded >> (16-8*i))&255 for i in range(width)]
                line=[]
                for value in byte_pieces:
                    line += [255 ^ value,value]
                lines.append(' db '+','.join(str(x) for x in line))
    lines.append('pixel_sprite_count: db '+str(len(names)))
    return '\n'.join(lines)+'\n'

def run(sprites=None):
    if sprites is None:
        sprites=json.loads((ROOT/'assets/sprites.json').read_text())
    dest=ROOT/'build/pixel_assets.asm'
    dest.write_text(generated_sprites(sprites))
    return dest

if __name__=='__main__':
    run()
