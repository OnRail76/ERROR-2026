#!/usr/bin/env python3
"""Validated, editable ASCII tiles/sprites/map -> Z80 DB tables (no Pillow required)."""
from pathlib import Path
import json
from tools.pixel_pack import run as pixel_run
ROOT=Path(__file__).resolve().parents[1]

def bytes8(lines):
    assert len(lines)==8 and all(len(s)==8 for s in lines), 'tile/sprite cells must be 8x8'
    assert all(set(s)<=set('.#') for s in lines), 'pixels: use only . and #'
    return [sum((0x80>>x) for x,ch in enumerate(row) if ch=='#') for row in lines]

def emit_table(name,arr,cols=16):
    return name+':\n'+'\n'.join(' db '+','.join(str(x) for x in arr[i:i+cols]) for i in range(0,len(arr),cols))+'\n'

def pack_sprite(lines):
    width=len(lines[0]);height=len(lines)
    assert width%8==0 and height%8==0 and all(len(s)==width for s in lines)
    cells=[]
    for yy in range(0,height,8):
        for xx in range(0,width,8):
            cells+=bytes8([row[xx:xx+8] for row in lines[yy:yy+8]])
    return cells

def run():
    tiles=json.loads((ROOT/'assets/tiles.json').read_text())
    sprites=json.loads((ROOT/'assets/sprites.json').read_text())
    assert 1<=len(tiles)<=256
    keys=[t['key'] for t in tiles]
    assert len(keys)==len(set(keys)) and all(len(k)==1 for k in keys)
    glyphs=[];attrs=[];solid=[]
    for t in tiles:
        glyphs+=bytes8(t['pixels'])
        assert 0<=t['attr']<=255 and t['solid'] in (0,1)
        attrs.append(t['attr']);solid.append(t['solid'])
    lines=['; Generated from assets/tiles.json + sprites.json + map01.txt; do not edit.']
    for name,arr in [('tile_glyphs',glyphs),('tile_attrs',attrs),('tile_solid_flags',solid)]:
        lines.append(emit_table(name,arr))
    for name,s in sprites.items():
        pix=pack_sprite(s['pixels'])
        assert name.isidentifier()
        lines.append(emit_table('sprite_'+name,pix))
        lines.append(emit_table('sprite_'+name+'_mask',[~x & 255 for x in pix]))
    raw=(ROOT/'assets/map01.txt').read_text().splitlines()
    layout=[line for line in raw if line and not line.startswith('# EDITABLE')]
    assert len(layout)==24 and all(len(row)==24 for row in layout), 'Map must be 24x24'
    assert all(set(row)<=set(keys) for row in layout), 'Unknown map key'
    lines.append('level_map:')
    for row in layout:
        lines.append(' db '+','.join(str(keys.index(ch)) for ch in row))
    out=ROOT/'build/assets.asm';out.parent.mkdir(exist_ok=True)
    out.write_text('\n'.join(lines)+'\n')
    pixel_run(sprites)
    print(f'ASSETS: {len(tiles)} tiles, {len(sprites)} sprites, 24x24 map')
    return out

if __name__=='__main__':run()
