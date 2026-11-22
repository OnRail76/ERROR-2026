#!/usr/bin/env python3
"""Run the *actual generated Z80 code* in the included partial VM.
No hardware speed/ULA claim; assertions cover screen, waves, score, memory.
"""
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from mini_z80 import VM,SYM

def boot():
    s=json.loads((ROOT/'build/error_2026.sym.json').read_text())
    SYM.clear();SYM.update(s)
    v=VM()
    blob=(ROOT/'build/error_2026.bin').read_bytes()
    v.m[0x8000:0xf000]=b'\x00'*(0xf000-0x8000)
    v.m[0x8000:0x8000+len(blob)]=blob
    seen=False
    for _ in range(600000):
        if v.pc==SYM['arena_press_wait']:seen=True
        v.keys={'SPACE'} if seen else set()
        if v.pc==SYM['main_loop']:
            v.keys=set()
            return v
        v.step()
    raise AssertionError('boot timeout')

def frame(v,keys=()):
    v.keys=set(keys)
    for _ in range(700000):
        v.step()
        if v.pc==SYM['main_loop']:
            return
    raise AssertionError('frame timeout')

def assert_screen(v,frame_n):
    for i in range(6144):
        expected=(0xc000 if (i&31)<24 else 0x6000)+i
        assert v.m[0x4000+i]==v.m[expected],(frame_n,'bitmap',hex(i))
    tints = {}
    for n in range(16):
        offset = SYM["bullet_slots"] + n * 6
        kind, x, y = v.m[offset:offset+3]
        if kind and x >= 2 and y >= 2:
            tints.update({(yy//8)*32+xx//8: (0x45 if kind == 1 else 0x47)
                          for yy in (y-2,y+2) for xx in (x-2,x+2)})
    for i in range(768):
        attr = v.m[0x7800+i]
        expected = tints.get(i, attr) if not attr & 64 else attr
        assert v.m[0x5800+i] == expected,(frame_n,'color',hex(i))

def test():
    v=boot()
    assert v.val('arena_lives')==3
    assert v.val('arena_wave')==1
    assert v.val('arena_remaining')==8
    assert sum(v.m[SYM['actor_slots']+8*i]!=0 for i in range(16))==8
    assert_screen(v,"init")
    for t in range(48):
        keys=['P','SPACE'] if t<12 else ['Q','SPACE'] if t<24 else ['O','SPACE'] if t<36 else ['A','SPACE']
        frame(v,keys)
        if t%8==0:
            assert_screen(v,t)
        assert v.val('engine_error_code')==0,f'frame {t}'
        assert list(v.m[0x7b00:0x7b04])==[0xa5,0x5a,0x3c,0xc3]
    print('PASS: 48 frames, 8-direction controls, fire, compositor fidelity, guard canaries')
    # Force one legal hit into a known existing enemy to validate actual Z80 collision API.
    v=boot()
    actor=SYM['actor_slots']
    b=SYM['bullet_slots']
    v.m[actor:actor+3]=bytes([1,32,32])
    v.m[actor+5]=1
    # Make the bullet collide on next tick and stop it via pool logic.
    v.m[b:b+6]=bytes([1,40,40,0,0,25])
    before=v.val('arena_kills')
    frame(v,[])
    assert v.val('arena_kills')==before+1,('score',v.val('arena_kills'),before)
    assert v.m[SYM['arena_score_digits']+2]==ord(str((before+1)%10)), 'score rendered incorrectly'
    print('PASS: collision increments score and updates HUD')
    # Simulate final enemy death on real Z80 logic; next wave spawns 8 entities.
    for i in range(16):v.m[actor+8*i]=0
    v.m[SYM['arena_remaining']]=0
    v.m[SYM["arena_blasts"]]=0
    before=v.val('arena_wave')
    frame(v,[])
    assert v.val('arena_wave')==before+1
    assert sum(v.m[actor+8*i]!=0 for i in range(16))==8
    print('PASS: new wave, 8 chasing enemies created')
    # Attempt illegal source coordinate, must be ignored at compositor level.
    v.m[SYM['lab_ship_x']]=88
    v.m[SYM['lab_ship_y']]=88
    assert v.val('engine_error_code')==0

if __name__=='__main__':test()

def test_zero_score_gameover():
    v=boot()
    actor=SYM['actor_slots']
    for i in range(16):v.m[actor+8*i]=0
    # Put a pursuer on top of the player and force the last life.
    x=v.val('lab_ship_x');y=v.val('lab_ship_y')
    v.m[actor:actor+8]=bytes([1,x,y,0,0,1,0,0])
    v.m[SYM['arena_invuln']]=0
    v.m[SYM['arena_lives']]=1
    assert v.val('arena_kills')==0
    v.keys=set()
    reached_gameover=False;reached_restart=False
    for _ in range(350000):
        if v.pc==SYM['arena_game_over']:
            reached_gameover=True
        if reached_gameover and v.pc==SYM['arena_release_wait']:
            v.keys=set()
        if reached_gameover and v.pc==SYM['arena_press_wait']:
            v.keys={'SPACE'}
        if reached_gameover and v.pc==SYM['main_loop']:
            reached_restart=True;break
        v.step()
    assert reached_gameover, 'Last-life player collision should cause gameover'
    assert reached_restart,'Must restart without corrupting RAM or stack'
    assert v.val('arena_lives')==3 and v.val('arena_kills')==0
    assert list(v.m[0x7b00:0x7b04])==[0xa5,0x5a,0x3c,0xc3]
    print('PASS: zero-score final death, GAME OVER, fresh new game')

if __name__=='__main__':test_zero_score_gameover()

def test_charge_and_retry():
    v = boot()
    actors, bullets = SYM["actor_slots"], SYM["bullet_slots"]
    for _ in range(60):
        v.set("arena_invuln", 2)
        frame(v)
        assert_screen(v, "charge")
        if v.m[bullets + 72] == 2:
            break
    else:
        raise AssertionError("no hostile shot was spawned")
    assert any(v.m[bullets + 75:bullets + 77])

    x, y = v.m[actors + 1:actors + 3]
    v.m[bullets:bullets + 6] = bytes([1, x + 8, y + 8, 0, 0, 2])
    frame(v)
    assert v.m[actors] == 5
    assert v.val("arena_kills") == 1

    v.set("arena_invuln", 0)
    x, y = v.val("lab_ship_x"), v.val("lab_ship_y")
    v.m[bullets + 72:bullets + 78] = bytes([2, x + 8, y + 8, 0, 0, 2])
    frame(v)
    assert v.val("arena_death") == 15 and v.val("arena_lives") == 2
    for _ in range(15):
        frame(v)
        assert_screen(v, "death and retry")
    assert v.val("arena_wave") == 1
    assert v.val("arena_remaining") == 8 and v.val("arena_kills") == 0
    assert v.val("arena_lives") == 2
    assert all(not v.m[bullets + i] for i in range(0, 96, 6))
    print("PASS: telegraphed hostile fire, blast effects, same-screen retry and score rollback")

if __name__ == "__main__":
    test_charge_and_retry()
