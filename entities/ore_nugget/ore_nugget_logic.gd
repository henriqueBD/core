extends AnimatedSprite2D

var _is_getting_hit: bool = false
var _health: int = 3

func _ready() -> void:
	$PlayerDetection.deactivate()

func _on_hurtbox_hit(_damage: float) -> void:
	if _is_getting_hit: return
	_is_getting_hit = true
	_health -= 1
	if _health == 0:
		play("break")
		animation_finished.connect(_end_break, CONNECT_ONE_SHOT)
	else:
		play("hit")
		animation_finished.connect(_end_hit, CONNECT_ONE_SHOT)

func _end_hit() -> void:
	_is_getting_hit = false

func _end_break() -> void:
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.activate()
	player_detection.set_response_enter(_on_player_pick_up, true)

func _on_player_pick_up() -> void:
	Global.chunks.set_no_respawn(global_position)
	queue_free()
