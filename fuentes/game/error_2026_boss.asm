; The 48x48 face is a static part of the boss arena's background.
boss_init:
 call arena_read_screen
 ld a,144
 ld (lab_ship_y),a
 ld (lab_old_ship_y),a
 ld a,96
 ld (boss_old_x),a
 ld a,152
 ld (boss_old_y),a
 ld a,1
 ld (arena_remaining),a
 ld a,25
 ld (arena_invuln),a
 ld (boss_timer),a
 ld a,(arena_sector)
 ld c,a
 add a,a
 add a,c
 add a,8
 ld (boss_hp),a
 ld a,(0x5c78)
 or 1
 ld (boss_rng),a
 ret

boss_paint:
 ld de,0x0909
 ld hl,boss_tiles
boss_paint_cell:
 push hl
 push de
 call attribute_addr
 ld (hl),0x46
 pop de
 pop hl
 call arena_stamp_cell
 inc e
 ld a,e
 cp 15
 jp c,boss_paint_cell
 ld e,9
 inc d
 ld a,d
 cp 15
 jp c,boss_paint_cell
 ret

boss_restore_colors:
 ld a,e
 sub 57
 cp 63
 ret nc
 ld a,d
 sub 57
 cp 63
 ret nc
 ld hl,0x7929
 ld de,27
 ld b,6
boss_restore_row:
 ld (hl),0x46
 inc l
 ld (hl),0x46
 inc l
 ld (hl),0x46
 inc l
 ld (hl),0x46
 inc l
 ld (hl),0x46
 inc l
 ld (hl),0x46
 add hl,de
 djnz boss_restore_row
 ret

boss_hud:
 ; Right-to-left depletion: each remaining HP lights one two-pixel segment.
 ld a,(boss_hp)
 ld c,a
 ld de,0x1019
 ld b,6
boss_bar_cell:
 push bc
 ld a,c
 cp 4
 jp c,boss_bar_partial
 ld a,4
boss_bar_partial:
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 push bc
 ld bc,boss_bar_tiles
 add hl,bc
 pop bc
 ld a,0x46
 call blit_cell
 ld a,c
 sub 4
 jp nc,boss_bar_remaining
 xor a
boss_bar_remaining:
 pop bc
 ld c,a
 inc e
 djnz boss_bar_cell
 ret
boss_bar_tiles:
 db 0,0,0,0,0,0,0,0
 db 0,0,128,128,128,128,0,0
 db 0,0,160,160,160,160,0,0
 db 0,0,168,168,168,168,0,0
 db 0,0,170,170,170,170,0,0

boss_fire:
 call boss_spawn_if_ready
 ; Store this update's player centre for the next shot.
 ld a,(lab_ship_x)
 add a,8
 ld (boss_old_x),a
 ld a,(lab_ship_y)
 add a,8
 ld (boss_old_y),a
 ret
boss_spawn_if_ready:
 ld a,(boss_hp)
 or a
 ret z
 ld hl,boss_timer
 dec (hl)
 ret nz
 ld a,(boss_rng)
 and 254
 rrca
 ld c,a
 ld a,(boss_rng)
 and 1
 ld a,c
 jp z,boss_rng_store
 xor 0xb8
boss_rng_store:
 ld (boss_rng),a
 and 15
 ld c,a
 ld a,(arena_sector)
 add a,a
 add a,a
 ld b,a
 ld a,28
 sub b
 add a,c
 ld (boss_timer),a
 ld de,0x6060
 ld a,3
 call arena_hostile_alloc
 or a
 ret z
 push hl
 ; The allocator's B counts down from four to one.
 ld a,4
 sub b
 ld e,a
 add a,a
 add a,a
 add a,e
 ld e,a
 ld d,0
 ld iy,boss_paths
 add iy,de
 ld de,0x0101
 ld a,(boss_old_x)
 sub 96
 jp nc,boss_dx_abs
 neg
 ld d,255
boss_dx_abs:
 ld (iy+1),a
 ld c,a
 ld a,(boss_old_y)
 sub 96
 jp nc,boss_dy_abs
 neg
 ld e,255
boss_dy_abs:
 ld (iy+2),a
 cp c
 jp nc,boss_major
 ld a,c
boss_major:
 or a
 jp nz,boss_major_valid
 inc a
boss_major_valid:
 ld (iy+0),a
 and 254
 rrca
 ld (iy+3),a
 ld (iy+4),a
 pop hl
 inc hl
 inc hl
 inc hl
 ld (hl),d
 inc hl
 ld (hl),e
 ret

; Each hostile type-3 slot gets its own integer line accumulator. This
; retains the recorded aim even when the player changes direction.
boss_bullet_step:
 ld ix,bullet_slots+72
 ld iy,boss_paths
 ld b,4
boss_path_slot:
 ld a,(ix+0)
 cp 3
 jp nz,boss_path_next
 push bc
 dec (ix+5)
 jp z,boss_path_kill
 ld a,(arena_sector)
 rrca
 and 3
 add a,3
 ld b,a
boss_path_tick:
 ld a,(iy+3)
 add a,(iy+1)
 cp (iy+0)
 jp c,boss_path_x_store
 sub (iy+0)
 ld c,a
 ld a,(ix+1)
 add a,(ix+3)
 cp 2
 jp c,boss_path_kill
 cp 185
 jp nc,boss_path_kill
 ld (ix+1),a
 ld a,c
boss_path_x_store:
 ld (iy+3),a
 ld a,(iy+4)
 add a,(iy+2)
 cp (iy+0)
 jp c,boss_path_y_store
 sub (iy+0)
 ld c,a
 ld a,(ix+2)
 add a,(ix+4)
 cp 2
 jp c,boss_path_kill
 cp 185
 jp nc,boss_path_kill
 ld (ix+2),a
 ld a,c
boss_path_y_store:
 ld (iy+4),a
 djnz boss_path_tick
 jp boss_path_done
boss_path_kill:
 ld (ix+0),0
boss_path_done:
 pop bc
boss_path_next:
 ld de,6
 add ix,de
 dec e
 add iy,de
 djnz boss_path_slot
 ret

boss_hit:
 ld a,(boss_hp)
 or a
 ret z
 ld ix,bullet_slots
 ld b,12
boss_hit_loop:
 ld a,(ix+0)
 or a
 jp z,boss_hit_next
 ld e,(ix+1)
 ld d,(ix+2)
 ld c,22
 call boss_inside
 jp nc,boss_hit_next
 ld (ix+0),0
 ld hl,boss_hp
 dec (hl)
 jp z,boss_finish
 push bc
 push ix
 call boss_hud
 pop ix
 pop bc
boss_hit_next:
 ld de,6
 add ix,de
 djnz boss_hit_loop
 ret
boss_finish:
 xor a
 ld (arena_remaining),a
 ld hl,bullet_slots
 ld de,bullet_slots+1
 ld bc,95
 ld (hl),a
 ldir
 ld a,40
 ld (boss_party),a
 ld (arena_blasts),a
 call boss_hud
 jp arena_audio_enemy

boss_contact:
 ld a,(boss_hp)
 or a
 ret z
 ld a,(lab_ship_x)
 add a,8
 ld e,a
 ld a,(lab_ship_y)
 add a,8
 ld d,a
 ld c,27
 call boss_inside
 ret nc
 jp arena_lose_life

; Octagonal hit area keeps the corners of the square graphic traversable.
boss_inside:
 ld a,e
 sub 96
 jp nc,boss_bound_x
 neg
boss_bound_x:
 cp c
 jp nc,boss_outside
 ld e,a
 ld a,d
 sub 96
 jp nc,boss_bound_y
 neg
boss_bound_y:
 cp c
 jp nc,boss_outside
 add a,e
 sub c
 ret c
 cp 15
 ret
boss_outside:
 or a
 ret

arena_boss: db 0
boss_hp: db 0
boss_timer: db 0
boss_rng: db 1
boss_old_x: db 96
boss_old_y: db 152
boss_paths: ds 20

boss_celebrate_frame:
 ld a,(boss_party)
 dec a
 ld (boss_party),a
 jp z,arena_end_wave
 and 3
 ret nz
 ld a,(boss_party)
 rrca
 rrca
 and 15
 ld e,a
 ld d,0
 ld hl,boss_party_order
 add hl,de
 ld a,(hl)
 add a,a
 ld e,a
 ld hl,boss_party_cells
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 push de
 ld hl,space_or_blast_phases
 ld a,(boss_party)
 and 4
 jp z,boss_party_draw
 ld hl,space_or_sparks_phases
boss_party_draw:
 call space_rect_draw
 call space_rect_present
 pop de
 ld a,(boss_party)
 and 4
 ld a,0x46
 jp z,boss_party_color
 ld a,0x47
boss_party_color:
 call space_rect_color
 call space_rect_present_colors
 jp arena_audio_enemy
boss_party_order: db 4,0,8,2,6,1,7,3,5,4
boss_party_cells:
 db 72,72,88,72,104,72,72,88,88,88,104,88,72,104,88,104,104,104
boss_party: db 0
