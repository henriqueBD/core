extends Node2D

func _ready() -> void:
	if Global.picked_pickaxe:
		_remove_pickaxe()
	else:
		var player_detection: PlayerDetection = $PlayerDetection
		player_detection.set_response_enter(_player_entered_pickup_area, false)
		player_detection.set_response_exit(_player_exited_pickup_area, false)
		set_process_input(false)

func _player_entered_pickup_area() -> void:
	set_process_input(true)

func _player_exited_pickup_area() -> void:
	set_process_input(false)

func _input(event: InputEvent) -> void:
	if !event.is_action("interact"): return
	
	Global.picked_pickaxe = true
	_remove_pickaxe()

func _remove_pickaxe() -> void:
	$Pickaxe.queue_free()
	$PlayerDetection.queue_free()
