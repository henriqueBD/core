@tool
class_name chunk_mng
extends Node2D

const chunk_scene: Resource = preload("res://scenes/Chunk_tile.tscn")

const folderPath: String = "res://chunks/"
const terrain_type_folder: String = "res://terrain_types/"

# Editor
const emptyChunkPath: String = folderPath + "emptyChunk.dat"
var emptyChunkTemplate: PackedByteArray

var player: player_character

@export var chunks_load_radius: int = 3
@export var save_on_exit: bool

var chunksDict: Dictionary[Vector2i, chunk_tile] = {}
var chunksBuffDict: Dictionary[Vector2i, bool]

var _last_center_chunk: Vector2i = Vector2i(-1, -1)
var _curr_center_chunk: Vector2i

static var tile_sprites: Array[Image]
static var tile_edge_colors: Array[Color]
static var tile_durability: PackedByteArray

static var obj_id_to_name: Dictionary[int, String] = {}

#Debug only remove on release
var should_mouse_break: bool = true

var editor_stuff_active: bool = false

func _enter_tree() -> void:
	assert(self.global_position == Vector2.ZERO, "Chunks position must be at (0, 0)")
	if Engine.is_editor_hint():
		if editor_stuff_active:
			late_ready()
			load_nearby_chunks(EditorInterface.get_editor_viewport_2d().get_mouse_position())
	else:
		Global.chunks = self
	
	_load_obj_list()
	_load_tile_resources()

func late_ready() -> void:
	if !Engine.is_editor_hint():
		player = Global.player_node
	emptyChunkTemplate = FileAccess.get_file_as_bytes(emptyChunkPath)
	assert(len(emptyChunkTemplate) > 0)
	for i: int in range(1, len(tile_sprites)):
		assert(tile_sprites[i] != null)
	
	if obj_id_to_name.is_empty():
		_load_obj_list()
	
	load_chunk(Vector2i(0,0))

func _load_tile_resources() -> void:
	tile_sprites = [null]
	tile_durability = [0]
	tile_edge_colors = [Color.from_rgba8(0,0,0,0)]
	
	var tile_name: Array = chunk_tile.TILE_TYPE.keys()
	for id: int in range(1, len(tile_name)):
		var tile_data: terrain_type_base = load(terrain_type_folder + tile_name[id] + ".tres")
		assert(tile_data)
		tile_sprites.append(tile_data.sprite.get_image())
		tile_edge_colors.append(tile_data.edge_color)
		assert(tile_data.durability < 255)
		tile_durability.append(tile_data.durability)

func _load_obj_list() -> void:
	var dir: DirAccess = DirAccess.open(Global.objs_path)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var d: Dictionary[int, String] = {}
	obj_id_to_name = d
	while file_name != "":
		if dir.current_is_dir():
			var hash_id: int = hash_string(file_name)
			obj_id_to_name[hash_id] = file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	print(obj_id_to_name)
	pass

static func hash_string(input: String) -> int:
	var hash_var: int = 5381
	for c: String in input:
		var code: int = c.unicode_at(0)
		hash_var = ((hash_var << 5) + hash_var) + code
	return hash_var & 0x7FFFFFFF

func load_chunk(load_coords: Vector2i) -> void:
	#print("loading " + str(load_coords))
	
	var newChunk: chunk_tile = chunk_scene.instantiate()
	var entities: obj_chunk = newChunk.initialize(load_coords, tile_sprites, chunksDict)
	
	newChunk.fix_borders()
	
	var coord_tmp: Vector2i = load_coords + Vector2i.UP
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.DOWN
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.LEFT
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.RIGHT
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	
	add_child(newChunk)
	chunksDict[load_coords] = newChunk
	newChunk.owner = self
	
	if entities == null: return
	
	if Engine.is_editor_hint():
		for i: int in range(len(entities.id)):
			var img_tmp: Image = Image.new()
			var obj_name: String = obj_id_to_name[entities.id[i]]
			var path: String = "%s%s/%s_preview.png" % [Global.objs_path, obj_name, obj_name]
			if img_tmp.load(path) != OK:
				push_error("Failed to load image at path: %s" % path)
				continue
			var to_add: Sprite2D = Sprite2D.new()
			to_add.texture = ImageTexture.create_from_image(img_tmp)
			to_add.global_position = entities.pos[i]
			newChunk.add_sprite(to_add)
	else:
		add_objects(newChunk, entities)

func unload_chunk(unloadCoords: Vector2i) -> void:
	if !chunksDict.has(unloadCoords): return
	var chunk_to_remove: chunk_tile = chunksDict[unloadCoords]
	
	if save_on_exit:
		print("unloading and saving " + str(unloadCoords))
	else:
		#print("unloading " + str(unloadCoords))
		chunk_to_remove._terrain_really_changed = false
		chunk_to_remove.changed_terrain = false
		chunk_to_remove.changed_entities = false
	
	chunk_to_remove.unload()
	chunksDict.erase(unloadCoords)
	chunk_to_remove.queue_free()

func is_chunk_in_bounds(check: Vector2i) -> bool:
	return FileAccess.file_exists(get_chunk_path(check))

func is_chunk_loaded(world_point: Vector2) -> bool:
	return chunksDict.has(world_to_chunk_key(world_point))

static func world_to_chunk_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / Global.CHUNK_SIDE), 
		floori(world_pos.y / Global.CHUNK_SIDE)
	)

func world_to_chunk(world_pos: Vector2) -> chunk_tile:
	var key: Vector2i = world_to_chunk_key(world_pos)
	return chunksDict[key]

func eval_area(area_rect: Rect2, mining_force: int) -> Vector2:
	var chunk_to_eval: chunk_tile = world_to_chunk(area_rect.position)
	return chunk_to_eval.eval_area(area_rect, mining_force)

#region Ray Cast

# Returns the global Y coord if there is collision, else returns -INF
func raycast_down_world(world_pos: Vector2, dist: int) -> float:
	var chunk_point: chunk_tile = world_to_chunk(world_pos)
	return chunk_point.rayCastDown(
		world_pos, dist, world_to_chunk(Vector2(world_pos.x, world_pos.y + 1)))

# Returns the global Y coord if there is collision, else returns -INF
func raycast_up_world(world_pos: Vector2, dist: int) -> float:
	var chunk_point: chunk_tile = world_to_chunk(world_pos)
	return chunk_point.rayCastUp(
		world_pos, dist, world_to_chunk(Vector2(world_pos.x, world_pos.y - 1)))

# Returns the global X coord if there is collision, else returns -INF
func raycast_left_world(world_pos: Vector2, dist: int) -> float:
	var chunk_point: chunk_tile = world_to_chunk(world_pos)
	return chunk_point.rayCastLeft(
		world_pos, dist, world_to_chunk(Vector2(world_pos.x - 1, world_pos.y)))

# Returns the global X coord if there is collision, else returns -INF
func raycast_right_world(world_pos: Vector2, dist: int) -> float:
	var chunk_point: chunk_tile = world_to_chunk(world_pos)
	return chunk_point.rayCastRight(
		world_pos, dist, world_to_chunk(Vector2(world_pos.x + 1, world_pos.y)))

func raycast_general_world(world_pos_start: Vector2, world_pos_end: Vector2) -> float:
	var chunk_point: chunk_tile = world_to_chunk(world_pos_start)
	return chunk_point.ray_cast_general(world_pos_start, world_pos_end)

#endregion

func is_tile_air(world_point: Vector2) -> bool:
	var point_key: Vector2i = world_to_chunk_key(world_point)
	if !chunksDict.has(point_key): return true
	var chunk_to_check: chunk_tile = chunksDict[point_key]
	return chunk_to_check._get_tilev(chunk_to_check.world_to_grid(world_point)) == 0

func breakTiless(world_rect: Rect2) -> void:
	var top_left: Vector2 = world_rect.position
	for x_break: int in range(top_left.x, top_left.x + world_rect.size.x):
		for y_break: int in range(top_left.y, top_left.y + world_rect.size.y):
			var pos: Vector2 = Vector2(x_break, y_break)
			var chunk: Vector2i = world_to_chunk_key(pos)
			if is_chunk_in_bounds(chunk) and chunksDict.has(chunk):
				var target: chunk_tile = chunksDict[chunk]
				target.destroyTiles(target.world_to_grid(pos))

func change_tiles(world_rect: Rect2, type: chunk_tile.TILE_TYPE) -> void:
	var chunk_top_left: Vector2i = world_to_chunk_key(world_rect.position)
	var chunk_top_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y))
	var chunk_bottom_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y))
	var chunk_bottom_left: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y + world_rect.size.y))
	
	if chunksDict.has(chunk_top_left):
		chunksDict[chunk_top_left].change_tiles(world_rect, type)
	if chunk_top_right != chunk_top_left and chunksDict.has(chunk_top_right):
		chunksDict[chunk_top_right].change_tiles(world_rect, type)
	if chunk_bottom_right != chunk_top_left and chunksDict.has(chunk_bottom_right):
		chunksDict[chunk_bottom_right].change_tiles(world_rect, type)
	if (chunk_bottom_left != chunk_top_right and 
		chunk_bottom_left != chunk_bottom_right and 
		chunksDict.has(chunk_bottom_left)):
		chunksDict[chunk_bottom_left].change_tiles(world_rect, type)

func break_tiles(world_rect: Rect2, mining_force: int) -> void:
	var chunk_top_left: Vector2i = world_to_chunk_key(world_rect.position)
	var chunk_top_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y))
	var chunk_bottom_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y))
	var chunk_bottom_left: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y + world_rect.size.y))
	
	if chunksDict.has(chunk_top_left):
		chunksDict[chunk_top_left].break_tiles(world_rect, mining_force)
	if chunk_top_right != chunk_top_left and chunksDict.has(chunk_top_right):
		chunksDict[chunk_top_right].break_tiles(world_rect, mining_force)
	if chunk_bottom_right != chunk_top_left and chunksDict.has(chunk_bottom_right):
		chunksDict[chunk_bottom_right].break_tiles(world_rect, mining_force)
	if (chunk_bottom_left != chunk_top_right and 
		chunk_bottom_left != chunk_bottom_right and 
		chunksDict.has(chunk_bottom_left)):
		chunksDict[chunk_bottom_left].break_tiles(world_rect, mining_force)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if editor_stuff_active:
			load_nearby_chunks(EditorInterface.get_editor_viewport_2d().get_mouse_position())
	else:
		load_nearby_chunks(player.global_position)

func load_nearby_chunks(global_pos: Vector2) -> void:
	_curr_center_chunk = world_to_chunk_key(global_pos)
	if _curr_center_chunk == _last_center_chunk:
		return
	
	_last_center_chunk = _curr_center_chunk
	chunksBuffDict.clear()
	
	var editor_msg: String = "Loading: "
	
	for x_offset: int in range(_curr_center_chunk.x - chunks_load_radius, _curr_center_chunk.x + chunks_load_radius + 1):
		for y_offset: int in range(_curr_center_chunk.y - chunks_load_radius, _curr_center_chunk.y + chunks_load_radius + 1):
			var chunk_to_check: Vector2i = Vector2i(x_offset, y_offset)
			if is_chunk_in_bounds(chunk_to_check):
				chunksBuffDict[chunk_to_check] = true
				if not chunksDict.has(chunk_to_check):
					load_chunk(chunk_to_check)
					if Engine.is_editor_hint(): 
						editor_msg += "({x}, {y}) ".format({"x": chunk_to_check.x, "y": chunk_to_check.y})
	
	if Engine.is_editor_hint(): 
		if len(editor_msg) > 9: print(editor_msg)
	
	editor_msg = "Unloading: "
	
	var to_remove: Array[Vector2i] = []
	for key: Vector2i in chunksDict.keys():
		if not chunksBuffDict.has(key):
			to_remove.append(key)
	for key: Vector2i in to_remove:
		unload_chunk(key)
		if Engine.is_editor_hint(): 
			editor_msg += "({x}, {y}) ".format({"x": key.x, "y": key.y})
	
	if Engine.is_editor_hint(): 
		if len(editor_msg) > 11: print(editor_msg)

func add_object_chunk(global_pos: Vector2, obj: Node2D, obj_id: int) -> void:
	var chunk_to_add: chunk_tile = world_to_chunk(global_pos)
	if chunk_to_add == null:
		print("Invalid position")
		return
	obj.global_position = global_pos
	chunk_to_add.editor_add_entity(obj, obj_id)

func add_objects(chunk_to_add: chunk_tile, objs: obj_chunk) -> void:
	for i: int in range(len(objs.id)):
		var obj_name: String = obj_id_to_name[objs.id[i]]
		var path: String = "res://entities/%s/%s.tscn" % [obj_name, obj_name]
		var tmp: PackedScene = load(path)
		var obj: Area2D = tmp.instantiate()
		obj.global_position = objs.pos[i]
		chunk_to_add.editor_add_entity(obj, objs.id[i])
	chunk_to_add.changed_entities = false

static func get_chunk_path(chunk_coords: Vector2i) -> String:
	return folderPath + str(chunk_coords.x) + "_" + str(chunk_coords.y) + ".dat"

#region editor

func delete_objects_chunk(area: Area2D) -> void:
	var chunk_to_delete: chunk_tile = world_to_chunk(area.global_position)
	if chunk_to_delete == null:
		print("Invalid position")
		return
	chunk_to_delete.editor_delete_entity(area)

func createEmptyChunk(new_chunk_pos: Vector2i) -> void:
	if is_chunk_in_bounds(new_chunk_pos) or new_chunk_pos.x < 0 or new_chunk_pos.y < 0: return
	print("creating new chunk " + str(new_chunk_pos))
	var newChunk: chunk_tile = chunk_scene.instantiate()
	newChunk.initialize(new_chunk_pos, tile_sprites, chunksDict, emptyChunkTemplate)
	add_child(newChunk)
	chunksDict[new_chunk_pos] = newChunk

#endregion

func _exit_tree() -> void:
	unload_all_chunks()

func unload_all_chunks() -> void:
	for k: Vector2i in chunksDict.keys():
		unload_chunk(k)
