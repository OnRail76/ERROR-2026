; GRIT V0.3.1 | SPACE LAB optimized-specific renderer, built from HALCONES 1.3.2 lessons.
; Original general GRIT renderer and V0.3 TAP are preserved.
; Private work C000-D7FF; star sky D800-EFFF. No video RAM contention
; for space composition. GRIT general demo still uses shadow 6000-77FF.
; All sprite overlay is composed in shadow, and stage/background color 7 restored.
; This source is only included in the SPACE LAB build, never the generic GRIT demo.
;
; 16x16 restore: copy 2/3 bytes across 16 rows, NOT 4..9 full 8x8 tiles.
space_fast_init:
 ld hl,0x6000
 ld de,0xc000
 ld bc,6144
 ldir                    ; copy GRIT initial bitmap + HUD to work plane
 xor a
 ld hl,0xd800
 ld de,0xd801
 ld bc,6143
 ld (hl),a
 ldir
 xor a
 ld (space_star_bank),a
 ret

; D=Y, E=X; 16x16 full-safe rectangle, private background only (space mode).
space_restore_16:
 push af
 push bc
 push de
 push hl
 ld a,d
 ld (px_y),a
 cp 177
 jp nc,sf_restore_done
 ld a,e
 ld (px_x),a
 cp 177
 jp nc,sf_restore_done
 call px_area_setup
 ld a,7
 ld (px_attr),a
 call px_area_dirty_and_attr
 ld a,(px_x)
 and 7
 ld a,3
 jp nz,sf_restore_width
 ld a,2
sf_restore_width:
 ld (px_row_bytes),a
 xor a
 ld (px_row),a
sf_restore_row:
 ld a,(px_y)
 ld d,a
 ld a,(px_row)
 add a,d
 ld d,a
 call px_shadow_line
 ld d,h
 ld e,l
 ld a,h
 add a,0x60                  ; 6000..77FF -> C000..D7FF
 ld h,a
 ld a,(px_row_bytes)
 ld c,a
 ld b,0
 ldir
 ld a,(px_row)
 inc a
 ld (px_row),a
 cp 16
 jp nz,sf_restore_row
sf_restore_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; One pixel in two planes (star); preserves all standard registers.
; D=pixel Y E=pixel X, A=0 erase, nonzero draw.
space_star_plot:
 push af
 push bc
 push de
 push hl
 ld (space_plot_action),a
 ld a,d
 cp 192
 jp nc,space_plot_done
 ld a,e
 cp 192
 jp nc,space_plot_done
 ; No per-tile dirty queue in specialized space mode.
 ld a,e
 and 7
 ld c,a
 ld b,0
 ld hl,star_bit_masks
 add hl,bc
 ld c,(hl)
 call star_screen_addr       ; HL=6000...77FF base formula
 ld a,h
 add a,0x60
 ld h,a                   ; actual sprite work C000..D7FF
 ld a,(space_plot_action)
 or a
 jp z,space_star_clear
 ld a,(hl)
 or c
 ld (hl),a
 ld a,h
 add a,0x18
 ld h,a
 ld a,(hl)
 or c
 ld (hl),a
 jp space_plot_done
space_star_clear:
 ld a,c
 cpl
 ld c,a
 ld a,(hl)
 and c
 ld (hl),a
 ld a,h
 add a,0x18
 ld h,a
 ld a,(hl)
 and c
 ld (hl),a
space_plot_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; D=Y, E=X, mark only corresponding tile of full shadow as dirty.
space_mark_dot:
 push af
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
 pop af
 ret

; One pixel bullet drawn ONLY on working shadow, never on background sky.
space_bullet_draw:
 push af
 push bc
 push de
 push hl
 ld a,d
 cp 192
 jp nc,sb_draw_done
 ld a,e
 cp 192
 jp nc,sb_draw_done
 ; No per-tile dirty queue in specialized space mode.
 ld a,e
 and 7
 ld c,a
 ld b,0
 ld hl,star_bit_masks
 add hl,bc
 ld c,(hl)
 call star_screen_addr
 ld a,h
 add a,0x60
 ld h,a
 ld a,(hl)
 or c
 ld (hl),a
sb_draw_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; Restore one byte from the intact sky; never delete a star behind a bullet.
space_bullet_restore:
 push af
 push bc
 push de
 push hl
 ld a,d
 cp 192
 jp nc,sb_restore_done
 ld a,e
 cp 192
 jp nc,sb_restore_done
 ; No per-tile dirty queue in specialized space mode.
 call star_screen_addr
 ld a,h
 add a,0x78
 ld h,a                   ; sky D800
 ld c,(hl)
 ld a,h
 sub 0x18                ; work C000
 ld h,a
 ld (hl),c
sb_restore_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

space_stars_draw:
 push bc
 push de
 push ix
 ld ix,star_slots
 ld b,32
space_stars_draw_loop:
 push bc
 ld e,(ix+0)
 ld d,(ix+1)
 ld a,1
 call space_star_plot
 ld de,3
 add ix,de
 pop bc
 djnz space_stars_draw_loop
 pop ix
 pop de
 pop bc
 ret

; Move only 16 stars/tick, alternating 16-star banks. Speed compensated
; by 2x Y increments on the selected tick (same average as V0.3).
space_stars_step:
 push af
 push bc
 push de
 push ix
 ld a,(space_star_bank)
 xor 1
 ld (space_star_bank),a
 ld ix,star_slots
 or a
 jp z,space_stars_bank_ready
 ld de,48
 add ix,de
space_stars_bank_ready:
 ld b,16
space_stars_step_loop:
 push bc
 ld e,(ix+0)
 ld d,(ix+1)
 xor a
 call space_star_plot
 ld a,(ix+2)
 add a,a
 ld c,a
 ld a,(ix+1)
 add a,c
 cp 192
 jp c,space_stars_y_store
 sub 192
space_stars_y_store:
 ld (ix+1),a
 ld e,(ix+0)
 ld d,a
 ld a,1
 call space_star_plot
 ld de,3
 add ix,de
 pop bc
 djnz space_stars_step_loop
 pop ix
 pop de
 pop bc
 pop af
 ret

; Once at launch, publish complete work bitmap + private color plane.
; GRIT title still uses present_full on its own general screen shadow.
space_fullpresent:
 ld hl,0xc000
 ld de,0x4000
 ld bc,6144
 ldir
 ld hl,0x7800
 ld de,0x5800
 ld bc,768
 ldir
 jp clear_dirty

; Pace to 25 ticks/s using Spectrum ROM FRAMES (23672 / $5C78).
; Unlike unconditional HALT+HALT after presenting, does not add 40ms
; to a game update that has already consumed >=2 vertical intervals.
; Requires an enabled IRQ that advances FRAMES (ROM or private arena IM2).
space_wait_25hz:
 ld a,(0x5c78)
 ld c,a
 ld a,(space_frame_stamp)
 ld b,a
 ld a,c
 sub b
 cp 2
 jp nc,space_wait_ready
 halt
 jp space_wait_25hz
space_wait_ready:
 ld a,c
 ld (space_frame_stamp),a
 ret
space_frame_stamp: db 0

space_star_bank: db 0
space_plot_action: db 0
