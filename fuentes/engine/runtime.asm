; GRIT-derived ZX Spectrum 48K workbench - separate engine + game.
; Machine code starts at 0x8000. BASIC loader: CLEAR 32767, LOAD CODE,
; RANDOMIZE USR 32768. Stack is at 0x7FF0 (outside framebuffer).
org 0x8000
entry:
 di
 ld sp,0x7ff0
 xor a
 out (0xfe),a
 call engine_quality_init
 ei
 call title_show
 call demo_init
main_loop:
 halt
 halt                     ; ~25 game updates/s with 50Hz PAL interrupts
 ld a,1
 ld (engine_last_phase),a
 call engine_guard_frame
 call engine_tick
 ld a,2
 ld (engine_last_phase),a
 call demo_frame
 ld a,3
 ld (engine_last_phase),a
 call engine_guard_frame
 ld a,(full_redraw)
 or a
 jp z,frame_present_dirty
 ld a,4
 ld (engine_last_phase),a
 call present_full
 jp main_loop
frame_present_dirty:
 ld a,4
 ld (engine_last_phase),a
 call present_dirty
 jp main_loop
; Splash screen with ROM font, no proprietary Grit assets.
title_show:
 call screen_clear
 ld d,5
 ld e,7
 ld hl,title_line1
 call text_draw
 ld d,8
 ld e,4
 ld hl,title_line2
 call text_draw
 ld d,12
 ld e,7
 ld hl,title_line3
 call text_draw
 ld d,18
 ld e,7
 ld hl,title_line4
 call text_draw
 call present_full
 call space_release
 call space_press
 ret
title_line1: db "GRIT ENGINE V0.3",0
title_line2: db "ZX48 Z80 LAB",0
title_line3: db "QAOP / SPACE",0
title_line4: db "PULSA SPACE",0
