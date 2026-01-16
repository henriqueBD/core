extends CharacterBody2D

@export var _walk_speed: float = 50

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

var player: player_character

var _next_roam: int
var _direction_walk: float

enum states {
	ROAM,
	ATTACK,
}

func _ready() -> void:
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_found_player, false)
	animation_player.play("walk")

func _physics_process(delta: float) -> void:
	_roam(delta)
	move_and_slide()

func _roam(delta: float) -> void:
	if is_on_wall():
		_next_roam = Time.get_ticks_msec() + randi_range(800, 1200)
		_direction_walk *= -1.0
		sprite_2d.flip_h = !sprite_2d.flip_h
	elif Time.get_ticks_msec() > _next_roam:
		_next_roam = Time.get_ticks_msec() + randi_range(800, 1200)
		_direction_walk = [-1.0, 1.0].pick_random()
		sprite_2d.flip_h = _direction_walk == -1.0
	
	velocity.x = _walk_speed * _direction_walk * delta

func _found_player() -> void:
	print("uuuuu")
