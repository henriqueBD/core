extends AnimatedSprite2D

static var _break_mask: BitMap = TerrainBreaker.create_bitmap("res://entities/exploding_rock/exploding_rock_mask.png")
var _terrain_breaker: TerrainBreaker = TerrainBreaker.init([_break_mask], 3, false, 0)

func on_hit(_damage: float) -> void:
	play("explode")
	animation_finished.connect(_on_explode_finish)

func _on_explode_finish() -> void:
	_terrain_breaker.break_terrain(_terrain_breaker.center_to_top_left(global_position))
	queue_free()
