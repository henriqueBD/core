extends Camera2D

@export var y_offset: float
@export var x_offset: float
@export_range(0, 1, 0.025) var motion_ease_walk: float
@export_range(0, 0.3, 0.001) var motion_ease_turn: float

var _player: player_character

var global_position_center: Vector2
var local_offset_x: float = 0

func _ready() -> void:
	_player = Global.player_node
	if !_player:
		printerr("Player not found")
		return
	global_position_center = _player.global_position

func _process(_delta: float) -> void:
	var target_position_centered: Vector2 = _player.global_position + Vector2(0, y_offset)
	
	global_position_center = lerp(global_position_center, target_position_centered, motion_ease_walk)
	local_offset_x = lerp(local_offset_x, _player.is_looking_foward() * x_offset, motion_ease_turn)
	
	global_position = Vector2(global_position_center.x + local_offset_x, global_position_center.y)
