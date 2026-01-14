extends AnimatedSprite2D

static var _break_mask: BitMap = TerrainBreaker.create_bitmap("res://entities/exploding_rock/exploding_rock_mask.png")

var _terrain_breaker: TerrainBreaker = TerrainBreaker.init([_break_mask], 3, false, 0)
var _is_exploding: bool = false

func on_hit(_damage: float) -> void:
	if _is_exploding: return
	
	_is_exploding = true
	play("explode")
	animation_finished.connect(_on_explode_finish)

func _on_explode_finish() -> void:
	_terrain_breaker.break_terrain(_terrain_breaker.center_to_top_left(global_position))
	Global.chunks.set_no_respawn(global_position)
	$ExplosionRadius.hit_single_frame()
	queue_free()
