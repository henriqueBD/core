class_name PlayerDetection
extends Area2D

var _response_enter: Callable
var _response_exit: Callable
var _one_shot_enter: bool
var _one_shot_exit: bool

func set_response_enter(fn: Callable, is_one_shot: bool) -> void:
	area_entered.connect(_on_area_entered)
	_response_enter = fn
	_one_shot_enter = is_one_shot

func set_response_exit(fn: Callable, is_one_shot: bool) -> void:
	area_exited.connect(_on_area_exit)
	_response_exit = fn
	_one_shot_exit = is_one_shot

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		_response_enter.call()
		if _one_shot_enter: 
			queue_free()

func _on_area_exit(area: Area2D) -> void:
	if area.is_in_group("Player"):
		_response_exit.call()
		if _one_shot_exit: 
			queue_free()

func deactivate() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func activate() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
