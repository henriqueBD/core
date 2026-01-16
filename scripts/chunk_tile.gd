@tool
class_name chunk_tile
extends Sprite2D

const MAX_SKIPS: int = 5
const EPSILON: float = 2.0

static var _tile_sprites: Array[Image]
static var _chunks_loaded: Dictionary[Vector2i, chunk_tile]

var img: Image
var _terrain_mask: BitMap
var _global_bounds: Rect2i
var tex: ImageTexture
var coords: Vector2i = Vector2i(0,0)
var data: PackedByteArray

var global_pos_cached: Vector2

var entities: obj_chunk

var _breaker_thread: Thread

var _collision_RID: RID
var _poligons_RID: Array[RID] = []

var _collision_mutex: Mutex = Mutex.new()
var _image_mutex: Mutex = Mutex.new()

var _scheduled_update: bool

enum TILE_TYPE { AIR, dirt, stone, gold, clovium, metal }

enum TILE_POS { CENTER, TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT }

static func get_entities_map(entities_cord: Vector2i) -> String:
	return "res://entities_map/%d-%d.dat" % [entities_cord.x, entities_cord.y]

func initialize(c: Vector2i, data_empty: PackedByteArray = []) -> obj_chunk:
	self.set_process(false)
	coords = c
	
	self.z_index = Globals.LAYER_CHUNK_TERRAIN
	
	if len(data_empty) == 0:
		data = decompress_chunk(get_bytes(c))
	else:
		data = decompress_chunk(data_empty)
	
	assert(data.size() == Globals.CHUNK_SIZE)
	
	position.x += c.x * Global.CHUNK_SIDE
	position.y += c.y * Global.CHUNK_SIDE
	
	img = Image.create_empty(Global.CHUNK_SIDE, Global.CHUNK_SIDE, false, Image.FORMAT_RGBA8)
	
	for i: int in range(data.size()):
		var grid_img_coords: Vector2i = Vector2i(i % Global.CHUNK_SIDE, i / Global.CHUNK_SIDE)
		if data[i] == TILE_TYPE.AIR: 
			img.set_pixelv(grid_img_coords, chunk_mng.tile_edge_colors[0])
			continue
		if !_has_same_neighborsv(grid_img_coords):
			img.set_pixelv(grid_img_coords, chunk_mng.tile_edge_colors[data[i]])
		else:
			img.set_pixelv(
				grid_img_coords, 
				_tile_sprites[data[i]].get_pixelv(Vector2i((grid_img_coords)) % _tile_sprites[data[i]].get_size())
			)
	
	tex = ImageTexture.create_from_image(img)
	texture = tex
	
	#_collision_RID = PhysicsServer2D.body_create()
	#_init_terrain_collision(_collision_RID)
	#_terrain_mask = get_terrain_mask_from_data(data)
	#_terrain_collision_update()
	
	# Load entities
	entities = obj_chunk.deserialize(c)
	return entities

func initialize_deffered(
	key: Vector2i, decompressed_data: PackedByteArray, 
	image: Image, collision: Array[CollisionPolygon2D], collision_mask: BitMap, 
	instances_static: Array[Node2D], instances_dynamic: Array[Node2D]) -> void:
	
	var sprite: ImageTexture = ImageTexture.create_from_image(image)
	call_deferred("_initialize_deffered_helper", key, decompressed_data, image, collision, collision_mask, sprite, instances_static, instances_dynamic)

func _initialize_deffered_helper(
	key: Vector2i, decompressed_data: PackedByteArray, image: Image, 
	collision: Array[CollisionPolygon2D], collision_mask: BitMap, 
	sprite: ImageTexture, instances_static: Array[Node2D], instances_dynamic: Array[Node2D]) -> void:
	
	set_process(false)
	
	_breaker_thread = Thread.new()
	
	z_index = Globals.LAYER_CHUNK_TERRAIN
	coords = key
	
	data = decompressed_data
	assert(data.size() == Globals.CHUNK_SIZE)
	
	entities = obj_chunk.new()
	global_position = Global.CHUNK_SIDE * key
	img = image
	tex = sprite
	texture = sprite
	
	_terrain_mask = collision_mask
	
	_collision_RID = _init_terrain_collision()
	_terrain_collision_update(_collision_RID)
	
	_global_bounds = Rect2i(
		self.coords * Globals.CHUNK_SIDE,
		Vector2i(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE)
	)
	
	_collision_RID = PhysicsServer2D.body_create()
	
	for obj: Node2D in instances_static:
		##Fix later
		self.add_child(obj)
		obj.owner = self
	
	for obj: Node2D in instances_dynamic:
		Global.main_node.add_child(obj)
	
	Global.chunk_load.emit(coords)

func _init_terrain_collision() -> RID:
	var res: RID = PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(res, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_space(res, get_world_2d().space)
	PhysicsServer2D.body_set_state(res, PhysicsServer2D.BODY_STATE_TRANSFORM, transform)
	PhysicsServer2D.body_set_collision_layer(res, 1)
	PhysicsServer2D.body_set_collision_mask(res, 1)
	return res

static func get_bytes(coords_tmp: Vector2i) -> PackedByteArray:
	var targetName: String = chunk_mng.get_chunk_path(coords_tmp)
	if FileAccess.file_exists(targetName):
		return FileAccess.get_file_as_bytes(targetName)
	else:
		printerr("Failed to get file " + targetName)
		return []

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

static func decompress_chunk(compressed_data: PackedByteArray) -> PackedByteArray:
	return compressed_data.decompress(Globals.CHUNK_SIZE, Globals.CHUNK_COMPRESSION_METHOD)

static func create_texture_from_terrain_data(terrain_data: PackedByteArray, mask: BitMap) -> Image:
	var terrain_img: Image = Image.create_empty(Global.CHUNK_SIDE, Global.CHUNK_SIDE, false, Image.FORMAT_RGBA8)
	
	if mask != null:
		for i: int in range(terrain_data.size()):
			var grid_img_coords: Vector2i = Vector2i(i % Global.CHUNK_SIDE, i / Global.CHUNK_SIDE)
			var curr_tile: int = terrain_data[i]
			if curr_tile == TILE_TYPE.AIR: 
				terrain_img.set_pixelv(grid_img_coords, chunk_mng.tile_edge_colors[0])
				continue
			if mask.get_bitv(grid_img_coords):
				terrain_img.set_pixelv(
					grid_img_coords, 
					_tile_sprites[curr_tile].get_pixelv(Vector2i((grid_img_coords)) % _tile_sprites[curr_tile].get_size())
				)
			else:
				terrain_img.set_pixelv(grid_img_coords, chunk_mng.tile_background_colors[curr_tile])
	else:
		for i: int in range(terrain_data.size()):
			var grid_img_coords: Vector2i = Vector2i(i % Global.CHUNK_SIDE, i / Global.CHUNK_SIDE)
			var curr_tile: int = terrain_data[i]
			if curr_tile == TILE_TYPE.AIR: 
				terrain_img.set_pixelv(grid_img_coords, chunk_mng.tile_edge_colors[0])
				continue
			terrain_img.set_pixelv(
				grid_img_coords, 
				_tile_sprites[curr_tile].get_pixelv(Vector2i((grid_img_coords)) % _tile_sprites[curr_tile].get_size())
			)
	
	return terrain_img

static func get_terrain_mask_from_data(terrain_data: PackedByteArray, previous_data: BitMap) -> BitMap:
	var res: BitMap = BitMap.new()
	res.create(Vector2i(Global.CHUNK_SIDE, Global.CHUNK_SIDE))
	
	if previous_data:
		for x: int in range(Globals.CHUNK_SIDE):
			for y: int in range(Globals.CHUNK_SIDE):
				res.set_bit(
					x, y, terrain_data[y * Global.CHUNK_SIDE + x] != TILE_TYPE.AIR and previous_data.get_bit(x, y)
				)
	else:
		for x: int in range(Globals.CHUNK_SIDE):
			for y: int in range(Globals.CHUNK_SIDE):
				res.set_bit(
					x, y, terrain_data[y * Global.CHUNK_SIDE + x] != TILE_TYPE.AIR
				)
	
	return res

static func get_terrain_collision(_terrain_data: BitMap) -> Array[CollisionPolygon2D]:
	return []
	#var res: Array[CollisionPolygon2D] = []
	#var vertices_arr: Array[PackedVector2Array] = terrain_data.opaque_to_polygons(Rect2i(Vector2i.ZERO, terrain_data.get_size()))
	#
	#for vertices: PackedVector2Array in vertices_arr:
		#var collision: CollisionPolygon2D = CollisionPolygon2D.new()
		#collision.polygon = vertices
		#res.append(collision)

func _terrain_collision_update(new_body: RID) -> void:
	var concave_array: Array[PackedVector2Array] = _terrain_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, _terrain_mask.get_size()), EPSILON)
	var new_convex_polys: Array[PackedVector2Array] = []

	for concave_poly: PackedVector2Array in concave_array:
		# Decompose into convex shapes
		var decomposed: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(concave_poly)
		new_convex_polys.append_array(decomposed)

	# 2. Locking (Optional but good practice if you access _poligons_RID elsewhere)
	_collision_mutex.lock()

	# 3. CLEANUP: Clear shapes from the body and free the old RIDs
	PhysicsServer2D.body_clear_shapes(_collision_RID)

	for old_rid: RID in _poligons_RID:
		PhysicsServer2D.free_rid(old_rid)
	_poligons_RID.clear()
	
	# 4. REBUILD: Create new RIDs and attach to body
	for poly: PackedVector2Array in new_convex_polys:
		var new_shape_rid: RID = PhysicsServer2D.convex_polygon_shape_create()
		PhysicsServer2D.shape_set_data(new_shape_rid, poly)
		PhysicsServer2D.body_add_shape(new_body, new_shape_rid)
		_poligons_RID.append(new_shape_rid)
	
	_collision_RID = new_body
	
	_collision_mutex.unlock()

func _create_new_physics_body_threaded() -> RID:
	# A. Math: Geometry Calculation
	var concave_array: Array[PackedVector2Array] = _terrain_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, _terrain_mask.get_size()), EPSILON)
	
	var new_body_rid: RID = _init_terrain_collision()
	
	# C. Physics Server: Create Shapes (Thread-safe)
	for concave_poly: PackedVector2Array in concave_array:
		# Decompose
		var convex_polys: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(concave_poly)
		
		# Create and add shapes immediately
		for poly: PackedVector2Array in convex_polys:
			var shape_rid: RID = PhysicsServer2D.convex_polygon_shape_create()
			PhysicsServer2D.shape_set_data(shape_rid, poly)
			PhysicsServer2D.body_add_shape(new_body_rid, shape_rid)
			
	return new_body_rid

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(world_pos)
	#var local_pos: Vector2 = global_pos_cached - world_pos
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

func _break_tile(grid_x: int, grid_y: int) -> void:
	data[grid_y * Global.CHUNK_SIDE + grid_x] = TILE_TYPE.AIR
	_terrain_mask.set_bit(grid_x, grid_y, false)

func _set_tilev(grid_pos: Vector2i, tile_type: TILE_TYPE) -> void:
	data[grid_pos.y * Global.CHUNK_SIDE + grid_pos.x] = tile_type

func _get_tile(x: int, y: int) -> TILE_TYPE:
	return data[y * Global.CHUNK_SIDE + x]

func _get_tilev(xy: Vector2i) -> TILE_TYPE:
	return data[xy.y * Global.CHUNK_SIDE + xy.x]

func _get_tile_safe(x: int, y: int) -> TILE_TYPE:
	if x < 0 or x >= Global.CHUNK_SIDE or y < 0 or y >= Global.CHUNK_SIDE:
		var global_coords: Vector2i = to_global(Vector2(x, y))
		#var key: Vector2i = Vector2i(global_coords.x / Global.CHUNK_SIDE , global_coords.y / Global.CHUNK_SIDE)
		var key: Vector2i = chunk_mng.world_to_chunk_key(global_coords)
		if !_chunks_loaded.has(key): return TILE_TYPE.AIR
		var chunk_search: chunk_tile = _chunks_loaded[key]
		return chunk_search._get_tilev(chunk_search.world_to_grid(global_coords))
	else: return _get_tile(x, y)

func _update_terrain_image() -> void:
	tex.update(img)

#region Terrain changes

var _terrain_really_changed: bool

func _recalculate_area(recalculate_rect_global: Rect2) -> void:
	recalculate_rect_global = recalculate_rect_global.grow(1)
	
	var grid_pos_start: Vector2i = world_to_grid(recalculate_rect_global.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(recalculate_rect_global.position + recalculate_rect_global.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			if _get_tile(x_pos, y_pos) == TILE_TYPE.AIR: continue
			if !_has_same_neighbors(x_pos, y_pos):
				img.set_pixel(x_pos, y_pos, chunk_mng.tile_edge_colors[_get_tile(x_pos, y_pos)])

func _recalculate_area_accurate(recalculate_rect_global: Rect2) -> void:
	recalculate_rect_global = recalculate_rect_global.grow(1)
	
	var grid_pos_start: Vector2i = world_to_grid(recalculate_rect_global.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(recalculate_rect_global.position + recalculate_rect_global.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			var tile: TILE_TYPE = _get_tile(x_pos, y_pos)
			if tile == TILE_TYPE.AIR: continue
			if !_has_same_neighbors(x_pos, y_pos):
				img.set_pixel(x_pos, y_pos, chunk_mng.tile_edge_colors[tile])
			else:
				img.set_pixel(
				x_pos, y_pos, 
				_tile_sprites[tile].get_pixelv(Vector2i(x_pos, y_pos) % _tile_sprites[tile].get_size())
				)
				

func get_terrain_image() -> Image:
	var image_res: Image = Image.create_empty(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE, false, Image.FORMAT_RGB8)
	for x: int in range(Globals.CHUNK_SIDE):
		for y: int in range(Globals.CHUNK_SIDE):
			image_res.set_pixel(x, y, chunk_mng.tile_edge_colors[_get_tile(x, y)])
	return image_res

static func get_terrain_image_static(terrain_data: PackedByteArray) -> Image:
	var image_res: Image = Image.create_empty(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE, false, Image.FORMAT_RGB8)
	for x: int in range(Globals.CHUNK_SIDE):
		for y: int in range(Globals.CHUNK_SIDE):
			image_res.set_pixel(x, y, chunk_mng.tile_edge_colors[terrain_data[y * Global.CHUNK_SIDE + x]])
	return image_res

func change_tiles(destroy_rect_world: Rect2, new_type: TILE_TYPE) -> void:
	var grid_pos_start: Vector2i = world_to_grid(destroy_rect_world.position)
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	var grid_pos_end: Vector2i = world_to_grid(destroy_rect_world.position + destroy_rect_world.size)
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			_set_tile(x_pos, y_pos, new_type)
	
	_recalculate_area_accurate(destroy_rect_world)
	tex.update(img)
	changed_terrain = true

#region multithread stuff

func break_tiles_mask(start: Vector2, mask: BitMap, mining_force: int, id: int) -> void:
	if _breaker_thread.is_started():
		_breaker_thread.wait_to_finish()
	
	var grid_pos_start: Vector2i = world_to_grid(start)
	var grid_pos_end: Vector2i = world_to_grid(start + Vector2(mask.get_size()))
	
	var new_body: RID = _init_terrain_collision()
	
	_breaker_thread.start(_break_tiles_mask_helper.bind(grid_pos_start, grid_pos_end, mask, mining_force, new_body, id))

func _break_tiles_mask_helper(grid_pos_start: Vector2i, grid_pos_end: Vector2i, mask: BitMap, mining_force: int, new_body: RID, id: int) -> void:
	_terrain_really_changed = false
	
	var image_origin_x: int = grid_pos_start.x
	var image_origin_y: int = grid_pos_start.y
	
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	#??
	grid_pos_end.x = min(grid_pos_end.x, image_origin_x + mask.get_size().x)
	grid_pos_end.y = min(grid_pos_end.y, image_origin_y + mask.get_size().y)
	
	_image_mutex.lock()
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			var tile_to_break: TILE_TYPE = _get_tile(x_pos, y_pos)
			
			if (!mask.get_bit(x_pos - image_origin_x, y_pos - image_origin_y) or
				tile_to_break == TILE_TYPE.AIR or 
				chunk_mng.tile_durability[tile_to_break] > mining_force):
				continue
				
			_terrain_really_changed = true
			_break_tile(x_pos, y_pos)
			img.set_pixel(x_pos, y_pos, chunk_mng.tile_background_colors[tile_to_break])
	_image_mutex.unlock()
	
	if _terrain_really_changed:
		_terrain_collision_update(new_body)
		_schedule_update()
		changed_terrain = true
	
	Global.chunks.break_tiles_post(id, _terrain_really_changed)

## Will break tiles and if it encounters a tile that it cannot break it calls callback(angle_radians: float)
func eval_break_tiles_mask(start: Vector2, mask: BitMap, mining_force: int, eval_force: int, id: int) -> void:
	if _breaker_thread.is_started():
		_breaker_thread.wait_to_finish()
	
	var grid_pos_start: Vector2i = world_to_grid(start)
	var grid_pos_end: Vector2i = world_to_grid(start + Vector2(mask.get_size()))
	
	var new_body: RID = _init_terrain_collision()
	
	_breaker_thread.start(eval_break_area_mask_helper.bind(grid_pos_start, grid_pos_end, mask, mining_force, eval_force, new_body, id))

func eval_break_area_mask_helper(
	grid_pos_start: Vector2i, grid_pos_end: Vector2i, mask: BitMap, 
	mining_force: int, eval_force: int, new_body: RID, id: int) -> void:
	
	var stronger_tiles_dir: Vector2 = Vector2.ZERO
	var rect_center: Vector2 = (grid_pos_start + grid_pos_end) / 2.0
	
	var image_origin_x: int = grid_pos_start.x
	var image_origin_y: int = grid_pos_start.y
	
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	#??
	grid_pos_end.x = min(grid_pos_end.x, image_origin_x + mask.get_size().x)
	grid_pos_end.y = min(grid_pos_end.y, image_origin_y + mask.get_size().y)
	
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			var tile_to_eval: TILE_TYPE = _get_tile(x_pos, y_pos)
			
			if (!mask.get_bit(x_pos - image_origin_x, y_pos - image_origin_y) or
				tile_to_eval == TILE_TYPE.AIR or 
				chunk_mng.tile_durability[tile_to_eval] > eval_force):
				continue
			
			stronger_tiles_dir += Vector2(x_pos, y_pos) - rect_center
	
	Global.chunks.eval_tiles_post(id, stronger_tiles_dir)
	_break_tiles_mask_helper(grid_pos_start, grid_pos_end, mask, mining_force, new_body, id + 1)

func _schedule_update() -> void:
	if _scheduled_update: return
	_scheduled_update = true
	_update_deffered.call_deferred()

func _update_deffered() -> void:
	_scheduled_update = false
	tex.update(img)

#endregion

#check chunks.eval area for more info
func eval_area(global_rect: Rect2, mining_force: int) -> Vector4:
	var tiles_dir: Vector2 = Vector2.ZERO
	var stronger_tiles_dir: Vector2 = Vector2.ZERO
	
	var grid_pos_start: Vector2i = world_to_grid(global_rect.position)
	var grid_pos_end: Vector2i = world_to_grid(global_rect.position + global_rect.size)
	var rect_center: Vector2 = (grid_pos_start + grid_pos_end) / 2.0
	
	grid_pos_start.x = max(0, grid_pos_start.x)
	grid_pos_start.y = max(0, grid_pos_start.y)
	
	grid_pos_end.x = min(Global.CHUNK_SIDE, grid_pos_end.x)
	grid_pos_end.y = min(Global.CHUNK_SIDE, grid_pos_end.y)
	
	#??
	grid_pos_end.x = min(grid_pos_end.x, grid_pos_start.x + global_rect.size.x)
	grid_pos_end.y = min(grid_pos_end.y, grid_pos_start.y + global_rect.size.y)
	
	
	var tile_tmp: TILE_TYPE
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			tile_tmp = _get_tile(x_pos, y_pos)
			if tile_tmp != TILE_TYPE.AIR:
				tiles_dir += Vector2(x_pos, y_pos) - rect_center
				if chunk_mng.tile_durability[int(tile_tmp)] > mining_force:
					stronger_tiles_dir += Vector2(x_pos, y_pos) - rect_center
	
	return Vector4(tiles_dir.x, tiles_dir.y, stronger_tiles_dir.x, stronger_tiles_dir.y)
	
	#return Vector4(
		#NAN if tiles_dir == Vector2.ZERO else tiles_dir.x,
		#NAN if tiles_dir == Vector2.ZERO else tiles_dir.y,
		#NAN if stronger_tiles_dir == Vector2.ZERO else stronger_tiles_dir.x,
		#NAN if stronger_tiles_dir == Vector2.ZERO else stronger_tiles_dir.y)

func eval_area_mask(start_world: Vector2i, mask: BitMap, mining_force: int) -> Vector2:
	var tiles_dir: Vector2 = Vector2.ZERO
	var stronger_tiles_dir: Vector2 = Vector2.ZERO
	
	var grid_pos_start: Vector2i = world_to_grid(start_world)
	var grid_pos_end: Vector2i = world_to_grid(start_world + mask.get_size())
	var rect_center: Vector2 = (grid_pos_start + grid_pos_end) / 2.0
	
	var tile_tmp: TILE_TYPE
	for x_pos: int in range(grid_pos_start.x, grid_pos_end.x):
		for y_pos: int in range(grid_pos_start.y, grid_pos_end.y):
			tile_tmp = _get_tile_safe(x_pos, y_pos)
			if (!mask.get_bit(x_pos - grid_pos_start.x, y_pos - grid_pos_start.y) and
				tile_tmp != TILE_TYPE.AIR):
				tiles_dir += Vector2(x_pos, y_pos) - rect_center
				if chunk_mng.tile_durability[int(tile_tmp)] > mining_force:
					stronger_tiles_dir += Vector2(x_pos, y_pos) - rect_center
	
	return Vector2(
		NAN if tiles_dir == Vector2.ZERO else tiles_dir.angle(), 
		NAN if stronger_tiles_dir == Vector2.ZERO else stronger_tiles_dir.angle())

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

func _fix_borders_helper(coord_tmp: Vector2i) -> void:
	assert(is_grid_pos_in_bounds(coord_tmp))
	var target_type: TILE_TYPE = _get_tilev(coord_tmp)
	if target_type == TILE_TYPE.AIR: return
	
	if _has_same_neighborsv(coord_tmp):
		if img.get_pixelv(coord_tmp) == chunk_mng.tile_edge_colors[target_type]:
			_terrain_really_changed = true
			img.set_pixelv(
				coord_tmp, 
				_tile_sprites[target_type].get_pixelv(Vector2i(coord_tmp) % _tile_sprites[target_type].get_size())
			)
	else:
		if img.get_pixelv(coord_tmp) != chunk_mng.tile_edge_colors[target_type]:
			_terrain_really_changed = true
			img.set_pixelv(coord_tmp, chunk_mng.tile_edge_colors[target_type])

#endregion

#region editor

var changed_terrain: bool = false

func should_save_terrain() -> bool:
	return changed_terrain

func unload() -> void:
	if changed_terrain:
		print("Saving chunk terrain: " + str(coords))
		_save_terrain()

func _save_terrain() -> void:
	var target_path: String = chunk_mng.get_chunk_path(coords)
	var file_to_save: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file_to_save:
		var compressed_data: PackedByteArray = compress_chunk(self.data)
		file_to_save.store_buffer(compressed_data)
	else:
		print("Probem trying to save chunk " + str(coords))

static func compress_chunk(decompressed_data: PackedByteArray) -> PackedByteArray:
	return decompressed_data.compress(Globals.CHUNK_COMPRESSION_METHOD)

#endregion

#func _draw() -> void:
	#var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	#rng.seed = 1
	#for rid: RID in _poligons_RID:
		#var poly_data: PackedVector2Array = PhysicsServer2D.shape_get_data(rid)
		#draw_colored_polygon(poly_data, Color.from_rgba8(rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), 100))

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	PhysicsServer2D.free_rid(_collision_RID)
	for rid: RID in _poligons_RID:
		PhysicsServer2D.free_rid(rid)
