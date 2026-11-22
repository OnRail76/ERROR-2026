"""Compile the game's editable 16x16 sprites and title lettering."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT = {
    "E": (31, 16, 16, 30, 16, 16, 31),
    "R": (30, 17, 17, 30, 20, 18, 17),
    "O": (14, 17, 17, 17, 17, 17, 14),
    "2": (14, 17, 1, 2, 4, 8, 31),
    "0": (14, 17, 19, 21, 25, 17, 14),
    "6": (6, 8, 16, 30, 17, 17, 14),
}

def data(values):
    return " db " + ",".join(map(str, values))

def logo_tiles():
    canvas = [[0] * 192 for _ in range(32)]
    for word, left in [("ERROR", 13), ("2026", 111)]:
        for i, letter in enumerate(word):
            for y, bits in enumerate(FONT[letter]):
                for x in range(5):
                    if bits & (16 >> x):
                        start = left + i * 18 + x * 3
                        for dy in range(3):
                            row = canvas[4 + 3*y + dy]
                            row[start:start+3] = [1, 1, 1]
    for x in range(11, 183):
        canvas[0][x] = canvas[30][x] = int(x < 85 or x >= 106)
    yield "arena_logo_tiles:"
    for y in range(0, 32, 8):
        for x in range(0, 192, 8):
            yield data(sum(p << (7-j) for j, p in enumerate(row[x:x+8]))
                       for row in canvas[y:y+8])

def sprite_tiles(aux):
    sprites = json.loads((ROOT / "assets/error2026_enemies.json").read_text())
    for name, sprite in sprites.items():
        if (name.endswith("_alt") and name != "player_alt") != aux:
            continue
        prefix = "space_or_" + name
        rows = [sum(1 << (15-i) for i, c in enumerate(row) if c == "#")
                for row in sprite["pixels"]]
        padded = [0, *rows, 0]
        yield prefix + "_phases:"
        yield " dw " + ",".join(f"{prefix}_phase{i}" for i in range(8))
        for shift in range(8):
            yield f"{prefix}_phase{shift}:"
            for y, pixels in enumerate(rows):
                # Preserve overlapping edges beyond the 16x16 footprint.
                near = padded[y] | pixels | padded[y+2]
                silhouette = (near | near << 1 | near >> 1) & 65535
                cut = (silhouette << (8-shift)) ^ 0xffffff
                ink = pixels << (8-shift)
                octets = (16, 8) if shift == 0 else (16, 8, 0)
                yield data(v >> bit & 255 for bit in octets for v in (cut, ink))

def smiley_tiles():
    rows = (ROOT / "assets/smiley.txt").read_text().splitlines()
    assert len(rows) == 48 and all(len(row) == 48 for row in rows)
    yield "boss_tiles:"
    for y in range(0, 48, 8):
        for x in range(0, 48, 8):
            yield data(sum((128 >> j) for j, c in enumerate(row[x:x+8]) if c == "#")
                       for row in rows[y:y+8])

def assemble_art(aux=False):
    logo = () if aux else (*logo_tiles(), *smiley_tiles(), *hud_art())
    return "\n".join((*logo, *sprite_tiles(aux), *title_captions(aux))) + "\n"

# Five-pixel HUD capitals. Each value encodes one 5-pixel scanline.
HUD_FONT = {
    **FONT, "O": (14,17,17,17,17,17,14),
    "A": (14,17,17,31,17,17,17), "C": (15,16,16,16,16,16,15),
    "D": (30,17,17,17,17,17,30), "F": (31,16,16,30,16,16,16),
    "G": (15,16,16,23,17,17,15), "I": (14,4,4,4,4,4,14),
    "L": (16,16,16,16,16,16,31), "M": (17,27,21,17,17,17,17),
    "N": (17,25,21,19,17,17,17), "P": (30,17,17,30,16,16,16),
    "Q": (14,17,17,17,21,18,13), "J": (7,2,2,2,2,18,12),
    "S": (15,16,16,14,1,1,30), "T": (31,4,4,4,4,4,4),
    "U": (17,17,17,17,17,17,14), "V": (17,17,17,17,17,10,4),
    "Y": (17,17,10,4,4,4,4),
}

def hud_title():
    # Expand the vertical stems in the 5-pixel logo font to 7 pixels,
    # then pack each line around the exact centre of the panel interior.
    for word, name, spacing in (("ERROR", "error", 1), ("2026", "year", 3)):
        yield f"hud_title_{name}:"
        width = len(word)*7 + (len(word)-1)*spacing
        left = (48-width)//2
        rows = []
        for y in range(7):
            line = 0
            for i, letter in enumerate(word):
                glyph = FONT[letter][y]
                wide = ((glyph & 16) << 2) | ((glyph & 16) << 1) | ((glyph & 14) << 1) | (3 if glyph & 1 else 0)
                line |= wide << (41-left-i*(7+spacing))
            rows.append(line)
        rows.append(0)
        for shift in range(40, -1, -8):
            yield data(row >> shift & 255 for row in rows)


def hud_art():
    yield from hud_title()
    yield "hud_sectors: dw hud_anden,hud_tunel,hud_dique,hud_red,hud_forja,hud_nucleo"
    for word in ("PUNTOS", "PANTALLA", "VIDAS", "SMILEY", "ANDEN",
                 "TUNEL", "DIQUE", "RED", "FORJA", "NUCLEO"):
        yield "hud_" + {"PUNTOS":"points", "PANTALLA":"screen",
                       "VIDAS":"lives"}.get(word, word.lower()) + ":"
        left = (48 - (len(word)*6-1))//2
        rows = [sum(HUD_FONT[c][y] << (43-left-6*i) for i,c in enumerate(word))
                for y in range(7)] + [0]
        for shift in range(40,-1,-8):
            yield data(row >> shift & 255 for row in rows)
    yield "hud_digits:"
    digits = (
        (62,99,99,99,99,99,99,99,62), (12,28,12,12,12,12,12,12,63),
        (62,99,3,6,12,24,48,96,127), (126,3,3,6,30,3,3,99,62),
        (6,14,30,54,102,102,127,6,6), (127,96,96,126,3,3,3,99,62),
        (30,48,96,126,99,99,99,99,62), (127,3,6,6,12,12,24,24,24),
        (62,99,99,99,62,99,99,99,62), (62,99,99,99,63,3,3,6,60),
    )
    for glyph in (*digits, (1,3,6,12,24,48,96,64,64)):
        yield data((*glyph, 0, 0, 0, 0, 0, 0, 0))

# The title uses the same five-column outlines as the dashboard logo.
TITLE_GLYPHS = {
    **HUD_FONT,
    "4": (2,6,10,18,31,2,2), "8": (14,17,17,14,17,17,14),
    "K": (17,18,20,24,20,18,17), "W": (17,17,17,21,21,27,17),
    " ": (0,)*7, ".": (0,0,0,0,0,0,4), "/": (1,1,2,4,8,16,16),
}

def title_captions(aux):
    for label, row, words in (
        ("spectrum", 2, "SPECTRUM 48K"), ("future", 10, "2026... EL FUTURO"),
        ("controls", 14, "Q A O P / SPACE O FIRE"), ("author", 21, "TONY C. WARE"),
    ):
        if aux != (label in ("future", "controls")):
            continue
        width = len(words)*6 - 1
        left = (256-width)//2
        start = left//8
        inset = left%8
        cells = (inset+width+7)//8
        yield f"title_{label}:"
        yield data((row, start, cells))
        rows = [sum(TITLE_GLYPHS[c][y] << (cells*8-inset-5-i*6)
                    for i,c in enumerate(words)) for y in range(7)] + [0]
        for shift in range((cells-1)*8, -1, -8):
            yield data(value >> shift & 255 for value in rows)
