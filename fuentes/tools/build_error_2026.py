#!/usr/bin/env python3
"""Rebuild ERROR 2026 for PAL ZX Spectrum 48K using Python only."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.arena_art import assemble_art
from tools.tap_writer import create_tap

def masked_renderer():
    path = ROOT / "engine/space_rect_renderer.asm"
    source = path.read_text()
    # The shared GRIT compositor uses OR. ERROR 2026's data interleaves
    # mask and artwork bytes, so only these five inner-loop sites change.
    original = " ld a,(de)\n or (hl)\n ld (de),a\n inc hl"
    masked = " ld a,(de)\n and (hl)\n inc hl\n or (hl)\n ld (de),a\n inc hl"
    assert source.count(original) == 5, "GRIT sprite loop changed"
    source = source.split("space_present_dot:", 1)[0] + "space_rect_x:" + source.split("space_rect_x:", 1)[1]
    return source.replace(original, masked)

def arena_actors(source):
    start = source.index("actor_pool_step:")
    end = source.index("bullet_pool_step:", start)
    source = source[:start] + source[end:]
    # Twelve player slots followed by four reserved hostile slots.
    source = source.replace(" ld b,24", " ld b,16")
    source = source.replace(" ld b,16\nbullet_alloc_find:",
        " ld b,12\n jp bullet_alloc_find\n"
        "arena_hostile_alloc:\n ld (pool_new_type),a\n"
        " ld a,e\n ld (pool_new_x),a\n ld a,d\n ld (pool_new_y),a\n"
        " ld hl,bullet_slots+72\n ld de,6\n ld b,4\nbullet_alloc_find:")
    source = source.replace(" ld b,16\ncollision_bullet_loop:",
                            " ld b,12\ncollision_bullet_loop:")
    source = source.replace(" ld b,16\ncollision_actor_loop:",
                            " ld b,8\ncollision_actor_loop:")
    source = source.replace(" jp z,collision_next_actor\n ld a,(ix+1)",
                            " jp z,collision_next_actor\n cp 5\n"
                            " jp z,collision_next_actor\n ld a,(ix+1)")
    source = source.replace(" jp z,bullet_step_advance\n ld a,(ix+1)",
                            " jp z,bullet_step_advance\n cp 3\n"
                            " jp z,bullet_step_advance\n ld a,(ix+1)")
    source = source.replace(" cp 185\n jp nc,bullet_step_kill",
                            " cp 2\n jp c,bullet_step_kill\n cp 185\n jp nc,bullet_step_kill")
    return source.replace("collision_kill_actor:\n xor a\n ld (ix+0),a",
                          "collision_kill_actor:\n ld (ix+0),5\n"
                          " ld (ix+6),8\n ld (ix+7),0")

def build_arena():
    (ROOT / "build").mkdir(exist_ok=True)
    def read(path):
        return (ROOT / path).read_text()

    # Link only the GRIT routines used by the arena. The standalone engine
    # build still links its original map, tile, scroll and demo modules.
    pixels = read("engine/pixel_sprites.asm")
    stars = read("engine/starfield.asm")
    fast = read("engine/space_fast.asm")
    modules = [
        read("engine/runtime_error2026.asm"),
        read("engine/quality.asm"),
        read("engine/video.asm").split("blit_masked_cell:")[0],
        "font_cell:" + read("engine/map.asm").split("font_cell:", 1)[1],
        "px_shadow_line:" + pixels.split("px_shadow_line:", 1)[1].split("px_phase_table:")[0]
        + "px_x: db 0",
        "star_screen_addr:" + stars.split("star_screen_addr:", 1)[1].split("star_action:")[0]
        ,
        fast.split("space_restore_16:")[0]
        + "space_fullpresent:" + fast.split("space_fullpresent:", 1)[1],
        read("engine/video_state.asm").replace("map_data: ds 768", "")
            .replace("dirty_pairs: ds 480", "dirty_pairs: equ 0xf101")
            .replace("dirty_flags: ds 768", "dirty_flags: equ 0x5d00"),
        read("engine/keyboard.asm").split("space_release:", 1)[0],
        arena_actors(read("engine/actors.asm")),
        read("game/error_2026.asm"),
        read("game/error_2026_io.asm"),
        read("game/error_2026_screens.asm"),
        read("game/error_2026_boss.asm"),
    ]
    source = "\n".join([*modules, masked_renderer(), assemble_art()])
    source += "\narena_main_end:\n ds 0xf300-arena_main_end\n" + assemble_art(aux=True)
    asm = ROOT / "build/error_2026.asm"
    binary = ROOT / "build/error_2026.bin"
    asm.write_text(source)
    subprocess.run([sys.executable, str(ROOT / "tools/z80_assembler.py"),
                    str(asm), str(binary)], check=True)
    code = binary.read_bytes()
    symbols = json.loads(binary.with_suffix(".sym.json").read_text())
    main_size = symbols["arena_main_end"] - 0x8000
    assert main_size <= 0x4000 and len(code) <= 0x8000, "Arena memory overlap"
    tap = ROOT / "build/ERROR_2026_V1_0_48K.tap"
    create_tap(code[:main_size], "ERROR 2026", tap, 0x8000, [(0xf300, code[0x7300:])])
    digest = hashlib.sha256(tap.read_bytes()).hexdigest()
    (ROOT / "build/error_2026.sha256").write_text(f"{digest}  {tap.name}\n")
    print(f"{tap.name} · {len(code)} bytes de programa · SHA256 {digest}")
    return tap

if __name__ == "__main__":
    build_arena()
