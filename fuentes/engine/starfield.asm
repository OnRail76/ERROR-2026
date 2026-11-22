; GRIT ENGINE 0.3: optional space renderer, adapted from the architectural
; lessons of HALCONES' two-bank 32-star cached starfield.
; 32 point-stars, speed 1 or 2 px per update, black-background mode only.
; Coordinates in 192x192 playfield; HUD x192..255 is NEVER touched.
; Call stars_init once after clearing black screen. Per frame:
;   restore actors from BLACK background, stars_step, draw actors/bullets.
; Do not use over populated tile maps; clearing points destroys map pixels.
; For static backgrounds use starfield not this destructive black-only version.

stars_init:
 ld hl,star_seed
 ld de,star_slots
 ld bc,96
 ldir
 ret

stars_draw:
 push bc
 push de
 push ix
 ld ix,star_slots
 ld b,32
stars_draw_next:
 push bc
 ld e,(ix+0)
 ld d,(ix+1)
 ld a,1
 call star_plot
 ld de,3
 add ix,de
 pop bc
 djnz stars_draw_next
 pop ix
 pop de
 pop bc
 ret

stars_step:
 push bc
 push de
 push ix
 ld ix,star_slots
 ld b,32
stars_step_next:
 push bc
 ld e,(ix+0)
 ld d,(ix+1)
 xor a
 call star_plot
 ld a,(ix+1)
 ld c,a
 ld a,(ix+2)
 add a,c
 cp 192
 jp c,stars_y_store
 sub 192
stars_y_store:
 ld (ix+1),a
 ld e,(ix+0)
 ld d,a
 ld a,1
 call star_plot
 ld de,3
 add ix,de
 pop bc
 djnz stars_step_next
 pop ix
 pop de
 pop bc
 ret

; A=0 erase pixel, A=1 light pixel, D=Y E=X (both 0..191).
; Preserves caller AF BC DE HL. Uses shadow bitmap and dirty tile queue.
star_plot:
 push af
 push bc
 push de
 push hl
 ld (star_action),a
 ld a,d
 cp 192
 jp nc,star_plot_done
 ld a,e
 cp 192
 jp nc,star_plot_done
 ; The marked tile must be presented even if only one pixel changed.
 push de
 ld a,d
 rrca
 rrca
 rrca
 and 31
 ld d,a
 ld a,e
 rrca
 rrca
 rrca
 and 31
 ld e,a
 ld a,7
 call mark_dirty
 pop de
 ; Resolve 8-bit pixel mask first; star_screen_addr keeps C unchanged.
 ld a,e
 and 7
 ld c,a
 ld b,0
 ld hl,star_bit_masks
 add hl,bc
 ld c,(hl)
 call star_screen_addr
 ld a,(star_action)
 or a
 jp z,star_plot_clear
 ld a,(hl)
 or c
 ld (hl),a
 jp star_plot_done
star_plot_clear:
 ld a,c
 cpl
 ld c,a
 ld a,(hl)
 and c
 ld (hl),a
star_plot_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; D=Y, E=X actual pixels. Output HL address in 0x6000..0x77FF.
star_screen_addr:
 ld a,d
 and 0xc0
 rrca
 rrca
 rrca
 add a,0x60
 ld b,a
 ld a,d
 and 7
 add a,b
 ld h,a
 ld a,d
 and 0x38
 add a,a
 add a,a
 ld l,a
 ld a,e
 rrca
 rrca
 rrca
 and 31
 add a,l
 ld l,a
 ret

star_action: db 0
star_bit_masks: db 128,64,32,16,8,4,2,1
star_slots: ds 96
star_seed:
 db 13,7,2
 db 60,68,1
 db 107,129,1
 db 154,190,2
 db 9,59,1
 db 56,120,1
 db 103,181,2
 db 150,50,1
 db 5,111,1
 db 52,172,2
 db 99,41,1
 db 146,102,1
 db 1,163,2
 db 48,32,1
 db 95,93,1
 db 142,154,2
 db 189,23,1
 db 44,84,1
 db 91,145,2
 db 138,14,1
 db 185,75,1
 db 40,136,2
 db 87,5,1
 db 134,66,1
 db 181,127,2
 db 36,188,1
 db 83,57,1
 db 130,118,2
 db 177,179,1
 db 32,48,1
 db 79,109,2
 db 126,170,1
