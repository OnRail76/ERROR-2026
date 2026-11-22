; GRIT V0.3.1 SPACE FAST -- rect compositor adapted from HALCONES' register-held
; 2/3-byte scanline loops; space-only (black sky), independent of main renderer.
; D=Y E=X (top-left) for all routines, X,Y 0..176, never touches HUD.
; Space sky at C000..D7FF; shadow work 6000..77FF; live 4000..57FF.

space_rect_params:
 ld a,d
 cp 177
 ret nc
 ld a,e
 cp 177
 ret nc
 ld a,d
 ld (space_rect_y),a
 ld a,e
 ld (space_rect_x),a
 and 7
 ld a,3
 jp nz,space_rect_wide
 ld a,2
space_rect_wide:
 ld (space_rect_width),a
 scf
 ret

space_rect_dst:
 ld a,(space_rect_y)
 ld d,a
 ld a,(space_rect_x)
 ld e,a
 ld a,(space_rect_x)
 ld (px_x),a
 call px_shadow_line
 ld a,h
 add a,0x60
 ld h,a                ; convert generic 6000 address to work C000
 ex de,hl              ; DE=shadow destination byte
 ret

space_rect_restore:
 push af
 push bc
 push de
 push hl
 call space_rect_params
 jp nc,srr_done
 call space_rect_dst
 ld h,d
 ld l,e
 ld a,h
 add a,0x18
 ld h,a                 ; source sky D800
 ld a,(space_rect_width)
 cp 2
 ld bc,32
 jp z,srr_row2
 ld bc,48
srr_row3:
 ldi
 ldi
 ldi
 jp po,srr_done
 ld a,e
 sub 3
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,srr_row3
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,srr_row3
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp srr_row3
srr_row2:
 ldi
 ldi
 jp po,srr_done
 ld a,e
 sub 2
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,srr_row2
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,srr_row2
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp srr_row2
srr_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

space_rect_draw:
 ; HL=8 DW phase table, D=Y E=X. OR-only because black-backed stars.
 push af
 push bc
 push de
 push hl
 ld (space_rect_source),hl
 call space_rect_params
 jp nc,srd_done
 ld a,(space_rect_x)
 and 7
 add a,a
 ld c,a
 ld b,0
 ld hl,(space_rect_source)
 add hl,bc
 ld e,(hl)
 inc hl
 ld d,(hl)
 push de
 call space_rect_dst
 pop hl               ; HL=pre-shifted OR bytes, DE=shadow destination
 ld b,16
 ld a,(space_rect_width)
 cp 2
 jp z,srd_row2
srd_row3:
 ld a,(de)
 or (hl)
 ld (de),a
 inc hl
 inc e
 ld a,(de)
 or (hl)
 ld (de),a
 inc hl
 inc e
 ld a,(de)
 or (hl)
 ld (de),a
 inc hl
 ld a,e
 sub 2
 ld e,a
 inc d
 ld a,d
 and 7
 jp nz,srd_row3_next
 ld a,e
 add a,32
 ld e,a
 jp c,srd_row3_next
 ld a,d
 sub 8
 ld d,a
srd_row3_next:
 djnz srd_row3
 jp srd_done
srd_row2:
 ld a,(de)
 or (hl)
 ld (de),a
 inc hl
 inc e
 ld a,(de)
 or (hl)
 ld (de),a
 inc hl
 ld a,e
 sub 1
 ld e,a
 inc d
 ld a,d
 and 7
 jp nz,srd_row2_next
 ld a,e
 add a,32
 ld e,a
 jp c,srd_row2_next
 ld a,d
 sub 8
 ld d,a
srd_row2_next:
 djnz srd_row2
srd_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

space_rect_present:
 push af
 push bc
 push de
 push hl
 call space_rect_params
 jp nc,srp_done
 call space_rect_dst
 ld h,d
 ld l,e               ; HL=shadow work 6000
 ld a,d
 sub 0x80
 ld d,a               ; DE=live 4000 from work C000
 ld a,(space_rect_width)
 cp 2
 ld bc,32
 jp z,srp_row2
 ld bc,48
srp_row3:
 ldi
 ldi
 ldi
 jp po,srp_done
 ld a,e
 sub 3
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,srp_row3
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,srp_row3
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp srp_row3
srp_row2:
 ldi
 ldi
 jp po,srp_done
 ld a,e
 sub 2
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,srp_row2
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,srp_row2
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp srp_row2
srp_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; FAST 16x16 color update: calculate the attribute row start ONCE.
; Replaces GRIT's per-tile calling convention and dirty queue.
; D=Y E=X A=attr, preserve standard registers. All sprites x/y <=176.
space_rect_color:
 push af
 push bc
 push de
 push hl
 ld (space_color_value),a
 call space_color_setup
 jp nc,space_color_done
 ld a,(space_color_rows)
 ld b,a
space_color_row:
 ld a,(space_color_value)
 ld (hl),a
 inc hl
 ld (hl),a
 ld a,(space_color_three)
 or a
 jp z,space_color_col_done
 inc hl
 ld a,(space_color_value)
 ld (hl),a
space_color_col_done:
 ld a,(space_color_three)
 or a
 ld de,31
 jp z,space_color_advance
 ld de,30
space_color_advance:
 add hl,de
 djnz space_color_row
space_color_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

; Copy color attributes from private RAM to physical screen once the frame is ready.
space_rect_present_colors:
 push af
 push bc
 push de
 push hl
 call space_color_setup
 jp nc,space_present_color_done
 ld a,(space_color_rows)
 ld b,a
space_present_color_row:
 push hl
 ld a,h
 sub 0x20
 ld d,a
 ld e,l
 ld a,(hl)
 ld (de),a
 inc hl
 inc de
 ld a,(hl)
 ld (de),a
 ld a,(space_color_three)
 or a
 jp z,space_present_color_skip_third
 inc hl
 inc de
 ld a,(hl)
 ld (de),a
space_present_color_skip_third:
 pop hl
 ld de,32
 add hl,de
 djnz space_present_color_row
space_present_color_done:
 pop hl
 pop de
 pop bc
 pop af
 ret

space_color_setup:
 ; Reject completely out-of-field rectangles.
 ld a,d
 cp 177
 ret nc
 ld a,e
 cp 177
 ret nc
 ld a,e
 and 7
 jp z,space_color_two
 ld a,1
 ld (space_color_three),a
 jp space_color_xready
space_color_two:
 xor a
 ld (space_color_three),a
space_color_xready:
 ld a,d
 and 7
 ld a,3
 jp nz,space_color_yready
 ld a,2
space_color_yready:
 ld (space_color_rows),a
 ld a,e
 rrca
 rrca
 rrca
 and 31
 ld e,a
 ld a,d
 rrca
 rrca
 rrca
 and 31
 ld d,a
 call attribute_addr
 scf
 ret

space_color_three: db 0
space_color_rows: db 2
; D=Y, E=X point: copy shadow byte to current visible without dirty flags.
space_present_dot:
 push af
 push de
 push hl
 call star_screen_addr
 ld a,h
 add a,0x60
 ld h,a
 ld a,(hl)
 ld d,a
 ld a,h
 sub 0x80
 ld h,a
 ld (hl),d
 pop hl
 pop de
 pop af
 ret

space_rect_x: db 0
space_rect_y: db 0
space_rect_width: db 2
space_rect_source: dw 0
space_color_value: db 7
