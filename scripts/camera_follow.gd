extends Camera2D

@onready var player: player_character = get_node("../Player")

func _process(_delta: float) -> void:
	if player:
		global_position = player.global_position
