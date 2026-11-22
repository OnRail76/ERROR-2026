; Demo independently authored for this toolkit, no assets/stories from GRIT.
; Change game/demo.asm to build a new game; keep engine modules unchanged.
; PLAYFIELD: x=0..23, y=0..23. HUD: x=24..31.

; Entry: new game. This is not a mockup: playable machine code Z80.
demo_init:
 call engine_enter_play
 call screen_clear
 call map_load
 call map_draw
 xor a
 ld (demo_frame_counter),a
 ld (demo_score),a
 ld (demo_state),a
 ld (demo_bullet_alive),a
 ld (demo_invuln),a
 ld (demo_fire_cool),a
 ld (move_dx),a
 ld (move_dy),a
 ld a,255
 ld (demo_hud_score_cache),a
 ld (demo_hud_hp_cache),a
 ld a,3
 ld (demo_hp),a
 ld a,11
 ld (demo_x),a
 ld a,18
 ld (demo_y),a
 ld a,88
 ld (demo_display_x),a
 ld a,144
 ld (demo_display_y),a
 ld a,255
 ld (demo_aim_y),a
 xor a
 ld (demo_aim_x),a
 ld a,6
 ld (demo_enemy_1x),a
 ld a,17
 ld (demo_enemy_2x),a
 ld a,1
 ld (demo_enemy_dir1),a
 ld (demo_enemy_dir2),a
 call demo_hud_base
 call demo_draw
 call present_full
 ret

demo_frame:
 call engine_is_terminal
 jp nz,demo_end_screen
 call demo_erase
 call keys_poll
 ld a,(demo_fire_cool)
 or a
 jp z,demo_no_cool
 dec a
 ld (demo_fire_cool),a
demo_no_cool:
 ld a,(demo_invuln)
 or a
 jp z,demo_no_inv
 dec a
 ld (demo_invuln),a
demo_no_inv:
 ld a,(demo_frame_counter)
 and 1
 jp nz,demo_skip_move
 call demo_move
demo_skip_move:
 call demo_display_ease
 call demo_fire
 call demo_bullet_step
 call demo_enemy_step
 call demo_check_hit
 call demo_draw
 call demo_hud_numbers
 ld a,(demo_frame_counter)
 inc a
 ld (demo_frame_counter),a
 ret

; Restore background for everything that was visible in last frame.
demo_erase:
 ld a,(demo_display_y)
 ld d,a
 ld a,(demo_display_x)
 ld e,a
 call pixel_restore_16
 ld d,6
 ld a,(demo_enemy_1x)
 ld e,a
 call map_restore
 ld d,13
 ld a,(demo_enemy_2x)
 ld e,a
 call map_restore
 ld a,(demo_bullet_alive)
 or a
 ret z
 ld a,(demo_bullet_y)
 ld d,a
 ld a,(demo_bullet_x)
 ld e,a
 jp map_restore

; Attempt both axes separately (diagonal if both keys), collision on all
; four tiles of the player's 16x16 footprint.
demo_move:
 ld a,(move_dx)
 or a
 jp z,demo_move_y
 ld b,a
 ld a,(demo_x)
 add a,b
 cp 23
 jp nc,demo_move_y
 ld e,a
 ld a,(demo_y)
 ld d,a
 call demo_solid_quad
 or a
 jp nz,demo_move_y
 ld a,e
 ld (demo_x),a
demo_move_y:
 ld a,(move_dy)
 or a
 jp z,demo_aim
 ld b,a
 ld a,(demo_y)
 add a,b
 cp 23
 jp nc,demo_aim
 ld d,a
 ld a,(demo_x)
 ld e,a
 call demo_solid_quad
 or a
 jp nz,demo_aim
 ld a,d
 ld (demo_y),a
demo_aim:
 ld a,(move_dx)
 ld b,a
 ld a,(move_dy)
 or b
 ret z
 ld a,b
 ld (demo_aim_x),a
 ld a,(move_dy)
 ld (demo_aim_y),a
 ret

 ; HALCONES technology transfer: gameplay remains tile-based (collisions
 ; unchanged), the visible player eases by FOUR real pixels per update.
 ; This intentionally exercises all eight preshift phases for other speeds.
demo_display_ease:
 ld a,(demo_x)
 add a,a
 add a,a
 add a,a
 ld b,a
 ld a,(demo_display_x)
 cp b
 jp z,demo_ease_y
 jp c,demo_ease_right
 sub 4
 jp demo_ease_x_store
demo_ease_right:
 add a,4
demo_ease_x_store:
 ld (demo_display_x),a
demo_ease_y:
 ld a,(demo_y)
 add a,a
 add a,a
 add a,a
 ld b,a
 ld a,(demo_display_y)
 cp b
 ret z
 jp c,demo_ease_down
 sub 4
 jp demo_ease_y_store
demo_ease_down:
 add a,4
demo_ease_y_store:
 ld (demo_display_y),a
 ret

demo_solid_quad:
 push de
 call map_is_solid
 or a
 jp nz,demo_quad_done
 inc e
 call map_is_solid
 or a
 jp nz,demo_quad_done
 inc d
 call map_is_solid
 or a
 jp nz,demo_quad_done
 dec e
 call map_is_solid
demo_quad_done:
 pop de
 ret

demo_fire:
 call engine_is_terminal
 ret nz
 ld a,(fire_down)
 or a
 ret z
 ld a,(demo_fire_cool)
 or a
 ret nz
 ld a,(demo_bullet_alive)
 or a
 ret nz
 ld a,(demo_x)
 inc a
 ld (demo_bullet_x),a
 ld a,(demo_y)
 ld (demo_bullet_y),a
 ld a,(demo_aim_x)
 ld (demo_bullet_dx),a
 ld a,(demo_aim_y)
 ld (demo_bullet_dy),a
 ld a,1
 ld (demo_bullet_alive),a
 ld a,5
 ld (demo_fire_cool),a
 call fx_fire
 ret

demo_bullet_step:
 call engine_is_terminal
 ret nz
 ld a,(demo_bullet_alive)
 or a
 ret z
 ld a,(demo_bullet_dx)
 ld b,a
 ld a,(demo_bullet_x)
 add a,b
 cp 24
 jp nc,demo_bullet_drop
 ld (demo_bullet_x),a
 ld e,a
 ld a,(demo_bullet_dy)
 ld b,a
 ld a,(demo_bullet_y)
 add a,b
 cp 24
 jp nc,demo_bullet_drop
 ld (demo_bullet_y),a
 ld d,a
 call map_is_solid
 or a
 jp nz,demo_bullet_drop
 ; Collision with enemy 1, Y=6.
 ld a,(demo_bullet_y)
 cp 6
 jp nz,demo_bullet_enemy2
 ld a,(demo_bullet_x)
 ld b,a
 ld a,(demo_enemy_1x)
 cp b
 jp nz,demo_bullet_enemy2
 ld a,3
 ld (demo_enemy_1x),a
 jp demo_enemy_hit
demo_bullet_enemy2:
 ld a,(demo_bullet_y)
 cp 13
 ret nz
 ld a,(demo_bullet_x)
 ld b,a
 ld a,(demo_enemy_2x)
 cp b
 ret nz
 ld a,20
 ld (demo_enemy_2x),a
demo_enemy_hit:
 ld a,(demo_score)
 inc a
 ld (demo_score),a
 call fx_hit
 cp 10
 jp c,demo_bullet_drop
 ld a,1
 ld (demo_state),a
 call engine_enter_victory
demo_bullet_drop:
 xor a
 ld (demo_bullet_alive),a
 ret

; Two independent enemies moving horizontally in their own rows.
demo_enemy_step:
 call engine_is_terminal
 ret nz
 ld a,(demo_frame_counter)
 and 3
 ret nz
 ld a,(demo_enemy_dir1)
 ld b,a
 ld a,(demo_enemy_1x)
 add a,b
 cp 21
 jp c,demo_enemy1_low
 ld a,255
 ld (demo_enemy_dir1),a
 ld a,19
 jp demo_enemy1_store
demo_enemy1_low:
 cp 2
 jp nc,demo_enemy1_store
 ld a,1
 ld (demo_enemy_dir1),a
 ld a,3
demo_enemy1_store:
 ld (demo_enemy_1x),a
 ld a,(demo_enemy_dir2)
 ld b,a
 ld a,(demo_enemy_2x)
 add a,b
 cp 21
 jp c,demo_enemy2_low
 ld a,255
 ld (demo_enemy_dir2),a
 ld a,19
 jp demo_enemy2_store
demo_enemy2_low:
 cp 2
 jp nc,demo_enemy2_store
 ld a,1
 ld (demo_enemy_dir2),a
 ld a,3
demo_enemy2_store:
 ld (demo_enemy_2x),a
 ret

; One-hit invulnerability to prevent rapid unavoidable health loss.
demo_check_hit:
 call engine_is_terminal
 ret nz
 ld a,(demo_invuln)
 or a
 ret nz
 ld a,(demo_y)
 cp 6
 jp z,demo_hit_enemy1
 inc a
 cp 6
 jp z,demo_hit_enemy1
 ld a,(demo_y)
 cp 13
 jp z,demo_hit_enemy2
 inc a
 cp 13
 jp z,demo_hit_enemy2
 ret
demo_hit_enemy1:
 ld a,(demo_enemy_1x)
 ld b,a
 jp demo_check_x
demo_hit_enemy2:
 ld a,(demo_enemy_2x)
 ld b,a
demo_check_x:
 ld a,(demo_x)
 cp b
 jp z,demo_damage
 inc a
 cp b
 ret nz
demo_damage:
 ld a,(demo_hp)
 dec a
 ld (demo_hp),a
 call fx_damage
 or a
 jp nz,demo_damage_survived
 ld a,2
 ld (demo_state),a
 call engine_enter_gameover
 ret
demo_damage_survived:
 ld a,25
 ld (demo_invuln),a
 ld a,11
 ld (demo_x),a
 ld a,18
 ld (demo_y),a
 ret

; Draw everything in shadow, THEN presenter copies only dirty cells.
demo_draw:
 ld d,6
 ld a,(demo_enemy_1x)
 ld e,a
 ld hl,sprite_enemy_mask
 ld (mask_src),hl
 ld hl,sprite_enemy
 ld a,0x42
 call blit_masked_cell
 ld d,13
 ld a,(demo_enemy_2x)
 ld e,a
 ld hl,sprite_enemy_mask
 ld (mask_src),hl
 ld hl,sprite_enemy
 ld a,0x43
 call blit_masked_cell
 ld a,(demo_display_y)
 ld d,a
 ld a,(demo_display_x)
 ld e,a
 ld hl,pixel_sprite_player_phases
 ld a,0x46
 call pixel_draw_16
 ld a,(demo_bullet_alive)
 or a
 ret z
 ld a,(demo_bullet_y)
 ld d,a
 ld a,(demo_bullet_x)
 ld e,a
 ld hl,sprite_bullet_mask
 ld (mask_src),hl
 ld hl,sprite_bullet
 ld a,0x47
 jp blit_masked_cell

; 64-pixel HUD is never included in gameplay scroll or tile restore.
demo_hud_base:
 ld d,2
 ld e,25
 ld hl,hud_head
 call text_draw
 ld d,4
 ld e,25
 ld hl,hud_sub
 call text_draw
 ld d,7
 ld e,25
 ld hl,hud_score
 call text_draw
 ld d,12
 ld e,25
 ld hl,hud_health
 call text_draw
 ld d,18
 ld e,25
 ld hl,hud_controls
 call text_draw
 ld d,20
 ld e,25
 ld hl,hud_space
 call text_draw
 call demo_hud_numbers
 ret
demo_hud_numbers:
 ld a,(demo_score)
 ld b,a
 ld a,(demo_hud_score_cache)
 cp b
 jp z,demo_hud_score_unchanged
 ld a,b
 ld (demo_hud_score_cache),a
 ld d,9
 ld e,27
 call demo_2digits
demo_hud_score_unchanged:
 ld a,(demo_hp)
 ld b,a
 ld a,(demo_hud_hp_cache)
 cp b
 ret z
 ld a,b
 ld (demo_hud_hp_cache),a
 ld d,14
 ld e,27
 call demo_2digits
 ret
; A unsigned <=99. Draw two decimal digits using Spectrum ROM glyphs.
demo_2digits:
 ld b,0
demo_div10:
 cp 10
 jp c,demo_tens_done
 sub 10
 inc b
 jp demo_div10
demo_tens_done:
 push af
 ld a,b
 add a,48
 call font_cell
 inc e
 pop af
 add a,48
 jp font_cell

; Win/lose screens remain until SPACE is released then pressed anew.
demo_end_screen:
 call screen_clear
 ld a,(demo_state)
 cp 1
 jp nz,demo_end_lose
 ld hl,msg_win
 jp demo_end_title
demo_end_lose:
 ld hl,msg_lose
demo_end_title:
 ld d,8
 ld e,7
 call text_draw
 ld hl,msg_replay
 ld d,15
 ld e,7
 call text_draw
 call present_full
 ld b,100
 call engine_wait_50hz
 call space_release
 call space_press
 call demo_init
 ret

hud_head: db "ZX48",0
hud_sub: db "DEMO 1",0
hud_score: db "PUNTOS",0
hud_health: db "VIDAS",0
hud_controls: db "QAOP",0
hud_space: db "SPACE",0
msg_win: db "DEMO SUPERADA",0
msg_lose: db "GAME OVER",0
msg_replay: db "SPACE REINICIA",0

demo_x: db 11
demo_y: db 18
demo_display_x: db 88
demo_display_y: db 144
demo_hp: db 3
demo_score: db 0
demo_hud_score_cache: db 255
demo_hud_hp_cache: db 255
demo_state: db 0
demo_frame_counter: db 0
demo_aim_x: db 0
demo_aim_y: db 255
demo_bullet_alive: db 0
demo_bullet_x: db 0
demo_bullet_y: db 0
demo_bullet_dx: db 0
demo_bullet_dy: db 255
demo_fire_cool: db 0
demo_invuln: db 0
demo_enemy_1x: db 6
demo_enemy_2x: db 17
demo_enemy_dir1: db 1
demo_enemy_dir2: db 255
