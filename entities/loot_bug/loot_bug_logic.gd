extends CharacterBody2D

@export var _move_speed: float

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var dynamic_obj_tracker: DynamicObjTracker = $DynamicObjTracker
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

static var _regular_sprite: Texture2D = load("res://entities/loot_bug/loot_bug.png")
static var _squished_sprite: Texture2D = load("res://entities/loot_bug/loot_bug_squished.png")

var _gravity: float
var _direction: float = 1.0
var _is_exploding: bool = false

func _ready() -> void:
	_gravity = Global.gravity
	dynamic_obj_tracker.define_bounds(Rect2(global_position, Vector2(1,1)))
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_player_stepped, false)
	player_detection.set_response_exit(_player_left, false)

func _on_hit(_damage: float) -> void:
	if _is_exploding: return
	
	_is_exploding = true
	sprite_2d.hide()
	set_physics_process(false)
	animated_sprite_2d.play("explode")
	animated_sprite_2d.animation_finished.connect(_explode_end, CONNECT_ONE_SHOT)

func _explode_end() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	
	if !is_on_floor():
		velocity.y += _gravity * delta
	
	if is_on_wall():
		_direction *= -1.0
		if _direction == -1.0:
			sprite_2d.flip_h = true
			animated_sprite_2d.flip_h = true
		else:
			sprite_2d.flip_h = false
			animated_sprite_2d.flip_h = false
	
	velocity.x = _direction * _move_speed
	
	move_and_slide()

func _player_stepped() -> void:
	sprite_2d.texture = _squished_sprite

func _player_left() -> void:
	sprite_2d.texture = _regular_sprite
