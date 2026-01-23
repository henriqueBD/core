extends Sprite2D

const SPEED: float = 10

@export var one_shot: bool = false

func _ready() -> void:
	hide()
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_player_entered_pickup_area, false)
	player_detection.set_response_exit(_player_exited_pickup_area, false)

func _player_entered_pickup_area() -> void:
	visible = true

func _player_exited_pickup_area() -> void:
	visible = false
	if one_shot:
		Global.chunks.set_no_respawn(global_position)
		queue_free()
