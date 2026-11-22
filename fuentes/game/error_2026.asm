; ERROR 2026 - EL FUTURO. ZX Spectrum 48K / GRIT ENGINE V0.3.1 FAST.
; 30 arenas, eight-direction fire, four enemy classes and six sectors.
; Derived from Tony C. Ware's GRIT Engine.
 
demo_init:
 call engine_enter_play
 xor a
 ld (arena_kills),a
 ld (arena_kills+1),a
 ld (arena_checkpoint),a
 ld (arena_checkpoint+1),a
 ld (arena_audio_left),a
 ld (arena_boss),a
 ld a,3
 ld (arena_lives),a
 ld a,1
 ld (arena_wave),a
arena_load_screen:
 call screen_clear
 call actor_pool_init
 ld a,88
 ld (lab_ship_x),a
 ld (lab_ship_y),a
 ld (lab_old_ship_x),a
 ld (lab_old_ship_y),a
 xor a
 ld (lab_frame),a
 ld (lab_shot_delay),a
 ld (arena_last_hits),a
 ld (arena_death),a
 ld (arena_blasts),a
 ld (arena_charge),a
 ld a,(0x5c78)
 or 1
 ld (arena_walk_rng),a
 ld a,3
 ld (arena_shooter_idx),a
 ld a,32
 ld (arena_cooldown),a
 ld a,1
 ld (arena_facing),a
 ld a,(arena_boss)
 or a
 call z,arena_spawn_wave
 ld a,(arena_boss)
 or a
 call nz,boss_init
 call lab_hud
 call space_fast_init
 call arena_floor
 ld a,(arena_boss)
 or a
 call nz,boss_paint
 call lab_draw
 call lab_color_initial
 jp space_fullpresent
 
arena_read_screen:
 ; Each entry holds a formation pointer followed by eight type codes.
 ld a,(arena_wave)
 dec a
 ld e,a
 ld d,0
 ld hl,0
 add hl,de
 add hl,hl
 add hl,hl
 add hl,de
 add hl,hl
 ld de,arena_screens
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ex de,hl
 ld (arena_position_ptr),hl
 ex de,hl
 ld (arena_type_ptr),hl
 ld a,(arena_wave)
 dec a
 ld c,0
arena_sector_count:
 cp 5
 jp c,arena_sector_found
 sub 5
 inc c
 jp arena_sector_count
arena_sector_found:
 ld a,c
 ld (arena_sector),a
 ld b,0
 ld hl,arena_floor_inks
 add hl,bc
 ld a,(hl)
 ld (arena_floor_ink),a
 ret
 
; Wave positions are defined as data, not inferred from player coordinates.
; Keep the eight enemies at a distance at the start of every wave.
arena_spawn_wave:
 call arena_read_screen
 ld b,8
arena_spawn_loop:
 push bc
 ld hl,(arena_position_ptr)
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ld (arena_position_ptr),hl
 ld hl,(arena_type_ptr)
 ld a,(hl)
 inc hl
 ld (arena_type_ptr),hl
 call actor_pool_alloc
 ; Stagger patrol timing. Later sectors introduce armoured rammers.
 ld de,5
 add hl,de
 ld a,(pool_new_type)
 cp 3
 jp nz,arena_spawn_patrol_hp
 ld (hl),3
 ld a,(arena_wave)
 cp 16
 jp c,arena_spawn_age
 inc (hl)
 jp arena_spawn_age
arena_spawn_patrol_hp:
 cp 4
 jp nz,arena_spawn_age
 ld a,(arena_wave)
 cp 16
 jp c,arena_spawn_age
 ld (hl),2
arena_spawn_age:
 inc hl
 pop bc
 ld a,b
 add a,a
 ld (hl),a
 djnz arena_spawn_loop
 ld a,8
 ld (arena_remaining),a
 ld a,25
 ld (arena_invuln),a
 ret

demo_frame:
 call engine_is_terminal
 ret nz
 ld a,(lab_ship_x)
 ld (lab_old_ship_x),a
 ld a,(lab_ship_y)
 ld (lab_old_ship_y),a
 ld a,(arena_death)
 or a
 jp nz,arena_dying
 call arena_keys
 call arena_update_aim
 call lab_ship_move
 call lab_erase
 call arena_explosion_tick
 call lab_fire
 ld a,(arena_boss)
 or a
 jp nz,arena_boss_frame
 call arena_chase
 call arena_enemy_fire
 call bullet_pool_step
 call bullet_actor_collisions
 call arena_score_hits
 jp arena_frame_contact
arena_boss_frame:
 ld a,(boss_hp)
 or a
 jp z,boss_celebrate_frame
 call boss_fire
 call bullet_pool_step
 call boss_bullet_step
 call boss_hit
arena_frame_contact:
 call arena_contact
 call arena_draw_frame
 ld a,(arena_death)
 or a
 ret nz
 ld a,(arena_blasts)
 or a
 ret nz
 ld a,(arena_remaining)
 or a
 call z,arena_end_wave
 ret

arena_dying:
 call lab_erase
 ld a,(arena_death)
 dec a
 jp z,arena_retry
 ld (arena_death),a
 jp arena_draw_frame
arena_retry:
 ld a,(arena_lives)
 or a
 jp z,arena_game_over
 ld hl,(arena_checkpoint)
 ld (arena_kills),hl
 jp arena_load_screen

arena_draw_frame:
 call lab_draw
 call lab_recolor_actors
 call lab_present
 call arena_ball_colors
 ld hl,lab_frame
 inc (hl)
 ret

lab_ship_move:
 ; Player speed 2 pixels per update, bounded X/Y 8..168.
 ld a,(move_dx)
 add a,a
 ld b,a
 ld a,(lab_ship_x)
 add a,b
 cp 8
 jp c,lab_ship_move_y
 cp 169
 jp nc,lab_ship_move_y
 ld (lab_ship_x),a
lab_ship_move_y:
 ld a,(move_dy)
 add a,a
 ld b,a
 ld a,(lab_ship_y)
 add a,b
 cp 8
 ret c
 cp 169
 ret nc
 ld (lab_ship_y),a
 ret

arena_update_aim:
 ; Convert signed axes (-1,0,+1) to a 3x3 index.
 ld a,(move_dx)
 inc a
 ld c,a
 ld a,(move_dy)
 inc a
 ld b,a
 add a,a
 add a,b
 add a,c
 cp 4
 ret z
 ld (arena_facing),a
 ret

lab_fire:
 ld a,(lab_shot_delay)
 or a
 jp z,lab_fire_ready
 dec a
 ld (lab_shot_delay),a
 ret
lab_fire_ready:
 ld a,(fire_down)
 or a
 ret z
 ld a,(lab_ship_x)
 add a,8
 ld e,a
 ld a,(lab_ship_y)
 add a,8
 ld d,a
 ld a,1
 call bullet_pool_alloc
 or a
 ret z
 ; Hit point originates from hero centre; exits in last movement dir.
 ld bc,3
 add hl,bc
 ex de,hl
 ld a,(arena_facing)
 add a,a
 ld c,a
 ld b,0
 ld hl,arena_vectors
 add hl,bc
 ld a,(hl)
 ld (de),a
 inc de
 inc hl
 ld a,(hl)
 ld (de),a
 call arena_audio_shot
 ld a,4
 ld (lab_shot_delay),a
 ret
arena_vectors:
 db -3,-3, 0,-4, 3,-3
 db -4,0, 0,0, 4,0
 db -3,3, 0,4, 3,3

; --- ENEMY BEHAVIOURS ---
; All routines use bounded positions 8..168. Never permit uint8 underflow.
; Enemy families use the existing slot fields for their own movement.
; 1 green pursuer, 2 cyan gunner, 3 red wanderer, 4 magenta perimeter patrol.
arena_chase:
 push af
 push bc
 push de
 push ix
 ld a,(lab_frame)
 and 1
 ld (arena_axis),a
 ld ix,actor_slots
 ld de,8
 ld b,8
arena_chase_loop:
 push bc
 ld a,(ix+0)
 or a
 jp z,arena_chase_next
 cp 5
 jp z,arena_chase_next
 inc (ix+6)
 cp 2
 jp z,arena_gunner
 cp 3
 jp z,arena_wander
 cp 4
 jp z,arena_patrol
 ; Pursuers alternate axes, with an occasional diagonal correction.
 ld a,(arena_axis)
 or a
 jp nz,arena_hunter_y
 call arena_seek_x1
 ld a,(ix+6)
 and 2
 jp z,arena_chase_next
arena_hunter_y:
 call arena_seek_y1
 jp arena_chase_next
arena_gunner:
 ld a,(ix+7)
 or a
 jp nz,arena_chase_next
 ld a,(ix+6)
 and 3
 jp z,arena_gunner_x
 cp 2
 jp nz,arena_chase_next
 ld a,(lab_ship_y)
 sub (ix+2)
 add a,44
 cp 89
 call nc,arena_seek_y1
 jp arena_chase_next
arena_gunner_x:
 ld a,(lab_ship_x)
 sub (ix+1)
 add a,44
 cp 89
 call nc,arena_seek_x1
 jp arena_chase_next
arena_wander:
 ld a,(ix+7)
 or a
 jp nz,arena_chase_next
 ld a,(ix+4)
 or a
 jp nz,arena_wander_walk
 ld a,(arena_walk_rng)
 and 254
 rrca
 ld c,a
 ld a,(arena_walk_rng)
 and 1
 ld a,c
 jp z,arena_wander_store
 xor 0xb8
arena_wander_store:
 ld (arena_walk_rng),a
 and 3
 ld (ix+3),a
 ld (ix+4),24
arena_wander_walk:
 dec (ix+4)
 ld a,(ix+3)
 or a
 jp z,arena_wander_left
 cp 1
 jp z,arena_wander_right
 cp 2
 jp z,arena_wander_up
 call arena_step_down
 ld a,(ix+6)
 and 3
 call z,arena_step_down
 jp arena_chase_next
arena_wander_left:
 call arena_step_left
 ld a,(ix+6)
 and 3
 call z,arena_step_left
 jp arena_chase_next
arena_wander_right:
 call arena_step_right
 ld a,(ix+6)
 and 3
 call z,arena_step_right
 jp arena_chase_next
arena_wander_up:
 call arena_step_up
 ld a,(ix+6)
 and 3
 call z,arena_step_up
 jp arena_chase_next
arena_patrol:
 ld a,(ix+4)
 or a
 jp nz,patrol_dash
 ld a,(ix+3)
 or a
 jp nz,arena_patrol_route
 ; Enter the loop at the nearest vertical edge.
 ld a,(ix+1)
 cp 88
 jp nc,arena_patrol_enter_right
 cp 12
 call nc,arena_step_left
 ld a,(ix+1)
 cp 12
 jp nc,arena_chase_next
 ld (ix+3),1
 jp arena_chase_next
arena_patrol_enter_right:
 cp 165
 call c,arena_step_right
 ld a,(ix+1)
 cp 165
 jp c,arena_chase_next
 ld (ix+3),3
 jp arena_chase_next
arena_patrol_route:
 ld a,(ix+7)
 or a
 jp z,patrol_detect
 dec (ix+7)
 jp patrol_continue
patrol_detect:
 ; Charge only from an edge, within six pixels of the player's lane.
 ld a,(ix+3)
 and 1
 jp z,patrol_check_column
 ld a,(lab_ship_y)
 sub (ix+2)
 add a,6
 cp 13
 jp c,patrol_warn
 jp patrol_continue
patrol_check_column:
 ld a,(lab_ship_x)
 sub (ix+1)
 add a,6
 cp 13
 jp c,patrol_warn
patrol_continue:
 ld a,(ix+3)
 dec a
 jp z,arena_patrol_north
 dec a
 jp z,arena_patrol_east
 dec a
 jp z,arena_patrol_south
 ld a,(ix+1)
 cp 12
 jp c,arena_patrol_turn_north
 call arena_step_left
 jp arena_chase_next
arena_patrol_turn_north:
 ld (ix+3),1
 jp arena_chase_next
arena_patrol_north:
 ld a,(ix+2)
 cp 12
 jp c,arena_patrol_turn_east
 call arena_step_up
 jp arena_chase_next
arena_patrol_turn_east:
 inc (ix+3)
 jp arena_chase_next
arena_patrol_east:
 ld a,(ix+1)
 cp 165
 jp nc,arena_patrol_turn_south
 call arena_step_right
 jp arena_chase_next
arena_patrol_turn_south:
 inc (ix+3)
 jp arena_chase_next
arena_patrol_south:
 ld a,(ix+2)
 cp 165
 jp nc,arena_patrol_turn_west
 call arena_step_down
 jp arena_chase_next
arena_patrol_turn_west:
 inc (ix+3)
patrol_warn:
 ld (ix+4),11
 ld (ix+7),128
 jp arena_chase_next
patrol_dash:
 cp 1
 jp z,patrol_cross
 dec (ix+4)
 jp arena_chase_next
patrol_cross:
 ld (ix+7),0
 ld a,(ix+3)
 dec a
 jp z,patrol_cross_right
 dec a
 jp z,patrol_cross_down
 dec a
 jp z,patrol_cross_left
 call arena_step_up
 call arena_step_up
 ld a,(ix+2)
 cp 12
 jp nc,arena_chase_next
 jp patrol_dash_done
patrol_cross_right:
 call arena_step_right
 call arena_step_right
 ld a,(ix+1)
 cp 165
 jp c,arena_chase_next
 jp patrol_dash_done
patrol_cross_down:
 call arena_step_down
 call arena_step_down
 ld a,(ix+2)
 cp 165
 jp c,arena_chase_next
 jp patrol_dash_done
patrol_cross_left:
 call arena_step_left
 call arena_step_left
 ld a,(ix+1)
 cp 12
 jp nc,arena_chase_next
patrol_dash_done:
 ld a,(ix+3)
 inc a
 and 3
 inc a
 ld (ix+3),a
 ld (ix+4),0
 ld (ix+7),48
arena_chase_next:
 ld de,8
 add ix,de
 pop bc
 dec b
 jp nz,arena_chase_loop
 pop ix
 pop de
 pop bc
 pop af
 ret

arena_step_left:
 ld a,(ix+1)
 cp 9
 ret c
 dec (ix+1)
 ret
arena_step_right:
 ld a,(ix+1)
 cp 168
 ret nc
 inc (ix+1)
 ret
arena_step_up:
 ld a,(ix+2)
 cp 9
 ret c
 dec (ix+2)
 ret
arena_step_down:
 ld a,(ix+2)
 cp 168
 ret nc
 inc (ix+2)
 ret
arena_seek_x1:
 ld a,(ix+1)
 ld c,a
 ld a,(lab_ship_x)
 cp c
 ret z
 jp c,arena_step_left
 jp arena_step_right
arena_seek_y1:
 ld a,(ix+2)
 ld c,a
 ld a,(lab_ship_y)
 cp c
 ret z
 jp c,arena_step_up
 jp arena_step_down

; Attribute codes: BRIGHT | black paper | enemy-specific INK.
; Input A=actor type (1..4). Returns A=color. No other reg affected.
arena_enemy_color:
 cp 2
 jp z,arena_color_zigzag
 cp 3
 jp z,arena_color_ram
 cp 4
 jp z,arena_color_stalker
 ld a,0x44              ; CAZADOR green
 ret
arena_color_zigzag:
 ld a,0x45              ; ZIGZAG cyan
 ret
arena_color_ram:
 ld a,0x42              ; EMBESTIDOR red
 ret
arena_color_stalker:
 ld a,0x43              ; ACECHADOR magenta
 ret

; IX actor. Locomotion alternates every four updates out of phase
; across actors. Type 5 reuses the slot for a harmless explosion.
arena_enemy_sprite:
 ld a,(ix+0)
 cp 5
 jp z,arena_enemy_blast
 dec a
 add a,a
 add a,a
 ld c,a
 ld a,(ix+6)
 and 4
 rrca
 or c
 ld c,a
 ld b,0
 ld hl,arena_poses
 add hl,bc
 ld a,(hl)
 inc hl
 ld h,(hl)
 ld l,a
 ret
arena_enemy_blast:
 ld a,(ix+6)
 cp 4
 ld hl,space_or_sparks_phases
 ret c
 ld hl,space_or_blast_phases
 ret
arena_poses:
 dw space_or_hunter_phases,space_or_hunter_alt_phases
 dw space_or_zigzag_phases,space_or_zigzag_alt_phases
 dw space_or_embestidor_phases,space_or_embestidor_alt_phases
 dw space_or_acechador_phases,space_or_acechador_alt_phases

arena_actor_color:
 ld a,(ix+0)
 cp 5
 jp z,arena_blast_color
 ld a,(ix+7)
 bit 7,a
 jp nz,arena_charge_color
 ld a,(ix+0)
 jp arena_enemy_color
arena_charge_color:
 ld a,0x47
 ret
arena_blast_color:
 ld a,0x46
 ret

; One kill = 100 points. Nonlethal impacts do not clear an enemy.
arena_score_hits:
 ld a,(pool_kill_count)
 ld c,a
arena_score_loop:
 ld a,(arena_last_hits)
 cp c
 ret z
 inc a
 ld (arena_last_hits),a
 ld hl,(arena_kills)
 inc hl
 ld (arena_kills),hl
 ld a,8
 ld (arena_blasts),a
 push bc
 call arena_audio_enemy
 pop bc
 ld a,(arena_remaining)
 or a
 jp z,arena_score_loop
 dec a
 ld (arena_remaining),a
 push bc
 call arena_refresh_score
 pop bc
 jp arena_score_loop

arena_contact:
 ld a,(arena_invuln)
 or a
 jp z,arena_can_hit
 dec a
 ld (arena_invuln),a
 ret
arena_can_hit:
 call arena_hostile_hit
 jp nz,arena_lose_life
 ld a,(arena_boss)
 or a
 jp nz,boss_contact
 push bc
 push de
 push ix
 ld ix,actor_slots
 ld de,8
 ld b,8
arena_contact_next:
 push bc
 ld a,(ix+0)
 or a
 jp z,arena_contact_skip
 cp 5
 jp z,arena_contact_skip
 ld a,(ix+1)
 ld c,a
 ld a,(lab_ship_x)
 sub c
 add a,12
 cp 24
 jp nc,arena_contact_skip
 ld a,(ix+2)
 ld c,a
 ld a,(lab_ship_y)
 sub c
 add a,12
 cp 24
 jp nc,arena_contact_skip
 jp arena_contact_done
arena_contact_skip:
 ld de,8
 add ix,de
 pop bc
 djnz arena_contact_next
 pop ix
 pop de
 pop bc
 ret
arena_contact_done:
 pop bc
 pop ix
 pop de
 pop bc
arena_lose_life:
 ld hl,arena_lives
 dec (hl)
 ld a,15
 ld (arena_death),a
 call arena_audio_player
 jp arena_refresh_lives

arena_end_wave:
 ld a,(arena_boss)
 or a
 jp nz,boss_cleared
 ld a,(arena_wave)
arena_check_sector_end:
 sub 5
 jp z,boss_start
 jp nc,arena_check_sector_end
 jp arena_next_wave
boss_start:
 ld a,1
 ld (arena_boss),a
 ld hl,(arena_kills)
 ld (arena_checkpoint),hl
 jp arena_load_screen
boss_cleared:
 xor a
 ld (arena_boss),a
arena_next_wave:
 ld a,(arena_wave)
 cp 30
 jp z,arena_victory
 inc a
 ld (arena_wave),a
 ld hl,(arena_kills)
 ld (arena_checkpoint),hl
 jp arena_load_screen

arena_game_over:
 call arena_audio_tick
 call engine_enter_gameover
 ld hl,arena_over_line1
 ld a,0x50
 jp arena_end_screen
arena_victory:
 call arena_audio_tick
 call engine_enter_victory
 ld hl,arena_win_line1
 ld a,0x60
arena_end_screen:
 push af
 push hl
 call screen_clear
 call arena_menu_frame
 call arena_logo
 ld a,(engine_state)
 cp 2
 ld hl,result_clear_pixels
 ld a,0x45
 jp nz,arena_result_icon
 ld hl,result_skull_pixels
 ld a,0x42
arena_result_icon:
 call arena_result_draw_icon
 pop hl
 pop af
 ld (text_attr),a
 ld d,11
 call arena_center_text
 ld a,0x47
 ld (text_attr),a
 call arena_refresh_score
 call arena_refresh_wave
 ld d,14
 ld hl,arena_result_points
 call arena_center_text
 ld d,16
 ld hl,arena_result_wave
 call arena_center_text
 ld d,20
 ld hl,arena_over_line3
 call arena_center_text
 call present_full
 ld b,150
 call engine_wait_50hz
 call arena_action_release
 call arena_action_press
 jp entry
arena_over_line1: db "   GAME OVER   ",0
arena_win_line1: db "    VICTORIA    ",0
arena_over_line3: db "SPACE O FIRE  /  TITULO",0

lab_erase:
 push bc
 push de
 push ix
 push iy
 ld ix,bullet_slots
 ld iy,lab_old_bullets
 ld b,16
lab_erase_bullet_loop:
 push bc
 ld a,(ix+0)
 ld (iy+0),a
 or a
 jp z,lab_erase_bullet_skip
 ld a,(ix+1)
 ld (iy+1),a
 ld e,a
 ld a,(ix+2)
 ld (iy+2),a
 ld d,a
 ld a,(ix+0)
 call arena_bullet_restore
lab_erase_bullet_skip:
 ld de,6
 add ix,de
 ld de,3
 add iy,de
 pop bc
 djnz lab_erase_bullet_loop
 ld ix,actor_slots
 ld iy,lab_old_actors
 ld b,8
lab_erase_actor_loop:
 push bc
 ld a,(ix+0)
 ld (iy+0),a
 ld a,(iy+0)
 or a
 jp z,lab_erase_actor_skip
 call arena_actor_color
 ld (iy+3),a
 ld a,(ix+1)
 ld (iy+1),a
 ld e,a
 ld a,(ix+2)
 ld (iy+2),a
 ld d,a
 call space_rect_restore
lab_erase_actor_skip:
 ld de,8
 add ix,de
 ld de,4
 add iy,de
 pop bc
 djnz lab_erase_actor_loop
 ld a,(lab_old_ship_x)
 ld e,a
 ld a,(lab_old_ship_y)
 ld d,a
 call space_rect_restore
 pop iy
 pop ix
 pop de
 pop bc
 ret

; Compose FINAL frame; the original generic tile presenter is not used here.
lab_draw:
 push bc
 push de
 push ix
 ld ix,actor_slots
 ld b,8
lab_draw_actor_loop:
 push bc
 ld a,(ix+0)
 or a
 jp z,lab_draw_actor_skip
 ld e,(ix+1)
 ld d,(ix+2)
 ld a,(ix+0)
 call arena_enemy_sprite
 call space_rect_draw
lab_draw_actor_skip:
 ld de,8
 add ix,de
 pop bc
 djnz lab_draw_actor_loop
 ld a,(lab_ship_y)
 ld d,a
 ld a,(lab_ship_x)
 ld e,a
 call arena_player_pose
 call space_rect_draw
 ld ix,bullet_slots
 ld b,16
lab_draw_bullet_loop:
 push bc
 ld a,(ix+0)
 or a
 jp z,lab_draw_bullet_skip
 ld e,(ix+1)
 ld d,(ix+2)
 ld a,(ix+0)
 call arena_bullet_draw
lab_draw_bullet_skip:
 ld de,6
 add ix,de
 pop bc
 djnz lab_draw_bullet_loop
 pop ix
 pop de
 pop bc
 ret

; Present only old/new sprite footprints and updated individual dots.
; Private work is finished before any visible bitmap bytes are transferred.
; Color memory work is skipped when an enemy's complete 8x8 attribute
; footprint does not change. This is the biggest optimization for gliding.
lab_color_initial:
 push bc
 push de
 push ix
 ld ix,actor_slots
 ld b,8
lab_color_initial_loop:
 push bc
 ld a,(ix+0)
 or a
 jp z,lab_color_initial_skip
 ld e,(ix+1)
 ld d,(ix+2)
 call arena_actor_color
 call space_rect_color
lab_color_initial_skip:
 ld de,8
 add ix,de
 pop bc
 djnz lab_color_initial_loop
 ld a,(lab_ship_x)
 ld e,a
 ld a,(lab_ship_y)
 ld d,a
 ld a,(arena_death)
 or a
 ld a,0x46
 jp z,lab_hero_color
 ld a,0x42
lab_hero_color:
 call space_rect_color
 pop ix
 pop de
 pop bc
 ret

; Restore old colors together before repainting in Z order. Only the
; changed attribute footprints need to be transferred to the physical screen.
lab_recolor_actors:
 push bc
 push de
 push iy
 ld iy,lab_old_actors
 ld b,8
lab_recolor_loop:
 ld a,(iy+0)
 or a
 jp z,lab_recolor_next
 ld e,(iy+1)
 ld d,(iy+2)
 ld a,(arena_floor_ink)
 call space_rect_color
lab_recolor_next:
 ld de,4
 add iy,de
 djnz lab_recolor_loop
 ld a,(lab_old_ship_x)
 ld e,a
 ld a,(lab_old_ship_y)
 ld d,a
 ld a,(arena_floor_ink)
 call space_rect_color
 ld a,(arena_boss)
 or a
 call nz,boss_restore_colors
 call lab_color_initial
 pop iy
 pop de
 pop bc
 ret

lab_present:
 push af
 push bc
 push de
 push ix
 push iy
 ld ix,actor_slots
 ld iy,lab_old_actors
 ld b,8
lab_present_actor_loop:
 push bc
 ld a,(iy+0)
 or a
 jp z,lab_present_actor_next
 ld e,(iy+1)
 ld d,(iy+2)
 ld a,(ix+0)
 or a
 jp z,lab_present_old_only
 ld c,(ix+1)
 ld b,(ix+2)
 push bc
 push de
 call arena_present_union
 pop de
 pop bc
 call arena_attr_changed
 jp nz,lab_present_actor_colors
 call arena_actor_color
 cp (iy+3)
 jp z,lab_present_actor_next
lab_present_actor_colors:
 call space_rect_present_colors
 ld e,c
 ld d,b
 jp lab_present_old_colors
lab_present_old_only:
 call space_rect_present
lab_present_old_colors:
 call space_rect_present_colors
lab_present_actor_next:
 ld de,8
 add ix,de
 ld de,4
 add iy,de
 pop bc
 djnz lab_present_actor_loop
 ld a,(lab_old_ship_x)
 ld e,a
 ld a,(lab_old_ship_y)
 ld d,a
 ld a,(lab_ship_x)
 ld c,a
 ld a,(lab_ship_y)
 ld b,a
 push bc
 push de
 call arena_present_union
 pop de
 pop bc
 ld a,(arena_death)
 or a
 jp nz,lab_present_ship_colors
 call arena_attr_changed
 jp z,lab_present_ship_done
lab_present_ship_colors:
 call space_rect_present_colors
 ld e,c
 ld d,b
 call space_rect_present_colors
lab_present_ship_done:
 ld ix,bullet_slots
 ld iy,lab_old_bullets
 ld b,16
lab_present_bullet_loop:
 push bc
 ld a,(iy+0)
 or a
 jp z,lab_present_old_bullet_skip
 ld e,(iy+1)
 ld d,(iy+2)
 ld a,(iy+0)
 call arena_bullet_present
lab_present_old_bullet_skip:
 ld a,(ix+0)
 or a
 jp z,lab_present_new_bullet_skip
 ld e,(ix+1)
 ld d,(ix+2)
 ld a,(ix+0)
 call arena_bullet_present
lab_present_new_bullet_skip:
 ld de,6
 add ix,de
 ld de,3
 add iy,de
 pop bc
 djnz lab_present_bullet_loop
 pop iy
 pop ix
 pop de
 pop bc
 pop af
 ret

 ; NZ if old D/E and new B/C touch different 8x8 attribute cells.
arena_attr_changed:
 ld a,e
 cp c
 jp z,arena_attr_check_y
 xor c
 and 248
 ret nz
 ld a,e
 and 7
 jp z,arena_attr_aligned
 ld a,c
 and 7
 jp z,arena_attr_aligned
arena_attr_check_y:
 ld a,d
 cp b
 ret z
 xor b
 and 248
 ret nz
 ld a,d
 and 7
 jp z,arena_attr_aligned
 ld a,b
 and 7
 jp z,arena_attr_aligned
 xor a
 ret
arena_attr_aligned:
 or 1
 ret

lab_old_actors: ds 64
lab_old_bullets: ds 72
lab_old_ship_x: db 88
lab_old_ship_y: db 88

; HUD stays right of x=192, updated independently via tile dirty presenter.
lab_hud:
 ld d,0
arena_hud_rail:
 ld e,24
 ld a,7
 ld hl,panel_left
 call blit_cell
 ld e,31
 ld hl,panel_right
 call blit_cell
 inc d
 ld a,d
 cp 24
 jp c,arena_hud_rail
 ld d,0
 ld a,0x45
 call panel_rule
 ld d,23
 ld a,0x45
 call panel_rule
 ld d,2
 ld hl,hud_title_error
 ld a,0x47
 call panel_strip
 ld d,3
 ld hl,hud_title_year
 ld a,0x46
 call panel_strip
 ld d,5
 ld a,5
 call panel_rule
 ld d,6
 ld hl,hud_points
 call panel_caption
 call arena_refresh_score
 ld d,10
 ld hl,hud_screen
 call panel_caption
 call arena_refresh_wave
 ld a,(arena_boss)
 or a
 jp nz,panel_boss
 ld a,(arena_sector)
 add a,a
 ld e,a
 ld d,0
 ld hl,hud_sectors
 add hl,de
 ld e,(hl)
 inc hl
 ld d,(hl)
 ex de,hl
 ld d,15
 ld a,7
 call panel_strip
 jp panel_lives
panel_boss:
 ld d,15
 ld hl,hud_smiley
 call panel_caption
 call boss_hud
panel_lives:
 ld d,19
 ld hl,hud_lives
 call panel_caption
 jp arena_refresh_lives

panel_caption:
 ld a,0x45
panel_strip:
 ld e,25
 ld b,6
panel_strip_cell:
 call blit_cell
 push bc
 ld bc,8
 add hl,bc
 pop bc
 inc e
 djnz panel_strip_cell
 ret

; Five fixed-width digits at X=204, split across two character rows.
panel_numbers:
 push iy
 push de
 push hl
 pop iy
 call panel_blank_row
 inc d
 call panel_blank_row
 pop de
 ld b,5
panel_score_digit:
 push bc
 ld a,(iy+0)
 sub 48
 jp nc,panel_number_index
 ld a,10
panel_number_index:
 ld l,a
 ld h,0
 add hl,hl
 add hl,hl
 add hl,hl
 add hl,hl
 ld bc,hud_digits
 add hl,bc
 ld a,0x47
 call blit_cell
 ld bc,8
 add hl,bc
 inc d
 call blit_cell
 dec d
 inc e
 inc iy
 pop bc
 djnz panel_score_digit
 inc d
 push de
 call panel_shift_half
 pop de
 dec d
 pop iy
 jp panel_shift_half
panel_blank_row:
 ld e,25
 ld b,6
 ld hl,boss_bar_tiles
 ld a,0x47
panel_blank_cell:
 call blit_cell
 inc e
 djnz panel_blank_cell
 ret

panel_shift_half:
 ld e,25
 call playfield_addr
 ld d,8
panel_shift_scan:
 push hl
 ld b,6
 ld c,0
panel_shift_byte:
 ld a,(hl)
 rrca
 rrca
 rrca
 rrca
 ld e,a
 and 15
 or c
 ld (hl),a
 ld a,e
 and 240
 ld c,a
 inc l
 djnz panel_shift_byte
 pop hl
 inc h
 dec d
 jp nz,panel_shift_scan
 ret

panel_rule:
 ld hl,panel_line
 ld e,25
 ld b,6
panel_rule_tile:
 call blit_cell
 inc e
 djnz panel_rule_tile
 ret
panel_left:  db 1,1,1,1,1,1,1,1
panel_right: db 128,128,128,128,128,128,128,128
panel_line:  db 0,0,0,255,0,0,0,0
panel_life_left: db 0,3,7,7,4,7,3,0
panel_life_right: db 0,192,224,224,32,224,192,0
panel_empty_left: db 0,3,4,4,4,4,3,0
panel_empty_right: db 0,192,32,32,32,32,192,0

arena_refresh_score:
 ld hl,(arena_kills)
 ld b,48
arena_score_hundreds:
 ld a,h
 or a
 jp nz,arena_score_sub100
 ld a,l
 cp 100
 jp c,arena_score_tens_init
arena_score_sub100:
 ld a,l
 sub 100
 ld l,a
 jp nc,arena_score_hundreds_inc
 dec h
arena_score_hundreds_inc:
 inc b
 jp arena_score_hundreds
arena_score_tens_init:
 ld a,b
 ld (arena_score_digits),a
 ld a,l
 ld hl,arena_score_digits+1
 call arena_two_digits
 ld a,(engine_state)
 cp 1
 ret nz
 ld de,0x0819
 ld hl,arena_score_digits
 jp panel_numbers
arena_refresh_lives:
 ld de,0x1519
 ld a,(arena_lives)
 ld c,a
 ld b,3
arena_life_cell:
 ld hl,panel_life_left
 ld a,0x46
 inc c
 dec c
 jp nz,arena_life_draw
 ld hl,panel_empty_left
 ld a,7
 inc c
arena_life_draw:
 call blit_cell
 inc e
 push bc
 ld bc,8
 add hl,bc
 pop bc
 call blit_cell
 inc e
 dec c
 djnz arena_life_cell
 ret
arena_refresh_wave:
 ld a,(arena_wave)
 ld hl,arena_wave_digits
 call arena_two_digits
 ld a,(engine_state)
 cp 1
 ret nz
 ld de,0x0c19
 ld hl,arena_wave_digits
 jp panel_numbers

arena_two_digits:
 ld b,48
arena_digit_tens:
 cp 10
 jp c,arena_digit_units
 sub 10
 inc b
 jp arena_digit_tens
arena_digit_units:
 ld (hl),b
 inc hl
 add a,48
 ld (hl),a
 ret

arena_result_points: db "PUNTOS  "
arena_score_digits: db "00000",0
arena_result_wave: db "PANTALLA  "
arena_wave_digits: db "01/30",0
lab_ship_x: db 88
lab_ship_y: db 88
lab_frame: db 0
lab_shot_delay: db 0
arena_lives: db 3
arena_invuln: db 0
arena_facing: db 0
arena_axis: db 0
arena_kills: dw 0
arena_last_hits: db 0
arena_remaining: db 8
arena_wave: db 1
arena_sector: db 0
arena_floor_ink: db 1
arena_type_ptr: dw 0
arena_position_ptr: dw 0

arena_death: db 0
arena_blasts: db 0
arena_checkpoint: dw 0

arena_walk_rng: db 1
