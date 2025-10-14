class_name chunk_mng
extends Node2D

const chunk_scene: Resource = preload("res://scenes/Chunk_tile.tscn")
const folderPath: String = "C:/Users/Henrique/Documents/Dev/Go/MapEditor/chunks/"

#Editor
const emptyChunkPath: String = folderPath + "emptyChunk.dat"
var emptyChunkTemplate: PackedByteArray

@onready var player: player_character = get_node("../Player")

@export var chunks_load_radius: int = 3

var chunksDict: Dictionary[Vector2i, chunk_tile] = {}
var chunksBuffDict: Dictionary[Vector2i, bool]

var lastCurrChunkPlayer: Vector2i = Vector2i(-1, -1)
var currChunkPlayer: Vector2i

var id_to_name: Dictionary[int, String]
var tile_sprites: Array[Image]

#Debug only remove on release
var should_mouse_break: bool = true

func _enter_tree() -> void:
	Global.chunks = self

func late_ready() -> void:
	tile_sprites = [
		null,
		Image.load_from_file("res://assets/sprites/terrain/dirt.png"), ##WILL NOT WORK ON SHIPPED GAME
		Image.load_from_file("res://assets/sprites/terrain/stone.png"),
		Image.load_from_file("res://assets/sprites/terrain/gold.png"),
		Image.load_from_file("res://assets/sprites/terrain/clovium.png"),
	]
	emptyChunkTemplate = FileAccess.get_file_as_bytes(emptyChunkPath)
	assert(len(emptyChunkTemplate) > 0)
	for i: int in range(1, len(tile_sprites)):
		assert(tile_sprites[i] != null)
	var coords: Vector2i = Vector2i(0,0)
	load_chunk(coords)

func load_chunk(load_coords: Vector2i) -> void:
	print("loading " + str(load_coords))
	
	var newChunk: chunk_tile = chunk_scene.instantiate()
	var entities: obj_chunk = newChunk.initialize(load_coords, tile_sprites, chunksDict)
	var coord_tmp: Vector2i = load_coords + Vector2i.UP
	
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.DOWN
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.LEFT
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	coord_tmp = load_coords + Vector2i.RIGHT
	if chunksDict.has(coord_tmp): chunksDict[coord_tmp].fix_borders()
	newChunk.fix_borders()
	
	add_child(newChunk)
	chunksDict[load_coords] = newChunk
	
	if entities == null: return
	add_objects(newChunk, entities)

func unload_chunk(unloadCoords: Vector2i) -> void:
	print("unloading " + str(unloadCoords))
	if chunksDict.has(unloadCoords):
		var chunk_to_remove: chunk_tile = chunksDict[unloadCoords]
		chunksDict.erase(unloadCoords)
		chunk_to_remove.queue_free()

func is_chunk_in_bounds(check: Vector2i) -> bool:
	return FileAccess.file_exists(get_chunk_path(check))

func world_to_chunk_key(world_pos: Vector2) -> Vector2i:
	#return Vector2i((world_pos.x - self.position.x) / Global.CHUNK_SIDE , (world_pos.y - self.position.y) / Global.CHUNK_SIDE)
	return Vector2i(world_pos.x / Global.CHUNK_SIDE , world_pos.y / Global.CHUNK_SIDE)

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
	currChunkPlayer = world_to_chunk_key(player.global_position)
	
	if currChunkPlayer == lastCurrChunkPlayer:
		return
	
	lastCurrChunkPlayer = currChunkPlayer
	chunksBuffDict.clear()
	
	for x_offset: int in range(currChunkPlayer.x - chunks_load_radius, currChunkPlayer.x + chunks_load_radius + 1):
		for y_offset: int in range(currChunkPlayer.y - chunks_load_radius, currChunkPlayer.y + chunks_load_radius + 1):
			var chunk_to_check: Vector2i = Vector2i(x_offset, y_offset)
			if is_chunk_in_bounds(chunk_to_check):
				chunksBuffDict[chunk_to_check] = true
				if not chunksDict.has(chunk_to_check):
					load_chunk(chunk_to_check)
	
	var to_remove: Array[Vector2i] = []
	for key: Vector2i in chunksDict.keys():
		if not chunksBuffDict.has(key):
			to_remove.append(key)
	for key: Vector2i in to_remove:
		unload_chunk(key)

func add_object_chunk(global_pos: Vector2, obj: Node2D, obj_id: int) -> void:
	var chunk_to_add: chunk_tile = world_to_chunk(global_pos)
	if chunk_to_add == null:
		print("Invalid position")
		return
	obj.global_position = global_pos
	chunk_to_add.editor_add_entity(obj, obj_id)

func add_objects(chunk_to_add: chunk_tile, objs: obj_chunk) -> void:
	for i: int in range(len(objs.id)):
		var obj_name: String = id_to_name[objs.id[i]]
		var path: String = "res://entities/" + obj_name + "/" + obj_name + ".tscn"
		var tmp: PackedScene = load(path)
		var obj: Area2D = tmp.instantiate()
		obj.global_position = objs.pos[i]
		chunk_to_add.editor_add_entity(obj, objs.id[i])
	chunk_to_add.changed_entities = false

static func get_chunk_path(chunk_coords: Vector2i) -> String:
	return folderPath + str(chunk_coords.x) + "-" + str(chunk_coords.y) + ".dat"

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
