@tool
class_name Entity_loader
extends Object

static var _id_to_path: Dictionary[int, NodePath]

static func init_dictionaty(path: String) -> void:
	_id_to_path.clear()
	_init_dictionaty_helper(path)

static func _init_dictionaty_helper(path: String) -> void:
	var directories: PackedStringArray = []
	
	for file: String in ResourceLoader.list_directory(path):
		if file.ends_with(".tscn"):
			var scene_name: String = file.trim_suffix(".tscn")
			var scene_path: NodePath = NodePath("%s/%s" % [path , file])
			_id_to_path[hash_string(scene_name)] = scene_path
		elif file.ends_with("/"):
			directories.append(file)
	
	for d: String in directories:
		_init_dictionaty_helper("%s/%s" % [path, d])

static func vibe_check() -> void:
	for path: NodePath in _id_to_path.values():
		assert(FileAccess.file_exists(path), "Path not found: " + str(path))

static func hash_string(input: String) -> int:
	var hash_var: int = 5381
	for c: String in input:
		var code: int = c.unicode_at(0)
		hash_var = ((hash_var << 5) + hash_var) + code
	return hash_var & 0x7FFFFFFF

static func load_scene(id: int) -> PackedScene:
	assert(_id_to_path.has(id), "Invalid entity ID: " + str(id))
	return load(_id_to_path[id])
