; Kempston: fire confirms the source, keyboard remains available at all times.
; Ignore the floating-bus 255 case and invalid opposing directions.
arena_kempston:
 ld bc,0x001f
 in a,(c)
 ld e,a
 in a,(c)
 cp e
 jp nz,arena_joy_invalid
 ld c,a
 and 224
 jp nz,arena_joy_invalid
 ld a,c
 and 3
 cp 3
 jp z,arena_joy_invalid
 ld a,c
 and 12
 cp 12
 jp z,arena_joy_invalid
 ld a,c
 ret
arena_joy_invalid:
 xor a
 ret

arena_keys:
 call keys_poll
 call arena_kempston
 ld c,a
 bit 4,c
 jp z,arena_joy_selected
 ld a,1
 ld (arena_joy_active),a
 ld (fire_down),a
arena_joy_selected:
 ld a,(arena_joy_active)
 or a
 ret z
 bit 0,c
 jp z,arena_joy_left
 ld a,1
 ld (move_dx),a
arena_joy_left:
 bit 1,c
 jp z,arena_joy_down
 ld a,255
 ld (move_dx),a
arena_joy_down:
 bit 2,c
 jp z,arena_joy_up
 ld a,1
 ld (move_dy),a
arena_joy_up:
 bit 3,c
 ret z
 ld a,255
 ld (move_dy),a
 ret

arena_action_release:
arena_release_wait:
 halt
 call arena_keys
 ld a,(fire_down)
 or a
 jp nz,arena_release_wait
 ret
arena_action_press:
arena_press_wait:
 halt
 call title_attract
 call arena_keys
 ld a,(fire_down)
 or a
 jp z,arena_press_wait
 ret

; Event priority: a shot cannot cut a kill or a received hit.
; Each update emits a tiny packet, with silence while the game runs.
arena_audio_shot:
 ld a,(arena_audio_left)
 or a
 ret nz
 xor a
 ld (arena_audio_kind),a
 ld a,1
 ld (arena_audio_left),a
 ret
arena_audio_enemy:
 ld a,(arena_audio_left)
 ld c,a
 ld a,(arena_audio_kind)
 cp 2
 jp nz,arena_audio_kill_start
 ld a,c
 or a
 ret nz
arena_audio_kill_start:
 ld a,1
 ld (arena_audio_kind),a
 ld a,3
 ld (arena_audio_left),a
 ret
arena_audio_player:
 ld a,2
 ld (arena_audio_kind),a
 ld a,5
 ld (arena_audio_left),a
 ret
arena_audio_tick:
 ld a,(arena_audio_left)
 or a
 ret z
 dec a
 ld (arena_audio_left),a
 ; 6..10 half-periods of 27..51 delay iterations (under 2.5 ms).
 ld c,a
 add a,6
 ld b,a
 ld a,c
 add a,a
 add a,c
 add a,c
 add a,c
 add a,c
 add a,27
 ld c,a
 ld a,(arena_audio_kind)
 or a
 jp z,arena_audio_tone
 ld a,b
 add a,4
 ld b,a
 ld a,c
 add a,12
 ld c,a
 ; Successive unequal half periods give the explosion its low, rough edge.
 xor a
arena_audio_noise:
 xor 16
 out (0xfe),a
 ld d,a
 ld a,b
 xor c
 ld e,a
 ld a,d
arena_audio_noise_wait:
 dec e
 jp nz,arena_audio_noise_wait
 djnz arena_audio_noise
 jp arena_audio_silence
arena_audio_tone:
 xor a
arena_audio_edge:
 xor 16
 out (0xfe),a
 ld e,c
arena_audio_delay:
 dec e
 jp nz,arena_audio_delay
 djnz arena_audio_edge
arena_audio_silence:
 xor a
 out (0xfe),a
 ret

arena_audio_left: db 0
arena_audio_kind: db 0
arena_joy_active: db 0

; All four silhouettes, and the player, share the blast and sparks.
arena_player_pose:
 ld a,(arena_death)
 or a
 jp z,arena_player_walk
 cp 8
 ld hl,space_or_sparks_phases
 ret c
 ld hl,space_or_blast_phases
 ret
arena_player_walk:
 ld hl,space_or_player_phases
 ld a,(move_dx)
 ld c,a
 ld a,(move_dy)
 or c
 ret z
 ld a,(lab_frame)
 and 4
 ret z
 ld hl,space_or_player_alt_phases
 ret

arena_explosion_tick:
 ld hl,arena_blasts
 ld a,(hl)
 or a
 ret z
 dec (hl)
 ld ix,actor_slots
 ld de,8
 ld b,8
arena_explosion_next:
 ld a,(ix+0)
 cp 5
 jp nz,arena_explosion_skip
 dec (ix+6)
 jp nz,arena_explosion_skip
 ld (ix+0),0
arena_explosion_skip:
 add ix,de
 djnz arena_explosion_next
 ret

; Enemy rounds carry their own pool slots and collision rules.
arena_enemy_fire:
 ld hl,arena_charge
 ld a,(hl)
 or a
 jp nz,arena_enemy_charging
 ld hl,arena_cooldown
 dec (hl)
 ret nz
 ld a,3
 ld (hl),a
 ld a,(arena_shooter_idx)
 inc a
 and 7
 ld (arena_shooter_idx),a
 add a,a
 add a,a
 add a,a
 ld e,a
 ld d,0
 ld ix,actor_slots
 add ix,de
 ld a,(ix+0)
 cp 2
 jp z,arena_aim_gun
 cp 3
 ret nz
 ld a,(arena_walk_rng)
 and 3
 ret nz
arena_aim_gun:
 ld a,(lab_ship_x)
 ld (arena_gun_x),a
 ld a,(lab_ship_y)
 ld (arena_gun_y),a
 ld (ix+7),128
 ld a,7
 ld (arena_charge),a
 ret
arena_enemy_charging:
 dec (hl)
 ret nz
 ld a,(arena_shooter_idx)
 add a,a
 add a,a
 add a,a
 ld e,a
 ld d,0
 ld ix,actor_slots
 add ix,de
 ld (ix+7),0
 ld a,(arena_sector)
 add a,a
 add a,a
 ld c,a
 ld a,37
 sub c
 ld (arena_cooldown),a
 ld a,(ix+0)
 or a
 ret z
 cp 5
 ret z
 ld a,(ix+1)
 add a,8
 ld e,a
 ld a,(ix+2)
 add a,8
 ld d,a
 ld a,2
 call arena_hostile_alloc
 or a
 ret z
 ; Quantise the aim to eight directions. Ignore a minor axis if
 ; it is below half of the major one. Hostile speed 3/2 px per tick.
 push hl
 ld a,(ix+1)
 ld c,a
 ld a,(arena_gun_x)
 sub c
 ld d,3
 jp nc,arena_hostile_x_magnitude
 neg
 ld d,253
arena_hostile_x_magnitude:
 ld h,a
 ld a,(ix+2)
 ld c,a
 ld a,(arena_gun_y)
 sub c
 ld e,3
 jp nc,arena_hostile_y_magnitude
 neg
 ld e,253
arena_hostile_y_magnitude:
 ld l,a
 and 254
 rrca
 cp h
 jp c,arena_hostile_check_y
 ld d,0
 jp arena_hostile_velocity
arena_hostile_check_y:
 ld a,h
 and 254
 rrca
 cp l
 jp c,arena_hostile_diagonal
 ld e,0
 jp arena_hostile_velocity
arena_hostile_diagonal:
 ld a,d
 cp 3
 jp nz,arena_hostile_x_negative
 dec d
 jp arena_hostile_y_diagonal
arena_hostile_x_negative:
 inc d
arena_hostile_y_diagonal:
 ld a,e
 cp 3
 jp nz,arena_hostile_y_negative
 dec e
 jp arena_hostile_velocity
arena_hostile_y_negative:
 inc e
arena_hostile_velocity:
 pop hl
 ld bc,3
 add hl,bc
 ld (hl),d
 inc hl
 ld (hl),e
 ret

; Include the two-pixel radius around each hostile projectile centre.
arena_hostile_hit:
 push ix
 ld ix,bullet_slots+72
 ld b,4
arena_hostile_hit_loop:
 ld a,(ix+0)
 or a
 jp z,arena_hostile_hit_skip
 ld a,(lab_ship_x)
 ld c,a
 ld a,(ix+1)
 sub c
 cp 16
 jp nc,arena_hostile_hit_skip
 ld a,(lab_ship_y)
 ld c,a
 ld a,(ix+2)
 sub c
 cp 16
 jp nc,arena_hostile_hit_skip
 ld (ix+0),0
 ld a,1
 or a
 pop ix
 ret
arena_hostile_hit_skip:
 ld de,6
 add ix,de
 djnz arena_hostile_hit_loop
 xor a
 pop ix
 ret

; Five-pixel balls; player shots keep the original one-point compositor.
arena_bullet_draw:
 ld (ball_kind),a
 xor a
 jp arena_ball_raster
arena_bullet_restore:
 ld a,1
 jp arena_ball_raster
arena_bullet_present:
 ld a,2
arena_ball_raster:
 ld (ball_op),a
 ld a,e
 cp 2
 ret c
 ld a,d
 cp 2
 ret c
 push de
 dec e
 dec e
 dec d
 dec d
 ld a,e
 and 7
 add a,a
 ld (ball_phase),a
 ld b,5
arena_ball_row:
 push bc
 call star_screen_addr
 ld a,h
 add a,0x60
 ld h,a
 ld a,(ball_op)
 or a
 jp nz,arena_ball_copy
 push hl
 ld a,(ball_kind)
 cp 1
 jp z,arena_player_mask
 ld hl,ball_wide
 ld a,(ball_row_count)
 cp 1
 jp z,arena_ball_narrow
 cp 5
 jp nz,arena_ball_mask
arena_ball_narrow:
 ld hl,ball_narrow
arena_ball_mask:
 call ball_read_mask
 pop hl
 ld a,(hl)
 or c
 ld (hl),a
 inc l
 ld a,(hl)
 or b
 ld (hl),a
 jp arena_ball_advance
arena_player_mask:
 ld hl,ball_wide
 call ball_read_mask
 pop hl
 ld a,c
 cpl
 and (hl)
 ld (hl),a
 inc l
 ld a,b
 cpl
 and (hl)
 ld (hl),a
 dec l
 ld a,(ball_row_count)
 cp 1
 jp z,arena_ball_advance
 cp 5
 jp z,arena_ball_advance
 push hl
 jp arena_ball_narrow
ball_read_mask:
 push de
 ld a,(ball_phase)
 ld e,a
 ld d,0
 add hl,de
 ld c,(hl)
 inc hl
 ld b,(hl)
 pop de
 ret
arena_ball_copy:
 push de
 ld d,h
 ld e,l
 cp 2
 jp z,arena_ball_to_screen
 ld a,h
 add a,0x18
 ld h,a
 jp arena_ball_copy_bytes
arena_ball_to_screen:
 ld a,d
 sub 0x80
 ld d,a
arena_ball_copy_bytes:
 ld a,(hl)
 ld (de),a
 inc l
 inc e
 ld a,(hl)
 ld (de),a
 pop de
arena_ball_advance:
 inc d
 ld hl,ball_row_count
 dec (hl)
 pop bc
 dec b
 jp nz,arena_ball_row
 ld (hl),5
 pop de
 ret

ball_kind: db 0
ball_op: db 0
ball_phase: db 0
ball_row_count: db 5
ball_wide:  db 248,0,124,0,62,0,31,0,15,128,7,192,3,224,1,240
ball_narrow: db 112,0,56,0,28,0,14,0,7,0,3,128,1,192,0,224

; Restore the colours for the old balls first, then tint the current
; balls in free cells. Actor and SMILEY colours take priority.
arena_ball_colors:
 ld iy,lab_old_bullets
 ld b,16
arena_ball_old_color:
 ld a,(iy+0)
 or a
 jp z,arena_ball_old_next
 ld e,(iy+1)
 ld d,(iy+2)
 xor a
 call arena_ball_attr
arena_ball_old_next:
 ld de,3
 add iy,de
 djnz arena_ball_old_color
 ld ix,bullet_slots
 ld b,16
arena_ball_new_color:
 ld a,(ix+0)
 or a
 jp z,arena_ball_new_next
 ld e,(ix+1)
 ld d,(ix+2)
 ld a,(ix+0)
 cp 1
 ld a,0x47
 jp nz,arena_round_tint
 ld a,0x45
arena_round_tint:
 call arena_ball_attr
arena_ball_new_next:
 ld de,6
 add ix,de
 djnz arena_ball_new_color
 ret
arena_ball_attr:
 push bc
 ld (ball_tint),a
 ld a,e
 cp 2
 jp c,arena_ball_attr_done
 ld a,d
 cp 2
 jp c,arena_ball_attr_done
 dec e
 dec e
 dec d
 dec d
 call arena_ball_corner
 inc e
 inc e
 inc e
 inc e
 call arena_ball_corner
 inc d
 inc d
 inc d
 inc d
 call arena_ball_corner
 dec e
 dec e
 dec e
 dec e
 call arena_ball_corner
arena_ball_attr_done:
 pop bc
 ret
arena_ball_corner:
 push de
 ld a,d
 and 248
 rrca
 rrca
 rrca
 ld d,a
 ld a,e
 and 248
 rrca
 rrca
 rrca
 ld e,a
 call attribute_addr
 ld c,(hl)
 ld a,(ball_tint)
 or a
 jp z,arena_ball_color_write
 bit 6,c
 jp nz,arena_ball_color_write
 ld c,a
arena_ball_color_write:
 ld a,h
 sub 0x20
 ld h,a
 ld (hl),c
 pop de
 ret
ball_tint: db 0

arena_shooter_idx: db 0
arena_cooldown: db 40
arena_charge: db 0

arena_gun_x: db 0
arena_gun_y: db 0
