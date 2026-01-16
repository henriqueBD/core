class_name player_character
extends CharacterBody2D

var chunk: chunk_mng
var is_editor_active: bool = false

@export_group("Gravity")
@export var gravity_amount: float = 1.5
@export var gravity_multiplier_falling: float = 1.7
@export var external_acceleration_fallof: float = 20

@export_group("Jump")
@export var jump_force: float = -400
@export var coyote_time: float = 0.3
@export var inverse_coyote_time: float = 0.2
@export var air_speed_max: float = 1
@export var air_speed_accel: float = 5
var _coyote_time_ms: int

@export_group("Ground Movement")
@export var ground_speed_max: float = 1.3
@export var ground_speed_accel: float = 7

@export_group("Break terrain")
@export var _mining_level: int
@export var _mining_offset: Vector2
@export var _mining_offset_vertical: Vector2
@export var _swing_cooldown: float

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var editor_logic: Editor = $Editor_logic
@onready var hitbox_pickaxe: Hitbox = $HitboxPickaxe

var _horizontal_input: float
var _vertical_input: float
var _delta_time: float
var _curr_state: STATE = STATE.idle
var _curr_state_callable: Callable = _idle_state
var _last_press_jump: int = -1

var _breaker_sideway: TerrainBreaker = TerrainBreaker.init(TerrainBreaker.create_bitmap_variations("res://assets/sprites/player_break_mask.png", 5), 0, true, 0)
var _breaker_upward: TerrainBreaker = TerrainBreaker.init([TerrainBreaker.create_bitmap("res://assets/sprites/player_break_up_mask.png")], 0, false, 0)
var _breaker_downward: TerrainBreaker = TerrainBreaker.init([TerrainBreaker.create_bitmap("res://assets/sprites/player_break_down_mask.png")], 0, false, 0)

var _is_swinging: bool = false
var _last_swing_input: int

var _hitbox_offset_x: float

func _enter_tree() -> void:
	self.set_physics_process(false)
	Global.player_node = self

func _ready() -> void:
	collision_mask = 1
	collision_mask = 1
	chunk = Global.chunks
	set_mining_level(_mining_level)
	_coyote_time_ms = int(coyote_time * 1000)
	_hitbox_offset_x = to_local(hitbox_pickaxe.global_position).x
	print(_hitbox_offset_x)
	Global.player_spawned.emit()

func _exit_tree() -> void:
	Global.player_node = null

func _physics_process(delta: float) -> void:
	_delta_time = delta
	
	#if _should_try_tunnel and _boost_should_end_time < Time.get_ticks_msec():
		#_should_try_tunnel = false
	
	_gather_input()
	
	_curr_state_callable.call()
	
	#if Input.is_action_just_pressed("hit_pickaxe"):
		#hit_pickaxe()
	
	move_and_slide()

func _gather_input() -> void:
	_horizontal_input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	_vertical_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

#logic for changing states
#region State Machine

enum STATE {
	idle,
	walk,
	airborne,
	jump,
	swing,
}

func change_state(new_state: STATE) -> void:
	#_log_state(new)
	
	match _curr_state:
		STATE.idle:
			_idle_state_leave()
		STATE.airborne:
			_airborne_state_leave()
	
	_curr_state = new_state
	
	match new_state:
		STATE.idle:
			_curr_state_callable = _idle_state
			_idle_state_enter()
		STATE.walk:
			_curr_state_callable = _walk_state
			_walk_state_enter()
		STATE.airborne:
			_curr_state_callable = _airborne_state
			_airborne_state_enter()
		STATE.jump:
			_curr_state_callable = _jump_state

func _log_state(state: STATE) -> void:
	print(str(STATE.keys()[state]))

#endregion

#region States

func _no_clip_state() -> void:
	velocity.x += _horizontal_input
	velocity.y += _vertical_input

# ---------- Idle ----------

func _idle_state_enter() -> void:
	if !is_on_floor():
		change_state(STATE.airborne)
		return
	
	if Time.get_ticks_msec() - _last_press_jump < inverse_coyote_time * 1000:
		_last_press_jump = -1
		change_state(STATE.jump)
		return
	
	if _horizontal_input != 0.0:
		change_state(STATE.walk)
		return
		
	_check_looking_dir()
	
	if Global.picked_pickaxe:
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("idle_no_pickaxe")
	
	velocity.x = 0.0

func _idle_state() -> void:
	if !is_on_floor():
		change_state(STATE.airborne)
		return
	
	if _valid_swing_input():
		_is_swinging = true
		if animated_sprite_2d.flip_h:
			animated_sprite_2d.offset.x = -4
		else:
			animated_sprite_2d.offset.x = 4
		animated_sprite_2d.play("idle_swing")
		animated_sprite_2d.animation_finished.connect(_idle_swing_end, CONNECT_ONE_SHOT)
		_pickaxe_logic()
	
	if Input.is_action_just_pressed("jump"):
		change_state(STATE.jump)
		return
	
	if _horizontal_input != 0.0:
		change_state(STATE.walk)
		return

func _idle_swing_end() -> void:
	animated_sprite_2d.offset.x = 0
	if Global.picked_pickaxe:
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("idle_no_pickaxe")

func _idle_state_leave() -> void:
	if animated_sprite_2d.animation_finished.is_connected(_idle_swing_end):
		animated_sprite_2d.offset = Vector2.ZERO
		_is_swinging = false
		animated_sprite_2d.animation_finished.disconnect(_idle_swing_end)

# ---------- Walk ----------

func _walk_state_enter() -> void:
	if Global.picked_pickaxe:
		animated_sprite_2d.play("walk")
	else:
		animated_sprite_2d.play("walk_no_pickaxe")

func _walk_state() -> void:
	if !is_on_floor():
		_allow_coyote_time()
		change_state(STATE.airborne)
		return
	
	_check_looking_dir()
	if _horizontal_input == 0.0:
		velocity.x = 0.0
		change_state(STATE.idle)
		return
	
	velocity.y += gravity_amount * _delta_time
	
	if Input.is_action_just_pressed("jump"):
		change_state(STATE.jump)
		return
	if sign(_horizontal_input) == 1.0:
		velocity.x = min(velocity.x + (ground_speed_accel * _delta_time), ground_speed_max)
	else:
		velocity.x = max(velocity.x - (ground_speed_accel * _delta_time), -ground_speed_max)

# ---------- Jump ----------

func _jump_state() -> void:
	_block_coyote_time()
	velocity.y = -jump_force
	change_state(STATE.airborne)

#func _jump_state_enter() -> void:
	#animated_sprite_2d.play("jump")
	#animated_sprite_2d.animation_finished.connect(_jump_state_leave, CONNECT_ONE_SHOT)
#
#func _jump_state() -> void:
	#if !is_on_floor():
		#animated_sprite_2d.animation_finished.disconnect(_jump_state_leave)
		#change_state(STATE.airborne)
#
#func _jump_state_leave() -> void:
	#_block_coyote_time()
	#velocity.y = -jump_force
	#change_state(STATE.airborne)

# ---------- Airborne ----------

var _airborne_time_enter: int = -1

func _allow_coyote_time() -> void:
	_airborne_time_enter = Time.get_ticks_msec()

func _block_coyote_time() -> void:
	_airborne_time_enter = -1

func _airborne_state_enter() -> void:
	if Global.picked_pickaxe:
		animated_sprite_2d.play("airborne")
	else:
		animated_sprite_2d.play("airborne_no_pickaxe")

func _airborne_state() -> void:
	if is_on_floor():
		if _horizontal_input == 0.0: change_state(STATE.idle)
		else: change_state(STATE.walk)
		return
	
	if _valid_swing_input():
		_is_swinging = true
		_pickaxe_logic()
		if animated_sprite_2d.flip_h:
			animated_sprite_2d.offset = Vector2(-5, 3)
		else:
			animated_sprite_2d.offset = Vector2(5, 3)
		animated_sprite_2d.play("airborne_swing")
		animated_sprite_2d.animation_finished.connect(_airbone_swing_end, CONNECT_ONE_SHOT)
	
	if Input.is_action_just_pressed("jump"):
		var time_now: int = Time.get_ticks_msec()
		if time_now - _airborne_time_enter < coyote_time * 1000:
			change_state(STATE.jump)
			return
		else:
			_last_press_jump = time_now
	
	_check_looking_dir()
	if _horizontal_input == 0.0:
		velocity.x += (air_speed_accel * _delta_time * sign(-velocity.x))
	else:
		if sign(_horizontal_input) == 1.0:
			velocity.x = min(velocity.x + (air_speed_accel * _delta_time), air_speed_max)
		else:
			velocity.x = max(velocity.x - (air_speed_accel * _delta_time), -air_speed_max)
	
	if sign(velocity.y) == 1.0:
		velocity.y += gravity_amount * gravity_multiplier_falling * _delta_time
	else:
		velocity.y += gravity_amount * _delta_time

func _airbone_swing_end() -> void:
	animated_sprite_2d.offset = Vector2.ZERO
	_is_swinging = false
	if Global.picked_pickaxe:
		animated_sprite_2d.play("airborne")
	else:
		animated_sprite_2d.play("airborne_no_pickaxe")

func _airborne_state_leave() -> void:
	if animated_sprite_2d.animation_finished.is_connected(_airbone_swing_end):
		animated_sprite_2d.offset = Vector2.ZERO
		_is_swinging = false
		animated_sprite_2d.animation_finished.disconnect(_airbone_swing_end)

#endregion

func _valid_swing_input() -> bool:
	#if !Global.picked_pickaxe: return false
	var time_now: int = Time.get_ticks_msec()
	if Input.is_action_just_pressed("hit_pickaxe") and _last_swing_input + _swing_cooldown < time_now:
		_last_swing_input = time_now
		return true
	else: return false

func _get_angle_input() -> float:
	var input_dir: Vector2 = Vector2.ZERO
	if _horizontal_input != 0.0: input_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0: input_dir.y = sign(_vertical_input)
	return input_dir.angle()

func _check_looking_dir() -> void:
	if _horizontal_input != 0:
		animated_sprite_2d.flip_h = _horizontal_input < 0.0

## Breaks terrain and updates hitbox
func _pickaxe_logic() -> void:
	var collision_shape_2d: CollisionShape2D = $CollisionShape2D
	var rect: Rect2 = collision_shape_2d.shape.get_rect()
	rect.position = collision_shape_2d.to_global(rect.position)
	if _vertical_input != 0:
		if _vertical_input > 0:
			_breaker_downward.break_terrain(
				_breaker_downward.center_bottom_to_top_left(Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y))
			)
		else:
			_breaker_upward.break_terrain(
				_breaker_upward.center_top_to_top_left(rect.position + Vector2(rect.size.x, 0))
			)
	else:
		if animated_sprite_2d.flip_h:
			_breaker_sideway.break_terrain_random_flip_x(
				_breaker_sideway.bottom_right_to_top_left(rect.position + Vector2(0, rect.size.y))
			)
		else:
			_breaker_sideway.break_terrain_random(
				_breaker_sideway.bottom_left_to_top_left(rect.position + rect.size)
			)
	
	if animated_sprite_2d.flip_h:
		hitbox_pickaxe.position.x = -_hitbox_offset_x
	else:
		hitbox_pickaxe.position.x = _hitbox_offset_x
	
	hitbox_pickaxe.hit_single_frame()

func set_mining_level(new_level: int) -> void:
	_mining_level = new_level
	_breaker_upward.force = new_level
	_breaker_sideway.force = new_level
	_breaker_downward.force = new_level

func teleport(new_world_coords: Vector2) -> void:
	global_position = new_world_coords

func is_looking_foward() -> float:
	if velocity.x != 0.0: return sign(velocity.x)
	if animated_sprite_2d.flip_h: return -1.0
	else: return 1.0
