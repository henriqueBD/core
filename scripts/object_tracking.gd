@tool
class_name tracking_obj
extends Node2D

var curr_chunk: Vector2i = Vector2i(10000000,1000000)
var obj_name: String
var obj_id: int

var start_global_pos: Vector2

var chunk_unloaded: bool = false

func _ready() -> void:
	var original_pos: Variant = self.get_meta("original_pos", NAN)
	if original_pos is Vector2:
		print("Adding from chunk")
		var vec_original_pos: Vector2 = original_pos as Vector2
		self.global_position = vec_original_pos
		start_global_pos = vec_original_pos
		curr_chunk = chunk_mng.world_to_chunk_key(start_global_pos)
		if !entity_signal.objects_per_chunk.has(curr_chunk):
			entity_signal.objects_per_chunk[curr_chunk] = {}
		entity_signal.objects_per_chunk[curr_chunk][self] = true
	else:
		print("Adding from editor")
	
	connect("tree_exiting", _remove_self_from_dict)
	self.set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if !is_node_ready():
			await ready
		_on_transform_changed()

func _on_transform_changed() -> void:
	var new_chunk_pos: Vector2i = chunk_mng.world_to_chunk_key(self.global_position)
	if curr_chunk == new_chunk_pos: return
	#add new reference
	if !entity_signal.objects_per_chunk.has(new_chunk_pos):
		entity_signal.objects_per_chunk[new_chunk_pos] = {}
	
	entity_signal.objects_per_chunk[new_chunk_pos][self] = true
	
	#if !entity_signal.is_freezed:
		#entity_signal.chunks_changed[new_chunk_pos] = true
	
	#remove old reference
	_remove_self_from_dict()
	
	curr_chunk = new_chunk_pos
	print(entity_signal.objects_per_chunk)

func changed() -> bool:
	return start_global_pos != self.global_position

func _remove_self_from_dict() -> void:
	if !entity_signal.objects_per_chunk.has(curr_chunk): return
	
	#if !chunk_unloaded:
		#entity_signal.chunks_changed[curr_chunk] = true
	
	var chunk_dict: Dictionary = entity_signal.objects_per_chunk[curr_chunk]
	chunk_dict.erase(self)
	if chunk_dict.is_empty():
		entity_signal.objects_per_chunk.erase(curr_chunk)
