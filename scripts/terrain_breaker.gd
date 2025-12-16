class_name TerrainBreaker
extends Object

var _force: int
var _last_break: Vector2
var _distance_tolerance_squared: int
var _mask: BitMap

static func create_bitmap(image_path: String) -> BitMap:
	var res: BitMap = BitMap.new()
	res.create_from_image_alpha(Image.load_from_file(image_path))
	return res

func set_parameters(force: int, mask: BitMap, distance_tolerance: int = 1) -> void:
	_force = force
	_mask = mask
	_distance_tolerance_squared = max(distance_tolerance, 1) ^ 2

func break_terrain(global_coords: Vector2) -> void:
	if global_coords.distance_squared_to(_last_break) < _distance_tolerance_squared: return
	_last_break = global_coords
	Global.chunks.break_tiles_mask(global_coords, _mask, _force)
