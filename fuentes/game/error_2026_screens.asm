; 30 authored encounters. Six districts of five screens.
; Layout pointer, then eight enemy types: pursuer, gunner, wanderer, perimeter patrol.
arena_screens:
 dw form_north
 db 1,1,1,1,2,1,1,1
 dw form_corners
 db 1,1,2,1,1,2,1,1
 dw form_pincer
 db 1,2,2,1,1,2,1,1
 dw form_diagonal
 db 1,1,2,2,3,1,3,1
 dw form_ring
 db 1,2,3,3,1,2,2,3
 dw form_gates
 db 1,2,3,4,3,1,2,4
 dw form_south
 db 4,1,1,4,2,2,1,4
 dw form_flanks
 db 3,2,4,3,2,4,3,1
 dw form_cross
 db 4,3,2,1,4,3,2,1
 dw form_corners
 db 3,4,2,1,4,2,3,4
 dw form_pincer
 db 1,3,2,1,2,3,1,2
 dw form_north
 db 3,1,1,3,2,2,4,4
 dw form_ring
 db 4,2,3,2,4,2,3,2
 dw form_gates
 db 3,2,2,3,4,3,3,4
 dw form_diagonal
 db 3,4,3,4,2,3,2,4
 dw form_flanks
 db 4,4,1,3,3,1,4,4
 dw form_cross
 db 3,4,2,4,3,4,2,4
 dw form_corners
 db 4,2,3,4,3,4,4,2
 dw form_south
 db 3,4,4,3,2,3,3,2
 dw form_pincer
 db 3,4,3,4,3,4,3,4
 dw form_gates
 db 2,3,4,2,2,4,3,2
 dw form_diagonal
 db 4,3,4,3,2,4,3,4
 dw form_flanks
 db 3,4,3,4,2,3,4,3
 dw form_north
 db 3,3,4,3,4,3,4,4
 dw form_ring
 db 4,4,3,3,2,3,4,4
 dw form_south
 db 4,4,1,2,3,3,1,2
 dw form_cross
 db 3,2,1,4,4,3,1,2
 dw form_corners
 db 3,3,2,1,4,4,1,2
 dw form_pincer
 db 4,3,2,1,4,2,1,3
 dw form_core
 db 3,4,2,1,4,2,1,3

form_north:    db 16,16, 76,16, 136,16, 160,64, 16,120, 72,160, 136,160, 160,136
form_corners:  db 16,16, 36,36, 160,16, 140,36, 16,160, 36,140, 160,160, 140,140
form_pincer:   db 12,30, 12,76, 12,122, 12,160, 164,16, 164,56, 164,106, 164,152
form_diagonal: db 12,20, 44,32, 76,44, 142,20, 164,156, 132,144, 100,132, 34,156
form_ring:     db 30,30, 88,12, 146,30, 162,88, 146,146, 88,162, 30,146, 12,88
form_gates:    db 26,16, 66,16, 106,16, 146,16, 26,160, 66,160, 106,160, 146,160
form_south:    db 16,160, 76,160, 136,160, 160,112, 16,56, 72,16, 136,16, 160,40
form_flanks:   db 16,18, 36,48, 12,84, 32,134, 156,158, 140,128, 164,92, 140,42
form_cross:    db 70,18, 106,18, 18,70, 18,106, 158,70, 158,106, 70,158, 106,158
form_core:     db 24,24, 76,28, 149,25, 140,78, 150,152, 100,139, 24,152, 34,96

arena_floor_inks: db 5,1,6,3,4,2
; 8x8 floor stamps, single pixels and short grooves. The arena is open.
arena_floor_tiles:
 db 0,0,0,0,0,0,0x44,0
 db 0,0,0,0,0,0,0x70,0
 db 0,0,0,0,0x10,0,0x08,0
 db 0,0,0x10,0x10,0,0,0,0
 db 0,0,0,0,0x08,0,0x08,0
 db 0,0,0,0,0,0x28,0x10,0
arena_floor_wall: db 0xff,0,0x44,0,0,0,0,0
arena_floor_edge: db 0x80,0x80,0x80,0xa0,0x80,0x80,0x80,0x80
arena_floor_edge_right: db 1,1,1,5,1,1,1,1

arena_floor:
 ld a,(arena_sector)
 add a,a
 add a,a
 add a,a
 ld e,a
 ld d,0
 ld hl,arena_floor_tiles
 add hl,de
 ld (arena_floor_stamp),hl
 ld de,0
arena_floor_row:
 ld e,0
arena_floor_cell:
 ld a,(arena_floor_ink)
 push de
 call attribute_addr
 ld (hl),a
 pop de
 ld hl,arena_floor_wall
 ld a,d
 or a
 jp z,arena_floor_paint
 cp 23
 jp z,arena_floor_paint
 ld hl,arena_floor_edge
 ld a,e
 or a
 jp z,arena_floor_paint
 cp 23
 ld hl,arena_floor_edge_right
 jp z,arena_floor_paint
 ; One rim detail per four tiles in the open floor, staggered by row.
 ld a,d
 and 1
 jp nz,arena_floor_advance
 ld a,(arena_wave)
 ld c,a
 ld a,d
 rrca
 add a,c
 add a,e
 and 3
 jp nz,arena_floor_advance
 ld hl,(arena_floor_stamp)
arena_floor_paint:
 call arena_stamp_cell
arena_floor_advance:
 inc e
 ld a,e
 cp 24
 jp c,arena_floor_cell
 inc d
 ld a,d
 cp 24
 jp c,arena_floor_row
 ret

arena_stamp_cell:
 push de
 push hl
 call playfield_addr
 ld a,h
 add a,0x60
 ld h,a
 ex de,hl
 pop hl
 ld b,8
arena_floor_scan:
 ld a,(hl)
 inc hl
 ld c,a
 ld (de),a
 ld a,d
 add a,0x18
 ld d,a
 ld a,c
 ld (de),a
 ld a,d
 sub 0x17
 ld d,a
 djnz arena_floor_scan
 pop de
 ret
arena_floor_stamp: dw 0

; 24x4 tile logo compiled from the original pixel lettering.
arena_logo:
 ld hl,arena_logo_tiles
 ld de,0x0504
arena_logo_cell:
 ld a,e
 cp 17
 ld a,0x47
 jp c,arena_logo_attr
 ld a,0x42
arena_logo_attr:
 call blit_cell
 ld bc,8
 add hl,bc
 inc e
 ld a,e
 cp 28
 jp c,arena_logo_cell
 ld e,4
 inc d
 ld a,d
 cp 9
 jp c,arena_logo_cell
 ret

; Publish the union of old D/E and new B/C sprite bounds in one pass.
; Gameplay moves by <=2 px per axis, limiting spans to 2..4 bytes and
; 16..18 rows. This avoids writing the overlapping region twice.
arena_present_union:
 ld a,b
 cp d
 jp nc,arena_union_y_ordered
 ld b,d
 ld d,a
arena_union_y_ordered:
 ld a,b
 sub d
 add a,16
 push af
 ld a,c
 cp e
 jp nc,arena_union_x_ordered
 ld c,e
 ld e,a
arena_union_x_ordered:
 ld a,e
 and 248
 ld b,a
 ld a,c
 add a,15
 sub b
 cp 24
 jp nc,arena_union_width4
 cp 16
 jp nc,arena_union_width3
 ld c,2
 jp arena_union_addr
arena_union_width3:
 ld c,3
 jp arena_union_addr
arena_union_width4:
 ld c,4
arena_union_addr:
 ld a,e
 ld (px_x),a
 push bc
 call px_shadow_line
 pop bc
 ld a,h
 add a,0x60
 ld h,a
 ld d,h
 ld e,l
 ld a,d
 sub 0x80
 ld d,a
 pop af
 ld b,0
 dec c
 dec c
 jp z,arena_union_count2
 dec c
 jp nz,arena_union_count4
 ld c,a
 add a,a
 add a,c
 ld c,a
arena_union_copy3:
 ldi
 ldi
 ldi
 ret po
 ld a,e
 sub 3
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,arena_union_copy3
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,arena_union_copy3
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp arena_union_copy3
arena_union_count2:
 add a,a
 ld c,a
arena_union_copy2:
 ldi
 ldi
 ret po
 ld a,e
 sub 2
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,arena_union_copy2
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,arena_union_copy2
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp arena_union_copy2

arena_union_count4:
 add a,a
 add a,a
 ld c,a
arena_union_copy4:
 ldi
 ldi
 ldi
 ldi
 ret po
 ld a,e
 sub 4
 ld e,a
 ld l,a
 inc d
 inc h
 ld a,d
 and 7
 jp nz,arena_union_copy4
 ld a,e
 add a,32
 ld e,a
 ld l,a
 jp c,arena_union_copy4
 ld a,d
 sub 8
 ld d,a
 ld a,h
 sub 8
 ld h,a
 jp arena_union_copy4

; Draw the centred 16x16 result icon over the title panel.
arena_result_draw_icon:
 ld de,0x020f
 call blit_cell
 ld bc,8
 add hl,bc
 inc e
 call blit_cell
 add hl,bc
 inc d
 dec e
 call blit_cell
 add hl,bc
 inc e
 jp blit_cell

result_skull_pixels:
 db 0,7,31,63,63,127,127,115
 db 0,224,248,252,252,254,254,206
 db 115,127,61,31,21,31,14,0
 db 206,254,188,248,168,248,112,0
result_clear_pixels:
 db 0,0,7,24,32,64,65,66
 db 0,2,197,42,20,40,80,160
 db 69,42,20,32,24,7,0,0
 db 64,4,4,8,48,192,0,0
