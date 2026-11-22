; ERROR 2026 48K. Code at 8000, stack at 7FF0.
org 0x8000
entry:
 di
 ld sp,0x7ff0
 xor a
 out (0xfe),a
 call engine_quality_init
 call arena_interrupt_init
 ei
 call title_show
 call demo_init
 ld a,(0x5c78)
 ld (space_frame_stamp),a
main_loop:
 call space_wait_25hz
 call engine_guard_frame
 call engine_tick
 call demo_frame
 call engine_guard_frame
 call arena_audio_tick
 call present_dirty
 call hud_year_glow
 jp main_loop

; Private PAL interrupt. The ROM handler expects System IY, but the
; renderer uses IY as a sprite pointer. Every vector goes to F2F2.
arena_interrupt_init:
 ld hl,0xf000
 ld de,0xf001
 ld bc,256
 ld (hl),0xf2
 ldir
 ld a,0xc3
 ld (0xf2f2),a
 ld hl,arena_interrupt
 ld (0xf2f3),hl
 ld a,0xf0
 ld i,a
 im 2
 ret
arena_interrupt:
 push af
 ld a,(0x5c78)
 inc a
 ld (0x5c78),a
 pop af
 ei
 reti

title_show:
 call screen_clear
 call arena_menu_frame
 call arena_logo
 ld hl,title_spectrum
 ld a,0x45
 call title_caption
 ld hl,title_future
 ld a,0x47
 call title_caption
 ld hl,title_controls
 call title_caption
 ld a,0x68
 ld (text_attr),a
 ld d,18
 ld hl,title_line5
 call arena_center_text
 ld hl,title_author
 ld a,7
 call title_caption
 ld a,0x47
 ld (text_attr),a
 xor a
 ld (title_tick),a
 call present_full
 call arena_action_release
 jp arena_action_press

 ; Three-byte header: row, first column, and number of 8x8 cells.
title_caption:
 ld d,(hl)
 inc hl
 ld e,(hl)
 inc hl
 ld b,(hl)
 inc hl
title_caption_cell:
 call blit_cell
 inc e
 push bc
 ld bc,8
 add hl,bc
 pop bc
 djnz title_caption_cell
 ret

; Centre a zero-terminated label on a 32-column display. D=row.
arena_center_text:
 push hl
 ld c,32
arena_center_scan:
 ld a,(hl)
 or a
 jp z,arena_center_draw
 dec c
 inc hl
 jp arena_center_scan
arena_center_draw:
 ld a,c
 and 254
 rrca
 ld e,a
 pop hl
 jp text_draw

arena_menu_frame:
 ld d,0
 call arena_menu_rule
 ld d,23
arena_menu_rule:
 ld e,1
 ld b,30
 ld a,0x45
 ld hl,panel_line
arena_menu_rule_tile:
 call blit_cell
 inc e
 djnz arena_menu_rule_tile
 ret

title_line5: db "  PULSA FUEGO   ",0

; The idle loop updates only live attributes, once per four PAL frames.
title_attract:
 ld a,(engine_state)
 or a
 ret nz
 ld hl,title_tick
 inc (hl)
 ld a,(hl)
 and 3
 ret nz
 ld a,(hl)
 and 32
 ld a,0x68
 jp z,title_prompt_color
 xor a
title_prompt_color:
 ld hl,0x5a48
 ld b,16
title_prompt_cell:
 ld (hl),a
 inc hl
 djnz title_prompt_cell
 ld a,(title_tick)
 rrca
 rrca
 rrca
 and 7
 ld e,a
 ld d,0
 ld hl,title_colors
 add hl,de
 ld a,(hl)
 ld hl,0x58b1
 ld de,21
 ld c,4
title_glow_row:
 ld b,11
title_glow_cell:
 ld (hl),a
 inc hl
 djnz title_glow_cell
 add hl,de
 dec c
 jp nz,title_glow_row
 ret
title_colors: db 2,0x42,0x46,0x47,0x46,0x42,0x42,2
title_tick: db 0

; Keep the HUD's live and shadow attribute cells in sync.
hud_year_glow:
 ld a,(0x5c78)
 and 32
 ld a,0x46
 jp z,hud_year_cells
 ld a,0x42
hud_year_cells:
 ld hl,0x7879
 ld de,0x5879
 ld b,6
hud_year_cell:
 ld (hl),a
 ld (de),a
 inc hl
 inc de
 djnz hud_year_cell
 ret
