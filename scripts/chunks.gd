@tool
class_name chunk_mng
extends Node2D

const chunk_scene: Resource = preload("res://scenes/Chunk_tile.tscn")

const folderPath_debug: String = ""
const FOLDER_PATH_RELEASE: String = "res://chunks/"
const terrain_type_folder: String = "res://terrain_types/"
const meta_unique_id: String = "unique_id"

# Editor
const emptyChunkPath: String = FOLDER_PATH_RELEASE + "emptyChunk.dat"
var emptyChunkTemplate: PackedByteArray

static var tile_sprites: Array[Image]
static var tile_edge_colors: Array[Color]
static var tile_background_colors: Array[Color]
static var tile_durability: PackedByteArray

var _player: player_character

@export var _chunks_load_radius_game: int = 2
@export var _chunks_load_radius_editor: int = 5
@export var save_on_exit: bool


var folderPath: String = FOLDER_PATH_RELEASE
var _chunks_load_radius: int

var _chunks_dict: Dictionary[Vector2i, chunk_tile] = {}
var _dynamic_entities_loaded: Dictionary[Vector3, bool] = {}
var _unloaded_chunks_terrain_modified: Dictionary[Vector2i, BitMap] = {}
var _chunks_dict_mutex: Mutex = Mutex.new()
var _chunks_buff_dict: Dictionary[Vector2i, bool]

var _use_multithread: bool = false
var _loader_continue: bool = true
var _loader_thread: Thread

var _array_load_mutex: Mutex = Mutex.new()
var _chunk_load_queue: Array[Vector2i] = []
var _chunk_loading: Vector2i = Vector2i.MIN
var _array_unload_mutex: Mutex = Mutex.new()
var _chunk_unload_queue: Array[Vector2i] = []
var _chunk_unloading: Vector2i = Vector2i.MIN

var _last_center_chunk: Vector2i = Vector2i(-1, -1)
var _curr_center_chunk: Vector2i

## TODO: Better naming and comment this
var _break_id: Dictionary[int, Array] = {}
var _curr_id: int = 0
var _counter_mutex_break: Mutex
var _counter_mutex_eval: Mutex

var editor_stuff_active: bool = false

func _enter_tree() -> void:
	assert(self.global_position == Vector2.ZERO, "Chunks position must be at (0, 0)")
	
	#maybe put this somewhere else later
	Entity_loader.init_dictionaty("res://entities")
	Entity_loader.vibe_check()
	
	if Engine.is_editor_hint():
		_chunks_load_radius = _chunks_load_radius_editor
		if editor_stuff_active:
			late_ready()
			load_nearby_chunks(EditorInterface.get_editor_viewport_2d().get_mouse_position())
		var parent: Node = self.get_parent()
		if parent:
			var script: Script = load("res://scripts/objects_signal.gd")
			if script: parent.set_script(script)
	else:
		_chunks_load_radius = _chunks_load_radius_game
		self.set_process(false)
		Global.player_spawned.connect(_on_player_spawned)
		_use_multithread = true
		_counter_mutex_break = Mutex.new()
		_counter_mutex_eval = Mutex.new()
		Global.chunks = self
		Global.chunk_load.connect(_on_chunk_loaded)
	
	if OS.has_feature("editor") or OS.is_debug_build():
		folderPath = folderPath_debug
	
	create_empty_chunk_file()
	emptyChunkTemplate = FileAccess.get_file_as_bytes(emptyChunkPath)
	assert(len(emptyChunkTemplate) > 0)
	for i: int in range(1, len(tile_sprites)):
		assert(tile_sprites[i] != null)
	
	_load_tile_resources()
	
	chunk_tile._tile_sprites = tile_sprites
	chunk_tile._chunks_loaded = _chunks_dict
	
	if _use_multithread: _loader_start()

func _on_player_spawned() -> void:
	set_process(true)
	_player = Global.player_node
	#_load_chunk_simple(world_to_chunk_key(_player.global_position))
	_curr_center_chunk = world_to_chunk_key(_player.global_position)
	_array_load_mutex.lock()
	_chunk_load_queue.append(_curr_center_chunk)
	_array_load_mutex.unlock()
	#_player.set_physics_process(true)

func late_ready() -> void:
	if !Engine.is_editor_hint():
		_player = Global.player_node
	#if obj_id_to_name.is_empty():
		#_load_obj_list()

func _on_chunk_loaded(load_coord: Vector2i) -> void:
	if load_coord != _curr_center_chunk: return
	Global.chunk_load.disconnect(_on_chunk_loaded)
	_player.set_physics_process(true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if editor_stuff_active:
			load_nearby_chunks(EditorInterface.get_editor_viewport_2d().get_mouse_position())
	else:
		load_nearby_chunks(_player.global_position)

#region Chunk loader

func _loader_start() -> void:
	if _loader_thread and _loader_thread.is_alive():
		_loader_continue = false
		_reset_queues()
		_loader_thread.wait_to_finish()
	_reset_queues()
	_loader_thread = Thread.new()
	_loader_continue = true
	_loader_thread.start(_loader_process)

func _reset_queues() -> void:
	_array_load_mutex.lock()
	_chunk_load_queue.clear()
	_array_load_mutex.unlock()
	
	_array_unload_mutex.lock()
	_chunk_unload_queue.clear()
	_array_unload_mutex.unlock()

# Multithreaded chunk loading and unloading:
func _loader_process() -> void:
	##TODO: Sleep or stop the thread to avoid wasting 100% of this core
	while _loader_continue:
		# Load chunks
		if !_chunk_load_queue.is_empty():
			_array_load_mutex.lock()
			var chunk_to_load_coords: Vector2i = _chunk_load_queue.pop_front()
			_array_load_mutex.unlock()
			
			if (chunk_to_load_coords == _chunk_loading or
				chunk_to_load_coords == _chunk_unloading or
				_chunks_dict.has(chunk_to_load_coords)):
				continue
			
			#print("loading from thread " + str(chunk_to_load_coords))
			_chunk_loading = chunk_to_load_coords
			
			_load_chunk_thread_safe(chunk_to_load_coords)
		
		#Unload chunks
		if !_chunk_unload_queue.is_empty():
			_array_unload_mutex.lock()
			var chunk_to_unload_coords: Vector2i = _chunk_unload_queue.pop_front()
			_array_unload_mutex.unlock()
			#print("unloading from thread " + str(chunk_to_unload_coords))
			if (chunk_to_unload_coords == _chunk_loading or
				chunk_to_unload_coords == _chunk_unloading or
				!_chunks_dict.has(chunk_to_unload_coords)):
				continue
			
			_chunk_unloading = chunk_to_unload_coords
			var chunk_to_remove: chunk_tile = _chunks_dict[chunk_to_unload_coords]
			
			if chunk_to_remove.should_save_terrain():
				_unloaded_chunks_terrain_modified[chunk_to_unload_coords] = chunk_to_remove._terrain_mask
			
			if should_skip_save():
				chunk_to_remove._terrain_really_changed = false
				chunk_to_remove.changed_terrain = false
				chunk_to_remove.changed_entities = false
			
			chunk_to_remove.unload()
			chunk_to_remove.queue_free()
			
			_chunks_dict_mutex.lock()
			_chunks_dict.erase(chunk_to_unload_coords)
			_chunks_dict_mutex.unlock()
			_chunk_unloading = Vector2i.MIN

func _load_chunk_thread_safe(chunk_to_load_coords: Vector2i) -> void:
	var new_chunk_instance: chunk_tile = chunk_scene.instantiate()
	
	#Load chunk terrain
	var terrain_data: PackedByteArray = chunk_tile.decompress_chunk(chunk_tile.get_bytes(chunk_to_load_coords))
	assert(terrain_data.size() == Globals.CHUNK_SIZE)
	
	var previous_terrain_mask: BitMap = _unloaded_chunks_terrain_modified.get(chunk_to_load_coords)
	#if _unloaded_chunks_terrain_modified.has(chunk_to_load_coords):
		#pass
	
	var terrain_image: Image = chunk_tile.create_texture_from_terrain_data(terrain_data, previous_terrain_mask)
	var terrain_mask: BitMap = chunk_tile.get_terrain_mask_from_data(terrain_data, previous_terrain_mask)
	var terrain_collision: Array[CollisionPolygon2D] = chunk_tile.get_terrain_collision(terrain_mask)
	
	#Load chunk entities
	var instances: Array[Array] = [[], []]
	var instances_static: Array[Node2D]
	var instances_dynamic: Array[Node2D]
	var entities: obj_chunk = obj_chunk.deserialize(chunk_to_load_coords)
	
	if !entities.id_static.is_empty() or !entities.id_dynamic.is_empty():
		if Engine.is_editor_hint():
			add_objects_editor(new_chunk_instance, entities)
		else:
			instances = _get_objects(entities)
			instances_static = instances[0]
			instances_dynamic = instances[1]
			if !instances_dynamic.is_empty():
				#_convert_obj_pos_to_chunk_local(instances_dynamic, chunk_to_load_coords)
				var coords_as_vector2: Vector2 = Vector2(chunk_to_load_coords)
				for obj: Node2D in instances_dynamic:
					obj.global_position += coords_as_vector2 * Vector2(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE)
	
	call_deferred("_instantiate_chunk", new_chunk_instance, chunk_to_load_coords)
	new_chunk_instance.initialize_deffered(
		chunk_to_load_coords, 
		terrain_data, 
		terrain_image, 
		terrain_collision,
		terrain_mask,
		instances_static, 
		instances_dynamic)

func _loader_end() -> void:
	_loader_continue = false
	if _loader_thread:
		print("Exiting chunk loader")
		_loader_thread.wait_to_finish()

#endregion

func _load_tile_resources() -> void:
	tile_sprites = [null]
	tile_durability = [0]
	tile_edge_colors = [Color.from_rgba8(0,0,0,0)]
	tile_background_colors = [Color.from_rgba8(0,0,0,0)]
	
	var tile_name: Array = chunk_tile.TILE_TYPE.keys()
	for id: int in range(1, len(tile_name)):
		var tile_data: terrain_type_base = load(terrain_type_folder + tile_name[id] + ".tres")
		assert(tile_data)
		tile_sprites.append(tile_data.sprite.get_image())
		tile_edge_colors.append(tile_data.edge_color)
		tile_background_colors.append(tile_data.background_color)
		assert(tile_data.durability > 0 and tile_data.durability < 255, "Error in tile " + tile_name[id])
		tile_durability.append(tile_data.durability)

func is_chunk_in_bounds(check_coords: Vector2i) -> bool:
	return FileAccess.file_exists(get_chunk_path(check_coords))

func is_chunk_loaded(world_point: Vector2) -> bool:
	return _chunks_dict.has(world_to_chunk_key(world_point))

static func world_to_chunk_key(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / Global.CHUNK_SIDE), 
		floori(world_pos.y / Global.CHUNK_SIDE)
	)

func world_to_chunk(world_pos: Vector2) -> chunk_tile:
	var key: Vector2i = world_to_chunk_key(world_pos)
	return _chunks_dict[key]

func is_rect_in_bounds(rect: Rect2) -> bool:
	var start_chunk: Vector2i = world_to_chunk_key(rect.position)
	var end_chunk: Vector2i = world_to_chunk_key(rect.position + rect.size)
	 
	#TODO: (maybe) Poor performance at _chunk_unload_queue.has(Vector2i(x, y))
	_array_unload_mutex.lock()
	for x: int in range(start_chunk.x, end_chunk.x + 1):
		for y: int in range(start_chunk.y, end_chunk.y + 1):
			if _chunk_unload_queue.has(Vector2i(x, y)) or !_chunks_dict.has(Vector2i(x, y)):
				_array_unload_mutex.unlock()
				return false
	_array_unload_mutex.unlock()
	
	return true


func eval_area(area_rect: Rect2, mining_force: int) -> Vector2:
	var chunks: Rect2i = _get_rect_bounds(area_rect.position, area_rect.size)
	
	var weaker_direction: Vector2 = Vector2.ZERO
	var stronger_direction: Vector2 = Vector2.ZERO
	
	for x: int in range(chunks.position.x, chunks.size.x + 1):
		for y: int in range(chunks.position.y, chunks.size.y + 1):
			var key: Vector2i = Vector2i(x, y)
			if _chunks_dict.has(key):
				var eval_res: Vector4 = _chunks_dict[key].eval_area(area_rect, mining_force)
				weaker_direction += Vector2(eval_res.x, eval_res.y)
				stronger_direction += Vector2(eval_res.z, eval_res.w)
	
	return Vector2(NAN if weaker_direction == Vector2.ZERO else weaker_direction.angle(),
					NAN if stronger_direction == Vector2.ZERO else stronger_direction.angle())

func eval_area_mask(start_world: Vector2, mask: BitMap, mining_force: int) -> Vector2:
	var chunk_to_eval: chunk_tile = world_to_chunk(start_world)
	return chunk_to_eval.eval_area_mask(start_world, mask, mining_force)

func eval_break_area_mask(global_top_left: Vector2, mask: BitMap, mining_force: int, eval_force: int, callback: Callable) -> void:
	var world_rect: Rect2 = Rect2(
		global_top_left,
		mask.get_size() as Vector2
	)
	
	var chunks: Rect2i = _get_rect_bounds(global_top_left, mask.get_size())
	
	_break_id[_curr_id] = [0, Vector2.ZERO, callback]
	_break_id[_curr_id + 1] = [0, world_rect, false]
	
	for x: int in range(chunks.position.x, chunks.size.x + 1):
		for y: int in range(chunks.position.y, chunks.size.y + 1):
			var key: Vector2i = Vector2i(x, y)
			if _chunks_dict.has(key):
				
				_counter_mutex_eval.lock()
				_break_id[_curr_id][0] += 1
				_counter_mutex_eval.unlock()
				
				_counter_mutex_break.lock()
				_break_id[_curr_id + 1][0] += 1
				_counter_mutex_break.unlock()
				
				_chunks_dict[key].eval_break_tiles_mask(global_top_left, mask, mining_force, eval_force, _curr_id)
	
	_curr_id += 2
	
	_counter_mutex_break.unlock()
	_counter_mutex_eval.unlock()

func eval_tiles_post(id: int, angle: Vector2) -> void:
	_counter_mutex_eval.lock()
	
	var dict_res: Array = _break_id[id]
	
	dict_res[0] -= 1
	dict_res[1] += angle
	
	if dict_res[0] == 0:
		var angle_sum: Vector2 = dict_res[1]
		if angle_sum != Vector2.ZERO:
			var callback: Callable = dict_res[2]
			if callback.is_valid():
				callback.call_deferred(angle_sum.angle())
		dict_res.erase(id)
		
	_counter_mutex_eval.unlock()

func change_tiles(world_rect: Rect2, type: chunk_tile.TILE_TYPE) -> void:
	var chunk_top_left: Vector2i = world_to_chunk_key(world_rect.position)
	var chunk_top_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y))
	var chunk_bottom_right: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x, world_rect.position.y + world_rect.size.y))
	var chunk_bottom_left: Vector2i = world_to_chunk_key(
		Vector2(world_rect.position.x + world_rect.size.x, world_rect.position.y + world_rect.size.y))
	
	if _chunks_dict.has(chunk_top_left):
		_chunks_dict[chunk_top_left].change_tiles(world_rect, type)
	if chunk_top_right != chunk_top_left and _chunks_dict.has(chunk_top_right):
		_chunks_dict[chunk_top_right].change_tiles(world_rect, type)
	if chunk_bottom_right != chunk_top_left and _chunks_dict.has(chunk_bottom_right):
		_chunks_dict[chunk_bottom_right].change_tiles(world_rect, type)
	if (chunk_bottom_left != chunk_top_right and 
		chunk_bottom_left != chunk_bottom_right and 
		_chunks_dict.has(chunk_bottom_left)):
		_chunks_dict[chunk_bottom_left].change_tiles(world_rect, type)

func break_tiles_mask(global_top_left: Vector2, mask: BitMap, mining_force: int) -> void:
	var world_rect: Rect2 = Rect2(
		global_top_left,
		mask.get_size() as Vector2
	)
	
	var chunks: Rect2i = _get_rect_bounds(global_top_left, mask.get_size())
	
	_break_id[_curr_id] = [0, world_rect, false]
	
	for x: int in range(chunks.position.x, chunks.size.x + 1):
		for y: int in range(chunks.position.y, chunks.size.y + 1):
			var key: Vector2i = Vector2i(x, y)
			if _chunks_dict.has(key):
				_chunks_dict[key].break_tiles_mask(global_top_left, mask, mining_force, _curr_id)
				_counter_mutex_break.lock()
				_break_id[_curr_id][0] += 1
				_counter_mutex_break.unlock()
	
	_curr_id += 1

## TODO: thread unsafe ??
func break_tiles_post(id: int, broke_tiles: bool) -> void:
	_counter_mutex_break.lock()
	
	var dict_res: Array = _break_id[id]
	
	if broke_tiles:
		dict_res[2] = true
		
	dict_res[0] -= 1
	
	if dict_res[0] == 0:
		
		if dict_res[2]:
			Global.terrain_break.emit.call_deferred(dict_res[1])
			
		dict_res.erase(id)
		
	_counter_mutex_break.unlock()

func load_nearby_chunks(global_pos: Vector2) -> void:
	_curr_center_chunk = world_to_chunk_key(global_pos)
	if _curr_center_chunk == _last_center_chunk:
		return
	
	_last_center_chunk = _curr_center_chunk
	_chunks_buff_dict.clear()
	
	#Queuing load chunks
	var editor_msg: String = "Loading: "
	
	for x_offset: int in range(_curr_center_chunk.x - _chunks_load_radius, _curr_center_chunk.x + _chunks_load_radius + 1):
		for y_offset: int in range(_curr_center_chunk.y - _chunks_load_radius, _curr_center_chunk.y + _chunks_load_radius + 1):
			var chunk_to_check: Vector2i = Vector2i(x_offset, y_offset)
			if is_chunk_in_bounds(chunk_to_check):
				_chunks_buff_dict[chunk_to_check] = true
				if not _chunks_dict.has(chunk_to_check):
					if _use_multithread:
						_array_load_mutex.lock()
						_chunk_load_queue.append(chunk_to_check)
						_array_load_mutex.unlock()
					else:
						_load_chunk_simple(chunk_to_check)
					if Engine.is_editor_hint(): 
						editor_msg += "({x}, {y}) ".format({"x": chunk_to_check.x, "y": chunk_to_check.y})
	
	if Engine.is_editor_hint(): 
		if len(editor_msg) > 9: print(editor_msg)
	
	#Queuing unload chunks
	editor_msg = "Unloading: "
	
	var to_remove: PackedVector2Array = []
	for key: Vector2i in _chunks_dict.keys():
		if not _chunks_buff_dict.has(key):
			to_remove.append(key)
	
	if !Engine.is_editor_hint():
		Global.chunk_pre_unload_bunch.emit(to_remove)
	
	for key: Vector2i in to_remove:
		if _use_multithread:
			_array_unload_mutex.lock()
			_chunk_unload_queue.append(key)
			_array_unload_mutex.unlock()
		else:
			_unload_chunk(key)
		if Engine.is_editor_hint(): 
			editor_msg += "({x}, {y}) ".format({"x": key.x, "y": key.y})
	
	if Engine.is_editor_hint(): 
		if len(editor_msg) > 11: print(editor_msg)

func _load_chunk_simple(load_coords: Vector2i) -> void:
	var newChunk: chunk_tile = chunk_scene.instantiate()
	var entities: obj_chunk = newChunk.initialize(load_coords)
	
	_instantiate_chunk(newChunk, load_coords)
	
	if entities.id_static.is_empty() and entities.id_dynamic.is_empty(): return
	
	if Engine.is_editor_hint():
		add_objects_editor(newChunk, entities)
	else:
		add_objects(newChunk, entities)

func _instantiate_chunk(new_chunk: chunk_tile, new_chunk_coords: Vector2i) -> void:
	add_child(new_chunk)
	new_chunk.owner = self
	_chunks_dict_mutex.lock()
	_chunks_dict[new_chunk_coords] = new_chunk
	_chunks_dict_mutex.unlock()
	_chunk_loading = Vector2i.MIN

func _unload_chunk(unloadCoords: Vector2i) -> void:
	if !_chunks_dict.has(unloadCoords): return
	var chunk_to_remove: chunk_tile = _chunks_dict[unloadCoords]
	
	if should_skip_save():
		chunk_to_remove._terrain_really_changed = false
		chunk_to_remove.changed_terrain = false
		chunk_to_remove.changed_entities = false
	
	_chunks_dict_mutex.lock()
	_chunks_dict.erase(unloadCoords)
	_chunks_dict_mutex.unlock()
	
	chunk_to_remove.unload()
	chunk_to_remove.queue_free()
	_chunk_unloading = Vector2i.MIN

func should_skip_save() -> bool:
	return !Engine.is_editor_hint()

func add_objects_editor(original_chunk: chunk_tile, entities: obj_chunk) -> void:
	var main_node: Node = self.get_parent()
	if !main_node: return
	
	for i: int in range(len(entities.id_static)):
		var instance_scene: PackedScene = Entity_loader.load_scene(entities.id_static[i])
		var instance: Node2D = instance_scene.instantiate()
		if _is_dynamic_obj(instance):
			print_rich("[color=red]Dynamic object found in static array[/color]")
			instance.set_meta("is_dynamic", true)
		var instance_global_pos: Vector2 = original_chunk.to_global(entities.pos_static[i])
		instance.set_meta("original_pos", instance_global_pos)
		main_node.add_child(instance)
		instance.owner = main_node
	for i: int in range(len(entities.id_dynamic)):
		var instance_scene: PackedScene = Entity_loader.load_scene(entities.id_dynamic[i])
		var instance: Node2D = instance_scene.instantiate()
		var instance_global_pos: Vector2 = original_chunk.to_global(entities.pos_dynamic[i])
		instance.set_meta("original_pos", instance_global_pos)
		instance.set_meta("is_dynamic", true)
		main_node.add_child(instance)
		instance.owner = main_node

func _is_dynamic_obj(instance: Node2D) -> bool:
	if instance is tracking_obj: return true
	for child: Node in instance.get_children():
		if _is_dynamic_obj(child): return true
	return false

func add_objects(chunk_to_add: chunk_tile, objs: obj_chunk) -> void:
	for i: int in range(len(objs.id_static)):
		var tmp: PackedScene = Entity_loader.load_scene(objs.id_static[i])
		var instance: Node2D = tmp.instantiate()
		instance.global_position = objs.pos_static[i]
		chunk_to_add.add_child(instance)
	for i: int in range(len(objs.id_dynamic)):
		var tmp: PackedScene = Entity_loader.load_scene(objs.id_dynamic[i])
		var instance: Node2D = tmp.instantiate()
		instance.global_position = objs.pos_dynamic[i]
		chunk_to_add.add_child(instance)
	chunk_to_add.changed_entities = false

func unregister_dynamic_obj(unique_id: Vector3) -> void:
	_dynamic_entities_loaded.erase(unique_id)

func _get_objects(objs: obj_chunk) -> Array[Array]:
	var instances_static: Array[Node2D] = []
	var instances_dynamic: Array[Node2D] = []
	
	for i: int in range(len(objs.id_static)):
		var instance_scene: PackedScene = Entity_loader.load_scene(objs.id_static[i])
		var instance: Node2D = instance_scene.instantiate()
		instance.global_position = objs.pos_static[i]
		instances_static.append(instance)
	
	for i: int in range(len(objs.id_dynamic)):
		var unique_id: Vector3 = Vector3(objs.pos_dynamic[i].x, objs.pos_dynamic[i].y, objs.id_dynamic[i])
		if _dynamic_entities_loaded.has(unique_id): continue
		_dynamic_entities_loaded[unique_id] = true
		var instance_scene: PackedScene = Entity_loader.load_scene(objs.id_dynamic[i])
		var instance: Node2D = instance_scene.instantiate()
		instance.global_position = objs.pos_dynamic[i]
		instance.set_meta(meta_unique_id, unique_id)
		instances_dynamic.append(instance)
	
	return [instances_static, instances_dynamic]

##return.position = first chunk
##
##return.size = last chunk
func _get_rect_bounds(start: Vector2, size: Vector2) -> Rect2i:
	return Rect2i(
		world_to_chunk_key(start),
		world_to_chunk_key(start + size)
	)

func _convert_obj_pos_to_chunk_local(objs: Array[Node2D], chunk_coords: Vector2i) -> void:
	var coords_converted: Vector2 = chunk_coords
	for obj: Node2D in objs:
		obj.global_position += coords_converted * Vector2(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE)

static func get_chunk_path(chunk_coords: Vector2i) -> String:
	return FOLDER_PATH_RELEASE + str(chunk_coords.x) + "_" + str(chunk_coords.y) + ".dat"

func create_empty_chunk(new_chunk_pos: Vector2i) -> void:
	var newChunk: chunk_tile = chunk_scene.instantiate()
	newChunk.initialize(new_chunk_pos, emptyChunkTemplate)
	newChunk._save_terrain()
	add_child(newChunk)
	_chunks_dict_mutex.lock()
	_chunks_dict[new_chunk_pos] = newChunk
	_chunks_dict_mutex.unlock()

func create_empty_chunk_file() -> void:
	var empty_data_decompressed: PackedByteArray = []
	empty_data_decompressed.resize(Globals.CHUNK_SIZE)
	for i: int in range(empty_data_decompressed.size()):
		empty_data_decompressed[i] = chunk_tile.TILE_TYPE.AIR
	var file_to_save: FileAccess = FileAccess.open(emptyChunkPath, FileAccess.WRITE)
	if file_to_save:
		var compressed_data: PackedByteArray = chunk_tile.compress_chunk(empty_data_decompressed)
		file_to_save.store_buffer(compressed_data)
	else:
		printerr("Probem trying to save empty chunk ")

func _cleanup() -> void:
	unload_all_chunks()
	_loader_end()
	
	_unloaded_chunks_terrain_modified.clear()
	_dynamic_entities_loaded.clear()
	_chunks_buff_dict.clear()
	_chunks_dict.clear()
	_break_id.clear()
	

func _exit_tree() -> void:
	_loader_end()
	unload_all_chunks()

func unload_all_chunks() -> void:
	for k: Vector2i in _chunks_dict.keys():
		_unload_chunk(k)
