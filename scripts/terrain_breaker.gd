class_name TerrainBreaker
extends Object

var force: int
var distance_tolerance_squared: int

var _last_break: Vector2
var _mask_variations_original: Array[BitMap]
var _mask_variations_flip_x: Array[BitMap]
var _mask_original: BitMap
var _mask_flip_x: BitMap
var _size: Vector2

static func create_bitmap(image_path: String) -> BitMap:
	var res: BitMap = BitMap.new()
	res.create_from_image_alpha(load(image_path) as Image)
	return res

static func create_bitmap_variations(image_path: String, columns: int) -> Array[BitMap]:
	var res: Array[BitMap] = []
	
	var sheet: Image = load(image_path) as Image
	if not sheet:
		printerr("Failed to load image at: ", image_path)
		return []
		
	var sheet_size: Vector2i = sheet.get_size()
	var cell_W: int = sheet_size.x / columns
	
	if cell_W * columns != sheet_size.x:
		printerr("Sprite sheet width is not divisible by ", columns)
		return []
	
	res.resize(columns)
	
	var sheet_rect: Rect2i = Rect2i(0, 0, cell_W, sheet_size.y)
	
	for i: int in range(columns):
		var bitmap: BitMap = BitMap.new()
		var region: Image = sheet.get_region(sheet_rect)
		bitmap.create_from_image_alpha(region)
		res[i] = bitmap
		sheet_rect.position.x += cell_W
	
	return res

static func init(bit_maps: Array[BitMap], break_force: int, create_flip_versions: bool, tolerance_distance_px: int) -> TerrainBreaker:
	var res: TerrainBreaker = TerrainBreaker.new()
	
	res.force = break_force
	res.distance_tolerance_squared = max(tolerance_distance_px * tolerance_distance_px, 1)
	res._mask_original = bit_maps[0]
	res._size = bit_maps[0].get_size()
	
	if bit_maps.size() > 1:
		res._mask_variations_original = bit_maps
	
	if create_flip_versions:
		var size_cell: Vector2i = bit_maps[0].get_size()
		var flipped_bit_maks: Array[BitMap]
		flipped_bit_maks.resize(bit_maps.size())
		for i: int in range(bit_maps.size()):
			var original: BitMap = bit_maps[i]
			var flipped: BitMap = BitMap.new()
			flipped.create(size_cell)
			for y: int in range(size_cell.y):
				for x: int in range(size_cell.x):
					var bit: bool = original.get_bit(x, y)
					flipped.set_bit(size_cell.x - 1 - x, y, bit)
			flipped_bit_maks[i] = flipped
		res._mask_flip_x = flipped_bit_maks[0]
		res._mask_variations_flip_x = flipped_bit_maks
	
	return res

func set_parameters(break_force: int, mask: BitMap, distance_tolerance: int = 1) -> void:
	force = break_force
	_mask_original = mask
	distance_tolerance_squared = max(distance_tolerance * distance_tolerance, 1)

func eval_area(global_top_left: Vector2) -> Vector2:
	return Global.chunks.eval_area_mask(global_top_left, _mask_original, force)

func eval_area_override_force(global_top_left: Vector2, eval_force: int) -> Vector2:
	return Global.chunks.eval_area_mask(global_top_left, _mask_original, eval_force)

func eval_break_area(global_top_left: Vector2, eval_force: int, callback: Callable) -> void:
	Global.chunks.eval_break_area_mask(global_top_left, _mask_original, force, eval_force, callback)

func request_eval() -> void:
	pass

#region break terrain

func break_terrain(global_coords_top_left: Vector2) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	Global.chunks.break_tiles_mask(global_coords_top_left, _mask_original, force)

func break_terrain_random(global_coords_top_left: Vector2) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	Global.chunks.break_tiles_mask(global_coords_top_left, _mask_variations_original.pick_random(), force)

func break_terrain_flip_x(global_coords_top_left: Vector2, flip_x: bool) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	if flip_x:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_flip_x, force)
	else:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_original, force)

func break_terrain_flip_x_random(global_coords_top_left: Vector2, flip_x: bool) -> void:
	if global_coords_top_left.distance_squared_to(_last_break) < distance_tolerance_squared: return
	_last_break = global_coords_top_left
	if flip_x:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_variations_flip_x.pick_random(), force)
	else:
		Global.chunks.break_tiles_mask(global_coords_top_left, _mask_variations_original.pick_random(), force)

#endregion

#region coordinate conversion

func center_to_top_left(global_center: Vector2) -> Vector2:
	return global_center - (_size / 2)

func top_right_to_top_left(top_right: Vector2) -> Vector2:
	return top_right - Vector2(_size.x, 0)

func bottom_right_to_top_left(bottom_right: Vector2) -> Vector2:
	return bottom_right - _size

func bottom_left_to_top_left(bottom_left: Vector2) -> Vector2:
	return bottom_left - Vector2(0, _size.y)

#endregion
