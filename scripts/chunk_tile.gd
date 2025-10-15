class_name chunk_tile
extends Sprite2D

var img: Image
var tex: ImageTexture
var coords: Vector2i = Vector2i(0,0)
var data: PackedByteArray
var _tile_sprites: Array[Image]

var entities: obj_chunk

var _chunks_loaded: Dictionary[Vector2i, chunk_tile]

#const chunk_shader: Shader = preload("res://terrain_shader.gdshader")

enum TILE_TYPE { AIR, DIRT, STONE, GOLD_PURE, CLOVIUM }

enum TILE_POS { CENTER, TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT }

const TILE_DURABILITY: PackedByteArray = [
	0, # AIR
	1, # DIRT
	2, # STONE
	1, # GOLD_PURE
	1, # CLOVIUM
]

var edge_colors: Array[Color] = [
	Color.from_rgba8(0, 0, 0, 0),
	Color.from_rgba8(122, 71, 53),
	Color.from_rgba8(91, 109, 109),
	Color.from_rgba8(255, 254, 161),
	Color.from_rgba8(153, 76, 204)
]

func initialize(c: Vector2i, sprite_array: Array[Image], dict_chunks: Dictionary[Vector2i, chunk_tile], data_empty: PackedByteArray = []) -> obj_chunk:
	_chunks_loaded = dict_chunks
	_tile_sprites = sprite_array
	coords = c
	
	if len(data_empty) == 0:
		data = decompress_chunk(getBytes())
	else:
		data = decompress_chunk(data_empty)
	
	if data.size() == 0:
		print("oops")
		return null
	
	self.position.x += c.x * Global.CHUNK_SIDE
	self.position.y += c.y * Global.CHUNK_SIDE
	
	img = Image.create_empty(Global.CHUNK_SIDE, Global.CHUNK_SIDE, false, Image.FORMAT_RGBA8)
	
	for i: int in range(data.size()):
		var grid_img_coords: Vector2i = Vector2i(i % Global.CHUNK_SIDE, i / Global.CHUNK_SIDE)
		if data[i] == TILE_TYPE.AIR: 
			img.set_pixelv(grid_img_coords, edge_colors[0])
			continue
		if !_has_same_neighborsv(grid_img_coords):
			img.set_pixelv(grid_img_coords, edge_colors[data[i]])
		else:
			img.set_pixelv(
				grid_img_coords, 
				_tile_sprites[data[i]].get_pixelv(Vector2i((grid_img_coords)) % _tile_sprites[data[i]].get_size())
			)
	
	tex = ImageTexture.create_from_image(img)
	self.texture = tex
	
	# Load entities
	entities = obj_chunk.new()
	var path: String = "res://entities_map/" + str(coords.x) + "-" + str(coords.y) + ".res"
	if FileAccess.file_exists(path):
		return ResourceLoader.load(path)
	else:
		return null

func getBytes() -> PackedByteArray:
	var targetName: String = chunk_mng.get_chunk_path(coords)
	var file: FileAccess = FileAccess.open(targetName, FileAccess.READ)
	if file:
		var size: int = file.get_length()
		var dataTmp: PackedByteArray = file.get_buffer(size)
		file.close()
		return dataTmp
	else:
		print("Failed to open file:", name)
		return []

func fix_borders() -> void:
	const max_grid: int = Global.CHUNK_SIDE - 1
	_terrain_really_changed = false
	
	_fix_borders_helper(Vector2i(0,0))
	_fix_borders_helper(Vector2i(0,max_grid))
	_fix_borders_helper(Vector2i(max_grid,0))
	_fix_borders_helper(Vector2i(max_grid,max_grid))
	for i: int in range(1, max_grid):
		_fix_borders_helper(Vector2i(i,0))
		_fix_borders_helper(Vector2i(i,max_grid))
		_fix_borders_helper(Vector2i(0,i))
		_fix_borders_helper(Vector2i(max_grid,i))
	
	if _terrain_really_changed:
		tex.update(img)
		changed_terrain = true

func _fix_borders_helper(coord_tmp: Vector2i) -> void:
	assert(is_grid_pos_in_bounds(coord_tmp))
	var target_type: TILE_TYPE = _get_tilev(coord_tmp)
	if target_type == TILE_TYPE.AIR: return
	if !_has_same_neighborsv(coord_tmp) and img.get_pixelv(coord_tmp) != edge_colors[target_type]:
		_terrain_really_changed = true
		img.set_pixelv(coord_tmp, edge_colors[target_type])
	elif img.get_pixelv(coord_tmp) == edge_colors[target_type]:
		_terrain_really_changed = true
		img.set_pixelv(
			coord_tmp, 
			_tile_sprites[target_type].get_pixelv(Vector2i((coord_tmp)) % _tile_sprites[target_type].get_size())
		)

func _has_same_neighborsv(coord_check: Vector2i) -> bool:
	return _has_same_neighbors(coord_check.x, coord_check.y)

func _has_same_neighbors(x_check: int, y_check: int) -> bool:
	var type_check: TILE_TYPE = _get_tile(x_check, y_check)
	return (
		_get_tile_safe(x_check + 1, y_check) == type_check and 
		_get_tile_safe(x_check - 1, y_check) == type_check and
		_get_tile_safe(x_check, y_check + 1) == type_check and
		_get_tile_safe(x_check, y_check - 1) == type_check
	)

func decompress_chunk(compressed_data: PackedByteArray) -> PackedByteArray:
	var decompressed_data: PackedByteArray = PackedByteArray()
	
	const REPEAT_BYTE_MARKER: int = 255
	
	var data_size: int = (compressed_data[1] << 8) | compressed_data[0]
	var i: int = 2
	#var i: int = 0
	while i < data_size:
	#while decompressed_data.size() < Global.CHUNK_SIDE * Global.CHUNK_SIDE:
		var current_byte: int = compressed_data[i]

		if current_byte == REPEAT_BYTE_MARKER:
			# Ensure there are enough bytes for a full sequence (marker, value, count_low, count_high).
			if i + 3 >= compressed_data.size():
				# This indicates corrupted or incomplete data.
				# You might want to handle this error more gracefully.
				push_error("Incomplete compressed sequence found at index %d" % i)
				break

			var byte_to_repeat: int = compressed_data[i + 1]
			
			# Reconstruct the 16-bit streak count from two bytes.
			var low_byte: int = compressed_data[i + 2]
			var high_byte: int = compressed_data[i + 3]
			var streak: int = (high_byte << 8) | low_byte

			# Append the repeated byte 'streak' number of times.
			for _j: int in range(streak):
				decompressed_data.append(byte_to_repeat)
			
			# Move the index past the entire 4-byte sequence.
			i += 4
		else:
			# If it's not a marker, it's a literal byte.
			decompressed_data.append(current_byte)
			i += 1
			
	return decompressed_data

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(world_pos)
	return Vector2i(floor(local_pos.x), floor(local_pos.y))

func grid_to_world(grid_pos: Vector2i, tile_pos: TILE_POS) -> Vector2:
	var world_pos: Vector2 = Vector2(grid_pos)
	
	match tile_pos:
		TILE_POS.CENTER:
			world_pos += Vector2(0.5, 0.5)
		TILE_POS.TOP:
			world_pos += Vector2(0.5, 0.0)
		TILE_POS.BOTTOM:
			world_pos += Vector2(0.5, 1.0)
		TILE_POS.LEFT:
			world_pos += Vector2(0.0, 0.5)
		TILE_POS.RIGHT:
			world_pos += Vector2(1.0, 0.5)
		TILE_POS.TOP_LEFT:
			world_pos += Vector2(0.0, 1.0)
	
	return to_global(world_pos)

func is_grid_pos_in_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < Global.CHUNK_SIDE and grid_pos.y >= 0 and grid_pos.y < Global.CHUNK_SIDE

func is_gridInt_pos_in_bounds(x_grid: int, y_grid: int) -> bool:
	return x_grid >= 0 and x_grid < Global.CHUNK_SIDE and y_grid >= 0 and y_grid < Global.CHUNK_SIDE

func _set_tile(grid_x: int, grid_y: int, tile_type: TILE_TYPE) -> void:
	data[grid_y * Global.CHUNK_SIDE + grid_x] = tile_type

func _set_tilev(grid_pos: Vector2i, tile_type: TILE_TYPE) -> void:
	data[grid_pos.y * Global.CHUNK_SIDE + grid_pos.x] = tile_type

func _get_tile(x: int, y: int) -> TILE_TYPE:
	return data[y * Global.CHUNK_SIDE + x]

func _get_tilev(xy: Vector2i) -> TILE_TYPE:
	return data[xy.y * Global.CHUNK_SIDE + xy.x]

func _get_tile_safe(x: int, y: int) -> TILE_TYPE:
	if x < 0 or x >= Global.CHUNK_SIDE or y < 0 or y >= Global.CHUNK_SIDE:
		var global_coords: Vector2i = to_global(Vector2(x, y))
		var key: Vector2i = Vector2i(global_coords.x / Global.CHUNK_SIDE , global_coords.y / Global.CHUNK_SIDE)
		if !_chunks_loaded.has(key): return 0
		var chunk_search: chunk_tile = _chunks_loaded[key]
		return chunk_search._get_tilev(chunk_search.world_to_grid(global_coords))
	else: return _get_tile(x, y)

#region Terrain changes

var _terrain_really_changed: bool

func _change_single_tile(gridPos: Vector2i, new_type: TILE_TYPE) -> void:
	if _get_tilev(gridPos) == new_type and img.get_pixelv(gridPos) != edge_colors[new_type]:
		return
	_terrain_really_changed = true
	_set_tilev(gridPos, new_type)
	if new_type == TILE_TYPE.AIR:
		img.set_pixelv(gridPos, edge_colors[0])
	else: img.set_pixelv(
		gridPos, 
		_tile_sprites[new_type].get_pixelv(Vector2i((gridPos)) % _tile_sprites[new_type].get_size())
	)

func _recalculate_area(recalculate_rect: Rect2) -> void:
	recalculate_rect = recalculate_rect.grow(1)
	
	var grid_pos_start: Vector2i = world_to_grid(recalculate_rect.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(recalculate_rect.position + recalculate_rect.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			if _get_tile(x_pos, y_pos) == TILE_TYPE.AIR: continue
			if !_has_same_neighbors(x_pos, y_pos):
				img.set_pixel(x_pos, y_pos, edge_colors[_get_tile(x_pos, y_pos)])

func change_tiles(destroy_rect_world: Rect2, new_type: TILE_TYPE) -> void:
	_terrain_really_changed = false
	
	var grid_pos_start: Vector2i = world_to_grid(destroy_rect_world.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(destroy_rect_world.position + destroy_rect_world.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			_change_single_tile(Vector2i(x_pos, y_pos), new_type)
	
	if _terrain_really_changed:
		_recalculate_area(destroy_rect_world)
		tex.update(img)
		changed_terrain = true

func break_tiles(destroy_rect_world: Rect2, mining_force: int) -> void:
	_terrain_really_changed = false
	
	var grid_pos_start: Vector2i = world_to_grid(destroy_rect_world.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(destroy_rect_world.position + destroy_rect_world.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			var tile_to_break: TILE_TYPE = _get_tile(x_pos, y_pos)
			if tile_to_break == TILE_TYPE.AIR or TILE_DURABILITY[tile_to_break] > mining_force:
				continue
			_terrain_really_changed = true
			_set_tile(x_pos, y_pos, TILE_TYPE.AIR)
			img.set_pixel(x_pos, y_pos, Color.from_rgba8(0, 0, 0, 0))
	
	if _terrain_really_changed:
		_recalculate_area(destroy_rect_world)
		tex.update(img)
		changed_terrain = true

#returns a data Vector2
#X: the angle of the general direction of the tiles different that AIR in relation to the rect center,
#	if no tiles returns NAN
#Y: the angle of the general direction of the tiles that cannot be broken with the mining_force in relation to the rect center,
#	if no tiles returns NAN
func eval_area(global_rect: Rect2, mining_force: int) -> Vector2:
	var tiles_dir: Vector2 = Vector2.ZERO
	var stronger_tiles_dir: Vector2 = Vector2.ZERO
	
	var grid_pos_start: Vector2i = world_to_grid(global_rect.position)
	var grid_pos_end: Vector2i = world_to_grid(global_rect.position + global_rect.size)
	var rect_center: Vector2 = (grid_pos_start + grid_pos_end) / 2.0
	
	var tile_tmp: TILE_TYPE
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			tile_tmp = _get_tile_safe(x_pos, y_pos)
			if tile_tmp != TILE_TYPE.AIR:
				tiles_dir += Vector2(x_pos, y_pos) - rect_center
				if TILE_DURABILITY[int(tile_tmp)] > mining_force:
					stronger_tiles_dir += Vector2(x_pos, y_pos) - rect_center
	
	return Vector2(
		NAN if tiles_dir == Vector2.ZERO else tiles_dir.angle(), 
		NAN if stronger_tiles_dir == Vector2.ZERO else stronger_tiles_dir.angle())

#endregion

#region Ray Cast

const ignoreTile: TILE_TYPE = TILE_TYPE.AIR
const no_collision: float = -INF
	
func rayCastDown(world_pos: Vector2, dist: int , down_chunk_tiles: chunk_tile) -> float:
	var grid_pos: Vector2i = world_to_grid(world_pos)
	var x_check: int = grid_pos.x
	for y: int in range(floori(grid_pos.y), floori(grid_pos.y) + dist + 1):
		if _get_tile_safe(x_check, y) != ignoreTile:
			return grid_to_world(Vector2i(x_check, y), TILE_POS.TOP).y
	return no_collision

func rayCastUp(world_pos: Vector2, dist: int, up_chunk_tiles: chunk_tile) -> float:
	var grid_pos: Vector2i = world_to_grid(world_pos)
	var x_check: int = grid_pos.x
	for y: int in range(floori(grid_pos.y), floori(grid_pos.y) - dist - 1, -1):
		if _get_tile_safe(x_check, y) != ignoreTile:
			return grid_to_world(Vector2i(x_check, y), TILE_POS.BOTTOM).y
	return no_collision

func rayCastLeft(world_pos: Vector2, dist: int, left_chunk_tiles: chunk_tile) -> float:
	var grid_pos: Vector2i = world_to_grid(world_pos)
	var y_check: int = grid_pos.y
	for x: int in range(grid_pos.x, grid_pos.x - dist, -1):
		if _get_tile_safe(x, y_check) != ignoreTile:
			return grid_to_world(Vector2(x, y_check), TILE_POS.RIGHT).x
	return no_collision

func rayCastRight(world_pos: Vector2, dist: int, right_chunk_tiles: chunk_tile) -> float:
	var grid_pos: Vector2i = world_to_grid(world_pos)
	var y_check: int = grid_pos.y
	for x: int in range(grid_pos.x, grid_pos.x + dist):
		if _get_tile_safe(x, y_check) != ignoreTile:
			return grid_to_world(Vector2(x, y_check), TILE_POS.LEFT).x
	return no_collision

func ray_cast_general(world_start: Vector2, world_end: Vector2) -> float:
	var grid_start: Vector2i = world_to_grid(world_start)
	var grid_end: Vector2i = world_to_grid(world_end)
	
	var dx: int = abs(grid_end.x - grid_start.x)
	var dy: int = abs(grid_end.y - grid_start.y)
	
	var x: int = grid_start.x
	var y: int = grid_start.y
	
	var sx: int = 1 if grid_end.x > grid_start.x else -1
	var sy: int = 1 if grid_end.y > grid_start.y else -1
	
	var err: int = (dx if dx > dy else -dy) >> 1
	
	while true:
		if _get_tile_safe(x, y) != ignoreTile:
			# Wall hit — estimate world position at tile center
			var hit_pos: Vector2 = Vector2(x + 0.5, y + 0.5)
			return world_start.distance_to(hit_pos)
	
		if x == grid_end.x and y == grid_end.y:
			break
	
		var e2: int = err
		if e2 > -dx:
			err -= dy
			x += sx
		if e2 < dy:
			err += dx
			y += sy
	
	return no_collision

#endregion

#region editor

var areas: Array[Area2D]
var changed_entities: bool = false
var changed_terrain: bool = false

func editor_add_entity(entity: Area2D, entity_id: int) -> void:
	entity.position = self.to_local(entity.global_position)
	add_child(entity)
	areas.append(entity)
	entities.id.append(entity_id)
	entities.pos.append(entity.global_position)
	changed_entities = true

func editor_delete_entity(cursor_area: Area2D) -> void:
	var l: int = len(areas)
	for i: int in range(l):
		var area: Area2D = areas[i]
		if area.overlaps_area(cursor_area):
			print("Delete")
			remove_child(area)
			remove_swap(areas, i)
			remove_swap(entities.id, i)
			remove_swap(entities.pos, i)
			return
	changed_entities = true

func remove_swap(arr: Array, index: int) -> void:
	if index < 0 or index >= arr.size():
		push_error("Index out of bounds in remove_swap")
		return
	var last_index: int = arr.size() - 1
	if index != last_index:
		arr[index] = arr[last_index]
	arr.pop_back()

func _save_entities() -> void:
	if len(entities.id) > 0:
		ResourceSaver.save(entities, "res://entities_map/" + str(coords.x) + "-" + str(coords.y) + ".res")

func unload() -> void:
	if changed_entities:
		print("Saving chunk entities: " + str(coords))
		_save_entities()
	if changed_terrain:
		print("Saving chunk terrain: " + str(coords))
		_save_terrain()

func _save_terrain() -> void:
	var target_path: String = chunk_mng.get_chunk_path(coords)
	var file_to_save: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file_to_save:
		var compressed_data: PackedByteArray = compress_chunk()
		var data_len: int = compressed_data.size()
		var data_len_buffer: PackedByteArray = [0,0]
		data_len_buffer[0] = data_len & 0xFF
		data_len_buffer[1] = (data_len >> 8) & 0xFF
		file_to_save.store_buffer(data_len_buffer)
		file_to_save.store_buffer(compressed_data)
	else:
		print("Probem trying to save chunk " + str(coords))

func compress_chunk() -> PackedByteArray:
	const REPEAT_BYTE_MARKER: int = 255
	if data.size() > Global.CHUNK_SIZE:
		push_error("Chunk size %d exceeds maximum allowed size %d" % [data.size(), Global.CHUNK_SIZE])
		return PackedByteArray() # Return empty array on error
	
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(data.size())
	
	var buf_i: int = 0
	var i: int = 0
	var j: int = 0
	var chunk_len: int = data.size()
	
	while i < chunk_len:
		var curr_byte: int = data[i]
	
		j = i + 1
		while j < chunk_len and data[j] == curr_byte:
			j += 1
	
		var streak: int = j - i
		if streak < 4:
			for k: int in range(streak):
				buf[buf_i] = curr_byte
				buf_i += 1
		else:
			buf[buf_i] = REPEAT_BYTE_MARKER
			buf[buf_i + 1] = curr_byte
			buf[buf_i + 2] = streak & 0xFF
			buf[buf_i + 3] = (streak >> 8) & 0xFF
			buf_i += 4
	
		i = j
	
	return buf.slice(0, buf_i)

#endregion
