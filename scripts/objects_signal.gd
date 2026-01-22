@tool
class_name entity_signal
extends Node

const EXCLUDE: Array[String] = ["Camera2D", "Chunk", "Player", "PlayerSpawner"]

static var objects_per_chunk: Dictionary[Vector2i, Dictionary] = {}
static var chunks_force_save: Dictionary[Vector2i, bool] = {}

static var is_freezed: bool

var obj_script: Script

@onready var chunks: chunk_mng = $Chunk

#func _enter_tree() -> void:
	#if !Engine.is_editor_hint():
		#Global.main_node = self
		#for c: Node in self.get_children():
			#if c.get_script() == obj_script:
				#c.queue_free()
				#print("Removed editor object")
		#self.set_script(null)

func _ready() -> void:
	if !Engine.is_editor_hint():
		Global.main_node = self
		for c: Node in self.get_children():
			if c.get_script() == obj_script:
				c.queue_free()
				print("Removed editor object")
		self.set_script(null)
		return
	
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
	var is_dynamic: bool = node.has_meta("is_dynamic") or _is_dynamic_obj(node)
	var node_name: String = node.scene_file_path.get_file().trim_suffix(".tscn")
	if node_name.is_empty(): return
	print(node_name + "added")
	var node_ID: int = Entity_loader.hash_string(node_name)
	node.set_script(obj_script)
	node.obj_id = node_ID
	node.obj_name = node_name
	node.is_dynamic = is_dynamic

func _is_dynamic_obj(node: Node) -> bool:
	const DYNAMIC_NAME: StringName = "DynamicObjTracker"
	
	var script: Script = node.get_script()
	if script and script.get_global_name() == DYNAMIC_NAME: return true
	
	if node is tracking_obj:
		if node.is_dynamic: return true
	
	for c: Node in node.get_children():
		if _is_dynamic_obj(c): return true
	
	return false

func _lobotomize_node(node: Node) -> void:
	node.set_script(null)
	for child: Node in node.get_children():
		_lobotomize_node(child)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for key: Vector2i in objects_per_chunk.keys():
			if chunks._chunks_dict.has(key):
				_on_chunk_child_leaving(chunks._chunks_dict[key])

func _on_chunk_child_leaving(node: Node) -> void:
	var chunk: chunk_tile = node as chunk_tile
	
	if !chunk: return
	if !objects_per_chunk.has(chunk.coords): return
	
	var save: bool = chunks_force_save.has(chunk.coords)
	chunks_force_save.erase(chunk.coords)
	
	var objects_to_save: obj_chunk = obj_chunk.new()
	var objects_saved: Dictionary[Vector3, bool] = {}
	
	for nd: Node in objects_per_chunk[chunk.coords]:
		if not nd:
			printerr("Error 1 in saving object to chunk")
			continue
		nd.queue_free()
		var obj: tracking_obj = nd as tracking_obj
		if not obj:
			printerr("Error 2 in saving object to chunk")
			continue
		obj.chunk_unloaded = true
		
		var unique_key: Vector3 = Vector3(obj.obj_id, obj.global_position.x, obj.global_position.y)
		if !objects_saved.has(unique_key):
			objects_to_save.add_obj(obj.obj_id, chunk.to_local(obj.global_position), !obj.is_dynamic)
			objects_saved[unique_key] = true
			
		if obj.changed():
			save = true
	
	objects_per_chunk.erase(chunk.coords)
	
	if !save: return
	print("Saving chunk %s entities: (%s static / %s dynamic)" % [str(chunk.coords), str(objects_to_save.pos_static.size()), str(objects_to_save.pos_dynamic.size())])
	objects_to_save.serialize_and_save(chunk.coords)
