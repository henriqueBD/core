class_name PlayerDetection
extends Area2D

var response: Callable
var one_shot: bool

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("Player"):
		response.call()
		if one_shot: 
			queue_free()
