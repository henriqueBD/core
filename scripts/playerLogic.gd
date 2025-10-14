class_name player_character
extends Node2D

var chunk: chunk_mng
@onready var collisions: CollisionObj = $Collision
@onready var state_machine: Node2D = $StateMachine
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var editor_logic: Editor = $Editor_logic
var is_editor_active: bool = false

@export_group("Gravity")
@export var gravity_amount: float = 1.5
@export var gravity_multiplier_falling: float = 1.7
@export var external_acceleration_fallof: float = 20

@export_group("Jump")
@export var jump_force: float = 5
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
@export var _pickaxe_boost_force: float
@export var _boost_break_time_ms: int
@export var _tunelling_speed: float
@export var _turning_speed_tunneling: float
@export var _exit_speed: float

var _curr_velocity: Vector2
var _external_acell: Vector2
var _horizontal_input: float
var _vertical_input: float
var _delta_time: float
var _looking_foward: bool = true

var _try_tunelling_end_ms: int
var _should_try_tunnel: bool
var _is_tunneling: bool

func _enter_tree() -> void:
	Global.player_node = self

func _ready() -> void:
	chunk = Global.chunks
	_coyote_time_ms = int(coyote_time * 1000)
	collisions.check_collisions_while_deactivated = true

func _exit_tree() -> void:
	Global.player_node = null

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("togle_editor"):
		if is_editor_active:
			editor_logic.deactivate()
			is_editor_active = false
			chunk.should_mouse_break = true
		else:
			editor_logic.activate()
			is_editor_active = true
			chunk.should_mouse_break = false
	
	if is_editor_active:
		editor_logic.update()
		return
	
	_delta_time = delta
	
	if _should_try_tunnel and _boost_should_end_time < Time.get_ticks_msec():
		_should_try_tunnel = false
	
	_check_collisions()
	
	_gather_input()
	currState.call()
	if Input.is_action_just_pressed("hit_pickaxe"):
		hit_pickaxe()
	
	_external_acell = _external_acell.move_toward(
		Vector2.ZERO, external_acceleration_fallof * delta)
	
	collisions.move(_curr_velocity + _external_acell)

func _check_collisions() -> void:
	if collisions.below_collision:
		_curr_velocity.y = 0.1
	if collisions.above_collision:
		_curr_velocity.y = 0.0
	if collisions.left_collision or collisions.right_collision:
		_curr_velocity.x = 0.0

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
	tunnel,
}

var currState: Callable = _idle_state

func change_state(new: STATE) -> void:
	#_log_state(new)
	match new:
		STATE.idle:
			currState = _idle_state
			_idle_state_enter()
		STATE.walk:
			currState = _walk_state
		STATE.airborne:
			currState = _airborne_state
		STATE.jump:
			currState = _jump_state
		STATE.tunnel:
			_tunnel_state_enter()
			currState = _tunnel_state
			
func _log_state(state: STATE) -> void:
	print(str(STATE.keys()[state]))

#endregion

#region States

func _no_clip_state() -> void:
	_curr_velocity = Vector2.ZERO
	_curr_velocity.x += _horizontal_input
	_curr_velocity.y += _vertical_input


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
	_curr_velocity.x = 0.0

func _idle_state() -> void:
	_curr_velocity.y += gravity_amount * _delta_time
	
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
	if !collisions.below_collision:
		_allow_coyote_time()
		change_state(STATE.airborne)
		return
	
	if _should_try_tunnel:
		if collisions.left_collision or collisions.right_collision:
			change_state(STATE.tunnel)
			return
	
	_check_looking_dir()
	if _horizontal_input == 0.0:
		_curr_velocity.x = 0.0
		change_state(STATE.idle)
		return
	
	_curr_velocity.y += gravity_amount * _delta_time
	
	if Input.is_action_just_pressed("jump"):
		change_state(STATE.jump)
		return
	if sign(_horizontal_input) == 1.0:
		_curr_velocity.x = min(_curr_velocity.x + (ground_speed_accel * _delta_time), ground_speed_max)
	else:
		_curr_velocity.x = max(_curr_velocity.x - (ground_speed_accel * _delta_time), -ground_speed_max)


## Jump
func _jump_state() -> void:
	_block_coyote_time()
	_curr_velocity.y = -jump_force
	change_state(STATE.airborne)


## Airborne
var _airborne_time_enter: int = -1

func _allow_coyote_time() -> void:
	_airborne_time_enter = Time.get_ticks_msec()

func _block_coyote_time() -> void:
	_airborne_time_enter = -1

func _airborne_state() -> void:
	if _should_try_tunnel and (collisions.above_collision or collisions.below_collision
	or collisions.left_collision or collisions.right_collision):
		change_state(STATE.tunnel)
		return
	
	if collisions.below_collision:
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
		_curr_velocity.x += (air_speed_accel * _delta_time * sign(-_curr_velocity.x))
	else:
		if sign(_horizontal_input) == 1.0:
			_curr_velocity.x = min(_curr_velocity.x + (air_speed_accel * _delta_time), air_speed_max)
		else:
			_curr_velocity.x = max(_curr_velocity.x - (air_speed_accel * _delta_time), -air_speed_max)
	
	if sign(_curr_velocity.y) == 1.0:
		_curr_velocity.y += gravity_amount * gravity_multiplier_falling * _delta_time
	else:
		_curr_velocity.y += gravity_amount * _delta_time


## TUNNEL
var _boost_should_end_time: int
var curr_angle: float

func _tunnel_state_enter() -> void:
	collisions.deactivate()
	_external_acell = Vector2.ZERO
	_is_tunneling = true
	var input_dir: Vector2 = Vector2.ZERO
	if _horizontal_input != 0.0: input_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0: input_dir.y = sign(_vertical_input)
	curr_angle = input_dir.angle()

func _tunnel_state() -> void:
	if _boost_should_end_time < Time.get_ticks_msec():
		_tunnel_state_leave()
		change_state(STATE.airborne)
		return
	
	var input_dir: Vector2 = Vector2.ZERO
	
	if _horizontal_input != 0.0:
		input_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0:
		input_dir.y = sign(_vertical_input)
	
	if input_dir != Vector2.ZERO:
		curr_angle = lerp_angle(curr_angle, input_dir.angle(), _turning_speed_tunneling * _delta_time)
		_curr_velocity = Vector2.from_angle(curr_angle) * _tunelling_speed * _delta_time
	
	#check eval_area (chunk_tile) for the return description
	var tiles_direction: Vector2 = chunk.eval_area(collisions._global_bounds.grow(3), _mining_level)
	
	if !is_nan(tiles_direction.y):
		_tunnel_state_leave(false)
		change_state(STATE.airborne)
		return
	if !is_nan(tiles_direction.x):
		if abs(angle_difference(curr_angle, tiles_direction.x)) < 2.9671:
			chunk.break_tiles(collisions._global_bounds.grow(1), _mining_level)
		else:
			_tunnel_state_leave()
			change_state(STATE.airborne)
			return
	else:
		_tunnel_state_leave()
		change_state(STATE.airborne)
		return

func _tunnel_state_leave(give_boost: bool = true) -> void:
	chunk.break_tiles(collisions._global_bounds.grow(3), _mining_level)
	_curr_velocity = Vector2.ZERO
	
	if give_boost: _external_acell = Vector2.from_angle(curr_angle) * _exit_speed
	else: _external_acell = Vector2.ZERO
	
	_boost_should_end_time = -1
	_is_tunneling = false
	_should_try_tunnel = false
	collisions.activate()

func _get_angle_input() -> float:
	var input_dir: Vector2 = Vector2.ZERO
	if _horizontal_input != 0.0: input_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0: input_dir.y = sign(_vertical_input)
	return input_dir.angle()

#endregion

func _check_looking_dir() -> void:
	if _horizontal_input != 0:
		animated_sprite_2d.flip_h = _horizontal_input < 0.0

func hit_pickaxe() -> void:
	var boost_dir: Vector2 = Vector2.ZERO
	
	if _horizontal_input != 0.0:
		boost_dir.x = sign(_horizontal_input)
	if _vertical_input != 0.0:
		boost_dir.y = sign(_vertical_input)
	
	if boost_dir == Vector2.ZERO:
		boost_dir.x = -1.0 if animated_sprite_2d.flip_h else 1.0
	
	_external_acell += boost_dir.normalized() * _pickaxe_boost_force
	_boost_should_end_time = Time.get_ticks_msec() + _boost_break_time_ms
	_should_try_tunnel = true
