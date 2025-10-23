@tool
class_name tracking_obj
extends Node2D

var curr_chunk: Vector2i = Vector2i(10000000,1000000)
var obj_name: String
var obj_id: int

func _ready() -> void:
	print("HEllo internal")
	connect("tree_exiting", _remove_self_from_dict)
	self.set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if not is_node_ready():
			await ready
		_on_transform_changed()

func _on_transform_changed() -> void:
	var new_chunk_pos: Vector2i = chunk_mng.world_to_chunk_key(self.global_position)
	if curr_chunk == new_chunk_pos: return
	#add new reference
	if !entity_signal.objects_per_chunk.has(new_chunk_pos):
		entity_signal.objects_per_chunk[new_chunk_pos] = {}
	
	entity_signal.objects_per_chunk[new_chunk_pos][self] = true
	entity_signal.chunks_changed[new_chunk_pos] = true
	
	#remove old reference
	_remove_self_from_dict()
	
	curr_chunk = new_chunk_pos
	print(entity_signal.objects_per_chunk)

func _remove_self_from_dict() -> void:
	if !entity_signal.objects_per_chunk.has(curr_chunk): return
	
	entity_signal.chunks_changed[curr_chunk] = true
	var chunk_dict: Dictionary = entity_signal.objects_per_chunk[curr_chunk]
	chunk_dict.erase(self)
	if chunk_dict.is_empty():
		entity_signal.objects_per_chunk.erase(curr_chunk)
