##Used to safely move entities across the game, It handles deletion if it gets too far. 
class_name DynamicObjTracker
extends Node2D

const HALF_CHUNK_SIDE: Vector2i = Vector2(Global.CHUNK_SIDE / 2, Global.CHUNK_SIDE / 2)

var _parent: Node2D
var _world_bounds: Rect2
var _offset: Vector2
var _bigger_side: int

func _ready() -> void:
	_parent = get_parent()
	if not _parent:
		print("WHAT")
		return
	_parent.reparent(Global.main_node)
	Global.chunk_pre_unload.connect(_chunk_will_unload)

func define_bounds(world_bounds: Rect2) -> void:
	_world_bounds = world_bounds
	_offset = world_bounds.position - _parent.global_position
	_bigger_side = max(_world_bounds.size.x, _world_bounds.size.y)
	_bigger_side += 2

func move(new_world_pos: Vector2) -> void:
	_world_bounds.position = new_world_pos + _offset
	if !Global.chunks.is_rect_in_bounds(_world_bounds): _despawn()

func _despawn() -> void:
	_parent.set_process(false)
	_parent.queue_free()

func _chunk_will_unload(coord: Vector2i) -> void:
	#fast check
	coord += HALF_CHUNK_SIDE
	if coord.distance_squared_to(_world_bounds.get_center()) > _bigger_side:
		return
	if !Global.chunks.is_rect_in_bounds(_world_bounds):
		print("Entity out of bounds, despawning")
		_despawn()
