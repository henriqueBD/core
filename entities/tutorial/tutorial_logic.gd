extends Sprite2D

const SPEED: float = 10

func _ready() -> void:
	hide()
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_player_entered_pickup_area, false)
	player_detection.set_response_exit(_player_exited_pickup_area, false)
	set_process_input(false)

func _player_entered_pickup_area() -> void:
	visible = true
	set_physics_process(true)

func _player_exited_pickup_area() -> void:
	visible = false
