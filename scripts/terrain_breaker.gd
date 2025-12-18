class_name TerrainBreaker
extends Object

var force: int
var eval_force: int
var distance_tolerance_squared: int

var _last_break: Vector2
var _mask_original: BitMap
var _mask_flip_x: BitMap
var _size: Vector2

static func create_bitmap(image_path: String) -> BitMap:
	var res: BitMap = BitMap.new()
	res.create_from_image_alpha(Image.load_from_file(image_path))
	return res

static func init(image_path: String, break_force: int, tolerance_distance_px: int, create_flip_version: bool) -> TerrainBreaker:
	var res: TerrainBreaker = TerrainBreaker.new()
	res.force = break_force
	res.distance_tolerance_squared = max(tolerance_distance_px ^ 2, 1)
	
	var mask_image: Image = load(image_path) as Image
	if !mask_image:
		printerr("Error in loading image")
		return null
	
	var mask: BitMap = BitMap.new()
	mask.create_from_image_alpha(mask_image)
	res._size = mask.get_size() as Vector2
	res._mask_original = mask
	
	if create_flip_version:
		var mask_flip: BitMap = BitMap.new()
		mask_image.flip_x()
		mask_flip.create_from_image_alpha(mask_image)
		res._mask_flip_x = mask_flip
	
	return res

func set_parameters(break_force: int, mask: BitMap, distance_tolerance: int = 1) -> void:
	force = break_force
	_mask_original = mask
	distance_tolerance_squared = max(distance_tolerance ^ 2, 1)


func center_to_top_left(global_center: Vector2) -> Vector2:
	return global_center - _size

func eval_area(global_top_left: Vector2) -> Vector2:
	return Global.chunks.eval_area_mask(global_top_left, _mask_original, eval_force)

func break_terrain(global_coords_top_left: Vector2) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	Global.chunks.break_tiles_mask(global_coords_top_left, _mask_original, force)

func break_terrain_flip_x(global_coords_top_left: Vector2, flip_x: bool) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	if flip_x:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_flip_x, force)
	else:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_original, force)

func top_right_to_top_left(top_right: Vector2) -> Vector2:
	return top_right - Vector2(_size.x, 0)

func bottom_right_to_top_left(bottom_right: Vector2) -> Vector2:
	return bottom_right - _size

func bottom_left_to_top_left(bottom_left: Vector2) -> Vector2:
	return bottom_left - Vector2(0, _size.y)
