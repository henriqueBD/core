@tool
class_name Entity_loader
extends Object

static var _id_to_path: Dictionary[int, NodePath] = {
	hash_string("falling_spike_small"): "res://entities/falling_spike_small/falling_spike_small.tscn",
	hash_string("falling_spike_big") : "res://entities/falling_spike_big/falling_spike_big.tscn",
	hash_string("simple_mushoom") : "res://entities/simple_assets/simple_mushoom.tscn",
	hash_string("simple_rock") : "res://entities/simple_assets/simple_rock.tscn",
}

static func vibe_check() -> void:
	print("Vibe checking")
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
