; GRIT ENGINE 0.3: HALCONES-derived eight-phase pixel renderer.
; Uses the GRIT 0.2 shadow RAM (6000-77FF), attributes (7800-7AFF),
; dirty queue and map restoration. Neither HALCONES' planes C000-EFFF
; nor its packed game-specific tables are copied into this memory map.
; Input for pixel_draw_16: HL=phase table (8 DW), D=pixel Y, E=pixel X,
; A=attribute (INK/PAPER). Uses a 16x16 sprite. Preserves AF/BC/DE/HL.
; Explicitly rejects X>176 or Y>176 and never paints HUD columns 24..31.
; Composition contract: restore ALL previous actors, then draw ALL current.
;
; Input for pixel_restore_16: D=pixel Y E=pixel X. Preserves AF/BC/DE/HL.
; On odd X/Y offset, a sprite can touch three cell columns/rows.

pixel_draw_16:
 push af
 push bc
 push de
 push hl
 ld (px_phase_table),hl
 ld (px_attr),a
 ld a,d
 ld (px_y),a
 cp 177
 jp nc,px_draw_done
 ld a,e
 ld (px_x),a
 cp 177
 jp nc,px_draw_done
 ; Phase lookup: eight pre-shifted variants, phase=X AND 7.
 ld a,e
 and 7
 ld c,a
 ld b,0
 ld hl,(px_phase_table)
 add hl,bc
 add hl,bc
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld (px_data_ptr),hl
 ex de,hl
 ld a,(px_x)
 and 7
 ld a,3
 jp nz,px_width_ready
 ld a,2
px_width_ready:
 ld (px_row_bytes),a
 call px_area_setup
 call px_area_dirty_and_attr
 xor a
 ld (px_row),a
px_draw_row:
 ; pixel screen address for Y+row and byte X>>3.
 ld a,(px_y)
 ld d,a
 ld a,(px_row)
 add a,d
 ld d,a
 call px_shadow_line
 ld de,(px_data_ptr)
 ld a,(px_row_bytes)
 ld b,a
px_draw_byte:
 ; source pairs are MASK, OR-ink; pixels in private shadow only.
 ld a,(de)
 ld c,a
 ld a,(hl)
 and c
 ld c,a
 inc de
 ld a,(de)
 or c
 ld (hl),a
 inc de
 inc hl
 djnz px_draw_byte
 ex de,hl
 ld (px_data_ptr),hl
 ex de,hl
 ld a,(px_row)
 inc a
 ld (px_row),a
 cp 16
 jp nz,px_draw_row
px_draw_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

pixel_restore_16:
 push af
 push bc
 push de
 push hl
 ld a,d
 ld (px_y),a
 cp 177
 jp nc,px_restore_done
 ld a,e
 ld (px_x),a
 cp 177
 jp nc,px_restore_done
 call px_area_setup
 ld a,(px_first_row)
 ld (px_cur_row),a
px_restore_row:
 ld a,(px_first_col)
 ld (px_cur_col),a
px_restore_col:
 ld a,(px_cur_row)
 ld d,a
 ld a,(px_cur_col)
 ld e,a
 call map_restore
 ld a,(px_cur_col)
 inc a
 ld (px_cur_col),a
 ld b,a
 ld a,(px_last_col)
 cp b
 jp nc,px_restore_col
 ld a,(px_cur_row)
 inc a
 ld (px_cur_row),a
 ld b,a
 ld a,(px_last_row)
 cp b
 jp nc,px_restore_row
px_restore_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; Calculate first and last touched cell of the 16x16 pixel rectangle.
; Only safe x/y <=176 reaches here; last cell always <=23.
px_area_setup:
 ld a,(px_x)
 rrca
 rrca
 rrca
 and 31
 ld (px_first_col),a
 ld a,(px_x)
 add a,15
 rrca
 rrca
 rrca
 and 31
 ld (px_last_col),a
 ld a,(px_y)
 rrca
 rrca
 rrca
 and 31
 ld (px_first_row),a
 ld a,(px_y)
 add a,15
 rrca
 rrca
 rrca
 and 31
 ld (px_last_row),a
 ret

px_area_dirty_and_attr:
 ld a,(px_first_row)
 ld (px_cur_row),a
px_dirty_row:
 ld a,(px_first_col)
 ld (px_cur_col),a
px_dirty_col:
 ld a,(px_cur_row)
 ld d,a
 ld a,(px_cur_col)
 ld e,a
 ld a,(px_attr)
 call mark_dirty
 call attribute_addr
 ld a,(px_attr)
 ld (hl),a
 ld a,(px_cur_col)
 inc a
 ld (px_cur_col),a
 ld b,a
 ld a,(px_last_col)
 cp b
 jp nc,px_dirty_col
 ld a,(px_cur_row)
 inc a
 ld (px_cur_row),a
 ld b,a
 ld a,(px_last_row)
 cp b
 jp nc,px_dirty_row
 ret

; Input D=actual pixel Y (0..191); uses px_x. Output HL shadow address.
; Screen layout: 6000 + ((Y&0xc0)<<5) + ((Y&7)<<8)
;                       + ((Y&0x38)<<2) + (X>>3).
px_shadow_line:
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
 ld a,(px_x)
 rrca
 rrca
 rrca
 and 31
 add a,l
 ld l,a
 ret

px_phase_table: dw 0
px_data_ptr: dw 0
px_x: db 0
px_y: db 0
px_attr: db 7
px_row_bytes: db 2
px_row: db 0
px_first_col: db 0
px_last_col: db 0
px_first_row: db 0
px_last_row: db 0
px_cur_col: db 0
px_cur_row: db 0
