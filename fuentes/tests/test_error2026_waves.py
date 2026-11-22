#!/usr/bin/env python3
"""Real assembled Z80 wave roster and AI validation, partial interpreter.
Avoids mockup game state: all wave allocation, AI and palette functions execute
inside the same machine-code VM used for the original build.
"""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from test_error2026 import boot,frame,assert_screen,SYM

RECIPES=[
 (1,1,1,1,2,1,1,1),
 (1,1,2,1,1,2,1,1),
 (1,2,2,1,1,2,1,1),
 (1,1,2,2,3,1,3,1),
 (1,2,3,3,1,2,2,3),
 (1,2,3,4,3,1,2,4),
 (4,1,1,4,2,2,1,4),
 (3,2,4,3,2,4,3,1),
]

def call_z80(v, name, max_steps=160000):
    stop=0x3000
    original_pc=v.pc
    original_sp=v.sp
    v.push(stop)
    v.pc=SYM[name]
    for _ in range(max_steps):
        if v.pc==stop:
            assert v.sp==original_sp, (name,"stack corrupted",v.sp,original_sp)
            v.pc=original_pc
            return
        v.step()
    raise AssertionError(f'Z80 routine {name} did not return')

def count_actor_types(v):
    a=SYM['actor_slots']
    return tuple(v.m[a+i*8] for i in range(8))

def test_rosters():
    v=boot()
    actor=SYM['actor_slots']
    for i, expected in enumerate(RECIPES,1):
        # Calling real spawn code after clearing pool; no invented list formation.
        v.m[actor:actor+128]=bytes(128)
        v.m[SYM['arena_wave']]=i
        call_z80(v,'arena_spawn_wave')
        assert count_actor_types(v)==expected, (i,count_actor_types(v),expected)
        assert v.val('arena_remaining')==8
        assert sum(v.m[actor+j*8]!=0 for j in range(16))==8
        for j in range(8):
            x,y=v.m[actor+j*8+1:actor+j*8+3]
            assert 8<=x<=168 and 8<=y<=168,('spawn bound',i,j,x,y)
    signatures = set()
    for stage in range(1,31):
        v.m[SYM['arena_wave']]=stage
        call_z80(v,'arena_load_screen')
        roster = bytes(v.m[actor:actor+64])
        assert roster not in signatures
        signatures.add(roster)
        assert v.val('arena_remaining') == 8
        assert v.val('arena_sector') == (stage-1)//5
        assert bytes(v.m[SYM['arena_wave_digits']:SYM['arena_wave_digits']+5]) == f'{stage:02}/30'.encode()
        for offset in range(0, 64, 8):
            enemy, x, y, _, _, hp, *_ = roster[offset:offset+8]
            assert 1 <= enemy <= 4 and 8 <= x <= 168 and 8 <= y <= 168
            assert hp == ((4 if stage >= 16 else 3) if enemy == 3 else
                          (2 if stage >= 16 and enemy == 4 else 1))
        assert_screen(v, stage)
    print('PASS: 30 unique formations and rosters, six sectors, armor and viewport')

def test_ai_and_bounds():
    v=boot()
    actor=SYM['actor_slots']
    v.m[SYM['lab_ship_x']]=90
    v.m[SYM['lab_ship_y']]=90
    v.m[SYM['lab_frame']]=0
    def one(t,x=70,y=70,age=0):
        v.m[actor:actor+128]=bytes(128)
        v.m[actor:actor+8]=bytes([t,x,y,0,0,1,age,0])
        call_z80(v,'arena_chase')
        return tuple(v.m[actor+1:actor+3]),v.m[actor+6]
    assert one(1)[0] == (71,70)
    assert one(2)[0] == (70,70)
    assert one(2,x=20,age=3)[0] == (21,70)
    v.set('arena_walk_rng', 1)
    assert one(3)[0] == (69,70)
    assert one(4)[0] == (69,70)
    assert one(4,x=110)[0] == (111,70)
    v.set("lab_ship_x", 180)
    v.m[actor:actor+8] = bytes([4,11,11,1,0,1,0,0])
    for _ in range(155):
        call_z80(v,'arena_chase')
    assert list(v.m[actor+1:actor+4]) == [165,11,2]
    call_z80(v,'arena_chase')
    call_z80(v,'arena_chase')
    assert list(v.m[actor+1:actor+4]) == [165,12,3]
    # 192 consecutive Z80 updates for each AI at four corners. Guard against
    # 8-bit wrap that famously broke HALCONES Crow on death at zero score.
    for t in range(1,5):
        for sx,sy,hx,hy in [(8,8,168,168),(168,168,8,8),(8,168,168,8),(168,8,8,168)]:
            v.m[SYM['lab_ship_x']]=hx;v.m[SYM['lab_ship_y']]=hy
            v.m[actor:actor+128]=bytes(128)
            v.m[actor:actor+8]=bytes([t,sx,sy,0,0,1,0,0])
            for f in range(192):
                v.m[SYM['lab_frame']]=f%256
                call_z80(v,'arena_chase')
                x,y=v.m[actor+1:actor+3]
                assert 8<=x<=168 and 8<=y<=168,('bad coordinate',t,sx,sy,f,x,y)
    print('PASS: distinct machine-code AI patterns, safe in all corners over 3,072 Z80 moves')

def test_palette_and_sprites():
    v=boot()
    for t,c in [(1,0x44),(2,0x45),(3,0x42),(4,0x43)]:
        v.r[7]=t
        call_z80(v,'arena_enemy_color')
        assert v.r[7]==c,(t,hex(v.r[7]))
    colors=[]
    for name in ['hunter','zigzag','embestidor','acechador']:
        phase_addr=SYM['space_or_'+name+'_phases']
        phase0=v.m[phase_addr]|(v.m[phase_addr+1]<<8)
        colors.append(bytes(v.m[phase0:phase0+64]))
    assert len(set(colors))==4,'Graphics are accidentally identical'
    print('PASS: 4 distinct in-game 16x16 sprites and 4 Z80 attribute colors')

def test_mixed_gameplay():
    v=boot()
    v.m[SYM['arena_wave']]=6
    call_z80(v,'arena_load_screen')
    assert count_actor_types(v)==RECIPES[5]
    for t in range(80):
        keys=('P','SPACE') if t<20 else ('Q','SPACE') if t<40 else ('O','SPACE') if t<60 else ('A','SPACE')
        frame(v,keys)
        if t%10==0:assert_screen(v,t)
        assert v.val('engine_error_code')==0, ('guard',t,v.val('engine_error_code'))
        assert list(v.m[0x7b00:0x7b04])==[0xa5,0x5a,0x3c,0xc3]
    print('PASS: mixed-wave 80 Z80 frames, 4-way fire, video fidelity, memory guards')

if __name__=='__main__':
    test_rosters()
    test_ai_and_bounds()
    test_palette_and_sprites()
    test_mixed_gameplay()

def test_smiley():
    v = boot()
    v.set("arena_wave", 5)
    call_z80(v, "boss_start")
    assert v.val("arena_boss") and v.val("boss_hp") == 8
    slots = SYM["bullet_slots"]
    v.set("boss_old_x", 120)
    v.set("boss_old_y", 144)
    v.set("boss_timer", 1)
    frame(v, ("O",))
    assert list(v.m[slots+72:slots+75]) == [3, 98, 99]
    assert_screen(v, "smiley fires")
    for _ in range(10):
        frame(v, ("O",))
        assert_screen(v, "moving ball")
    x, y = v.val("lab_ship_x"), v.val("lab_ship_y")
    v.m[slots+78:slots+84] = bytes([2, x+8, y+8, 0, 0, 2])
    v.set("arena_invuln", 0)
    frame(v)
    assert v.val("arena_death") == 15
    for _ in range(15):
        frame(v)
    assert v.val("arena_boss") and v.val("boss_hp") == 8 and v.val("arena_lives") == 2
    for _ in range(8):
        v.m[slots:slots+6] = bytes([1, 96, 105, 0, 0, 2])
        frame(v)
    assert not v.val("boss_hp")
    assert v.val("boss_party") == 40
    for _ in range(40):
        frame(v)
    assert v.val("arena_wave") == 6 and not v.val("arena_boss")
    print("PASS: boss uses saved-position aim, appears again on retry, and gates progression")

if __name__ == "__main__":
    test_smiley()

def test_patrol_dash():
    v = boot()
    actor = SYM["actor_slots"]
    v.m[actor:actor+128] = bytes(128)
    v.m[actor:actor+8] = bytes([4,11,80,1,0,1,0,0])
    v.set("lab_ship_x",120)
    v.set("lab_ship_y",80)
    call_z80(v,"arena_chase")
    assert v.m[actor+7] == 128
    for _ in range(10):
        call_z80(v,"arena_chase")
        assert list(v.m[actor+1:actor+3]) == [11,80]
    v.set("lab_ship_y",100)
    for _ in range(77):
        call_z80(v,"arena_chase")
    assert list(v.m[actor+1:actor+5]) == [165,80,3,0]
    call_z80(v,"arena_chase")
    assert v.m[actor+2] == 81
    print("PASS: patrol warns, crosses the fixed lane and resumes at the other edge")

if __name__ == "__main__":
    test_patrol_dash()
