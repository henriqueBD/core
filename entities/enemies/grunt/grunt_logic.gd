extends CharacterBody2D

# TODO: Dynamic object
# TODO: Remove magic numbers

@export var _walk_speed: float = 1300
@export var _run_speed_max: float = 3000
@export var _run_accel: float = 4000

@onready var player_detection_chase: PlayerDetection = $PlayerDetection
@onready var player_detection_attack: PlayerDetection = $PlayerDetection2
@onready var hitbox: Hitbox = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

var _curr_running_speed: float
var _next_time: int
var _direction_walk: float = 1.0
var _should_try_chase: bool = false
var _health: int = 2
var _curr_state: STATE

enum STATE {
	IDLE,
	ROAM,
	CHASE,
	ATTACK,
}

func _ready() -> void:
	player_detection_chase.set_response_enter(_found_player, false)
	player_detection_chase.set_response_exit(_lost_player, false)
	
	player_detection_attack.set_response_enter(_player_entered_attack_range, false)
	
	hitbox.ingone_RIDS = [$Hurtbox.get_rid()]
	
	_change_state(STATE.IDLE)

func _physics_process(delta: float) -> void:
	match _curr_state:
		STATE.IDLE:
			_idle()
		STATE.ROAM:
			_roam(delta)
		STATE.CHASE:
			_chase(delta)
	
	move_and_slide()

func _change_state(new: STATE) -> void:
	match new:
		STATE.IDLE:
			_idle_enter()
		STATE.ROAM:
			_roam_enter()
		STATE.CHASE:
			_chase_enter()
		STATE.ATTACK:
			_attack_enter()
	
	_curr_state = new

func _idle_enter() -> void:
	_next_time = Time.get_ticks_msec() + randi_range(800, 1200)
	velocity = Vector2.ZERO
	animation_player.play("idle")

func _idle() -> void:
	if !is_on_floor():
		velocity.y += Global.gravity
	
	if Time.get_ticks_msec() > _next_time:
		if _curr_state != STATE.CHASE:
			_change_state(STATE.ROAM)

func _roam_enter() -> void:
	_next_time = Time.get_ticks_msec() + randi_range(900, 1300)
	_direction_walk = [-1.0, 1.0].pick_random()
	sprite_2d.flip_h = _direction_walk == -1.0
	_set_flip_collision(sprite_2d.flip_h)
	animation_player.play("walk")

func _roam(delta: float) -> void:
	if !is_on_floor():
		velocity.y += Global.gravity
	
	if is_on_wall():
		_next_time = Time.get_ticks_msec() + randi_range(700, 1000)
		_direction_walk *= -1.0
		sprite_2d.flip_h = !sprite_2d.flip_h
		_set_flip_collision(sprite_2d.flip_h)
	elif Time.get_ticks_msec() > _next_time:
		if _curr_state != STATE.CHASE:
			_change_state(STATE.IDLE)
		return
	
	velocity.x = _walk_speed * _direction_walk * delta

func _chase_enter() -> void:
	_next_time = Time.get_ticks_msec() + randi_range(2000, 3000)
	player_detection_attack.activate()
	_curr_running_speed = 0
	animation_player.play("walk")

func _chase(delta: float) -> void:
	if Time.get_ticks_msec() > _next_time and !_should_try_chase:
		player_detection_attack.deactivate()
		_change_state(STATE.IDLE)
		return
	
	if Global.player_node:
		var vector_to_player: Vector2 = Global.player_node.global_position - global_position
		var angle: float = abs(rad_to_deg(vector_to_player.angle()))
		
		const max_angle: float = 25
		if angle <= max_angle or angle >= (180.0 - max_angle):
			var new_dir: float = sign(vector_to_player.x)
			if new_dir != _direction_walk and new_dir != 0.0:
				_direction_walk = new_dir
				sprite_2d.flip_h = new_dir == -1
				_set_flip_collision(sprite_2d.flip_h)
	
	if is_on_wall():
		#TODO: bonk
		player_detection_attack.deactivate()
		_change_state(STATE.IDLE)
		return
	
	_curr_running_speed += _run_accel
	
	velocity.x = min(_curr_running_speed, _run_speed_max) * _direction_walk * delta

func _attack_enter() -> void:
	animation_player.play("attack")
	velocity = Vector2.ZERO
	animation_player.animation_finished.connect(_attack_end, CONNECT_ONE_SHOT)

func _attack_end(_s: String) -> void:
	if player_detection_attack.is_player_inside():
		_change_state(STATE.ATTACK)
	elif _should_try_chase:
		_change_state(STATE.CHASE)
	else:
		_change_state(STATE.IDLE)

func _found_player() -> void:
	_should_try_chase = true
	if _curr_state != STATE.ATTACK:
		_change_state(STATE.CHASE)

func _lost_player() -> void:
	_should_try_chase = false

func _player_entered_attack_range() -> void:
	if _curr_state != STATE.ATTACK:
		_change_state(STATE.ATTACK)

func _set_flip_collision(flip: bool) -> void:
	if flip:
		hitbox.scale.x = -1.0
		player_detection_chase.scale.x = -1.0
		player_detection_attack.scale.x = -1.0
	else:
		hitbox.scale.x = 1.0
		player_detection_chase.scale.x = 1.0
		player_detection_attack.scale.x = 1.0

func _on_hurtbox_hit(_damage: float) -> void:
	_health -= 1
	if _health <= 0:
		_die()

func _die() -> void:
	queue_free()
