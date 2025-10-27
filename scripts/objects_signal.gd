@tool
class_name entity_signal
extends Node

const EXCLUDE: Array[String] = ["Camera2D", "Chunk", "Player"]

static var objects_per_chunk: Dictionary[Vector2i, Dictionary] = {}
static var chunks_force_save: Dictionary[Vector2i, bool] = {}

static var is_freezed: bool

var obj_script: Script

@onready var chunks: chunk_mng = $Chunk

func _enter_tree() -> void:
	if !Engine.is_editor_hint():
		for c: Node in self.get_children():
			if c.get_script() == obj_script:
				c.queue_free()
				print("Removed editor object")
		self.set_script(null)

func _ready() -> void:
	
	self.set_process(false)
	
	if !Engine.is_editor_hint():
		printerr("No editor scripts in game")
		self.set_script(null)
		return
	
	_try_connect("child_entered_tree", _on_child_entered)
	
	if !chunks.is_connected("child_exiting_tree", _on_chunk_child_leaving):
		chunks.connect("child_exiting_tree", _on_chunk_child_leaving)
	
	obj_script = load("res://scripts/object_tracking.gd")
	
	for c: Node in self.get_children():
		if c.get_script() == obj_script:
			c.queue_free()

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
	chunk.clear_entity_backend()
	if !objects_per_chunk.has(chunk.coords):
		chunk._save_entities()
		return
	
	var save: bool = chunks_force_save.has(chunk.coords)
	chunks_force_save.erase(chunk.coords)
	
	for nd: Node in objects_per_chunk[chunk.coords]:
		if not nd:
			print("what 0")
			continue
		nd.queue_free()
		var obj: tracking_obj = nd as tracking_obj
		if not obj:
			print("What 1")
			continue
		obj.chunk_unloaded = true
		chunk.add_entity_backend(obj.obj_id, obj.global_position)
		if obj.changed():
			save = true
	
	objects_per_chunk.erase(chunk.coords)
	
	if !save: return
	
	chunk._save_entities()
	print("Saving chunk entities: " + str(chunk.coords))
