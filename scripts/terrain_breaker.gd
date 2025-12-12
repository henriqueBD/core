class_name Terrain_breaker
extends Object

var _force: int
var _last_break: Vector2
var _distance_tolerance_squared: int
var _mask: Image

func set_parameters(force: int, mask: Image, distance_tolerance: int = 1) -> void:
	_force = force
	_mask = mask
	_distance_tolerance_squared = max(distance_tolerance, 1) ^ 2

func break_terrain(global_coords: Vector2) -> void:
	if global_coords.distance_squared_to(_last_break) < _distance_tolerance_squared: return
	_last_break = global_coords
	Global.chunks.break_tiles_mask(global_coords, _mask, _force)
