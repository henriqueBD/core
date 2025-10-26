extends Area2D

const MAX_FALLING_SEC: float = 1.0

var timer_self_destroy: float = 0.0

@onready var player_detection: CollisionShape2D = $player_detection

func _ready() -> void:
	set_process(false)

func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.owner
	if !parent: return
	
	if parent == Global.player_node:
		_fall()

func _fall() -> void:
	print("falling")
	player_detection.queue_free()
	set_process(true)

#Falling logic
func _process(delta: float) -> void:
	timer_self_destroy += delta
	if timer_self_destroy > MAX_FALLING_SEC:
		_bye_bye()
	pass

func _bye_bye() -> void:
	queue_free()
