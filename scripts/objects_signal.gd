@tool
class_name entity_signal
extends Node

const EXCLUDE: Array[String] = ["Camera2D", "Chunk", "Player"]

static var objects_per_chunk: Dictionary[Vector2i, Dictionary] = {}
static var chunks_changed: Dictionary[Vector2i, bool] = {}

var obj_script: Script

@onready var chunks: chunk_mng = $Chunk

func _ready() -> void:
	self.set_process(false)
	_try_connect("child_entered_tree", _on_child_entered)
	if !chunks.is_connected("child_exiting_tree", _on_chunk_child_leaving):
		chunks.connect("child_exiting_tree", _on_chunk_child_leaving)
	obj_script = load("res://scripts/object_tracking.gd")

func _try_connect(name_signal: String, fn: Callable) -> void:
	if !is_connected(name_signal, fn):
		connect(name_signal, fn)

func _on_child_entered(node: Node) -> void:
	if node.name in EXCLUDE: return
	
	var node_name: String = node.scene_file_path.get_base_dir().get_file()
	if node_name.is_empty(): return
	var node_ID: int = chunk_mng.hash_string(node_name)
	node.set_script(obj_script)
	node.obj_id = node_ID
	node.obj_name = node_name

func _on_chunk_child_leaving(node: Node) -> void:
	var chunk: chunk_tile = node as chunk_tile
	
	if !chunk: return
	if (!objects_per_chunk.has(chunk.coords) or 
		!chunks_changed.has(chunk.coords)): return
	
	chunks_changed.erase(chunk.coords)
	chunk.clear_entity_backend()
	
	var save: bool = false
	
	for nd: Node in objects_per_chunk[chunk.coords]:
		if not nd: continue
		nd.queue_free()
		var obj: tracking_obj = nd as tracking_obj
		if not obj: continue
		chunk.add_entity_backend(obj.obj_id, obj.global_position)
		save = true
	
	if !save: return
	
	objects_per_chunk.erase(chunk.coords)
	chunk._save_entities()
