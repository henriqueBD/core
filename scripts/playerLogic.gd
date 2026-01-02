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
@export var _pickaxe_boost_force: float
@export var _boost_break_time_ms: int
@export var _tunelling_speed: float
@export var _turning_speed_tunneling: float
@export var _exit_speed: float

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var editor_logic: Editor = $Editor_logic

var _external_acell: Vector2
var _horizontal_input: float
var _vertical_input: float
var _delta_time: float
var _curr_state: Callable = _idle_state
var _bounds: Rect2

var _breaker_sideway: TerrainBreaker = TerrainBreaker.init(TerrainBreaker.create_bitmap_variations("res://assets/sprites/player_break_mask.png", 5), 0, true, 0)
var _breaker_upward: TerrainBreaker = TerrainBreaker.init([TerrainBreaker.create_bitmap("res://assets/sprites/player_break_up_mask.png")], 0, false, 0)
var _breaker_downward: TerrainBreaker = TerrainBreaker.init([TerrainBreaker.create_bitmap("res://assets/sprites/player_break_down_mask.png")], 0, false, 0)

func _enter_tree() -> void:
	self.set_physics_process(false)
	Global.player_node = self

func _ready() -> void:
	collision_mask = 1
	collision_mask = 1
	chunk = Global.chunks
	set_mining_level(_mining_level)
	_coyote_time_ms = int(coyote_time * 1000)
	Global.player_spawned.emit()

func _exit_tree() -> void:
	Global.player_node = null

func _physics_process(delta: float) -> void:
	_delta_time = delta
	
	#if _should_try_tunnel and _boost_should_end_time < Time.get_ticks_msec():
		#_should_try_tunnel = false
	
	_gather_input()
	
	_curr_state.call()
	
	if Input.is_action_just_pressed("hit_pickaxe"):
		hit_pickaxe()
	
	_external_acell = _external_acell.move_toward(
		Vector2.ZERO, external_acceleration_fallof * delta)
	
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

func change_state(new: STATE) -> void:
	#_log_state(new)
	match new:
		STATE.idle:
			_curr_state = _idle_state
			_idle_state_enter()
		STATE.walk:
			_curr_state = _walk_state
		STATE.airborne:
			_curr_state = _airborne_state
		STATE.jump:
			_curr_state = _jump_state

func _log_state(state: STATE) -> void:
	print(str(STATE.keys()[state]))

#endregion

#region States

func _no_clip_state() -> void:
	velocity = Vector2.ZERO
	velocity.x += _horizontal_input
	velocity.y += _vertical_input

## Idle
var last_press_jump: int = -1

func _idle_state_enter() -> void:
	if Time.get_ticks_msec() - last_press_jump < inverse_coyote_time * 1000:
		last_press_jump = -1
		change_state(STATE.jump)
		return
	
	if _horizontal_input != 0.0:
		change_state(STATE.walk)
		return
		
	_check_looking_dir()
	velocity.x = 0.0

func _idle_state() -> void:
	velocity.y += gravity_amount * _delta_time
	
	if _external_acell.y != 0:
		change_state(STATE.walk)
		return
	if _external_acell.y < 0:
		change_state(STATE.airborne)
		return
	
	if Input.is_action_just_pressed("jump"):
		change_state(STATE.jump)
		return
		
	if _horizontal_input != 0.0:
		change_state(STATE.walk)
		return

## Walk
func _walk_state() -> void:
	if !is_on_floor():
		_allow_coyote_time()
		change_state(STATE.airborne)
		return
	
	#if _should_try_tunnel:
		#if collisions.left_collision or collisions.right_collision:
			#change_state(STATE.tunnel)
			#return
	
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

## Jump
func _jump_state() -> void:
	_block_coyote_time()
	velocity.y = -jump_force
	change_state(STATE.airborne)


## Airborne
var _airborne_time_enter: int = -1

func _allow_coyote_time() -> void:
	_airborne_time_enter = Time.get_ticks_msec()

func _block_coyote_time() -> void:
	_airborne_time_enter = -1

func _airborne_state() -> void:
	#if _should_try_tunnel and (collisions.above_collision or collisions.below_collision
	#or collisions.left_collision or collisions.right_collision):
		#change_state(STATE.tunnel)
		#return
	
	if is_on_floor():
		if _horizontal_input == 0.0: change_state(STATE.idle)
		else: change_state(STATE.walk)
		return
		
	if Input.is_action_just_pressed("jump"):
		var time_now: int = Time.get_ticks_msec()
		if time_now - _airborne_time_enter < coyote_time * 1000:
			change_state(STATE.jump)
			return
		else:
			last_press_jump = time_now
	
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

#endregion

func _get_angle_input() -> float:
	var input_dir: Vector2 = Vector2.ZERO
	if _horizontal_input != 0.0: input_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0: input_dir.y = sign(_vertical_input)
	return input_dir.angle()

func _check_looking_dir() -> void:
	if _horizontal_input != 0:
		animated_sprite_2d.flip_h = _horizontal_input < 0.0

func hit_pickaxe() -> void:
	var collision_shape_2d: CollisionShape2D = $CollisionShape2D
	var rect: Rect2 = collision_shape_2d.shape.get_rect()
	rect.position = collision_shape_2d.to_global(rect.position)
	if _vertical_input != 0:
		if _vertical_input > 0:
			_breaker_downward.break_terrain(Vector2(rect.position.x, rect.position.y + rect.size.y) + _mining_offset_vertical)
		else:
			_breaker_upward.break_terrain(rect.position + _mining_offset_vertical)
	else:
		if animated_sprite_2d.flip_h:
			_breaker_sideway.break_terrain_flip_x_random(Vector2(rect.position - _mining_offset), true)
		else:
			_breaker_sideway.break_terrain_random(rect.position + _mining_offset)

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
