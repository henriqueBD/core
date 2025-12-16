class_name obj_chunk

const _ERROR: PackedByteArray = [255]

var id_static: PackedInt64Array = []
var pos_static: PackedVector2Array = []

var id_dynamic: PackedInt64Array = []
var pos_dynamic: PackedVector2Array = []

func add_obj(id_push: int, pos_push: Vector2, is_static: bool) -> void:
	if is_static:
		id_static.append(id_push)
		pos_static.append(pos_push)
	else:
		id_dynamic.append(id_push)
		pos_dynamic.append(pos_push)

func serialize_and_save(coord_to_save: Vector2i) -> void:
	var file_path: String = chunk_tile.get_entities_map(coord_to_save)
	
	if id_static.is_empty() and id_dynamic.is_empty():
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		return
	
	if pos_static.size() != id_static.size() or pos_dynamic.size() != id_dynamic.size():
		printerr("Error in saving objs for chunk " + str(coord_to_save))
		return

	var bytes_static: PackedByteArray = _serialize_helper(id_static, pos_static)
	var bytes_dynamic: PackedByteArray = _serialize_helper(id_dynamic, pos_dynamic)
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_32(id_static.size())
		file.store_buffer(bytes_static)
		
		file.store_32(id_dynamic.size())
		file.store_buffer(bytes_dynamic)
	else: 
		printerr(FileAccess.get_open_error())
	
	file.close()

func _serialize_helper(id_array: PackedInt64Array, pos_array: PackedVector2Array) -> PackedByteArray:
	# Layout: [ID, ID, ID...] followed by [Pos, Pos, Pos...]
	if id_array.is_empty(): return []
	return id_array.to_byte_array() + pos_array.to_byte_array()

static func deserialize(coords: Vector2i) -> obj_chunk:
	var file_path: String = chunk_tile.get_entities_map(coords)
	if not FileAccess.file_exists(file_path):
		return obj_chunk.new()
	
	var data: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	if data.size() == 0:
		return obj_chunk.new()
	
	var chunk_objs: obj_chunk = obj_chunk.new()
	var offset: int = 0
	
	# --- READ STATIC ---
	var static_count: int = data.decode_s32(offset)
	offset += 4
	
	chunk_objs.id_static.resize(static_count)
	chunk_objs.pos_static.resize(static_count)
	
	# 1. Read all IDs first
	for i: int in range(static_count):
		chunk_objs.id_static[i] = data.decode_s64(offset)
		offset += 8 # Int64 is 8 bytes
		
	# 2. Read all Positions second
	for i: int in range(static_count):
		# Vector2 is 2 floats (4 bytes each) = 8 bytes total
		chunk_objs.pos_static[i] = Vector2(data.decode_float(offset), data.decode_float(offset + 4))
		offset += 8 
	
	var dynamic_count: int = data.decode_s32(offset)
	offset += 4
	
	chunk_objs.id_dynamic.resize(dynamic_count)
	chunk_objs.pos_dynamic.resize(dynamic_count)
	
	for i: int in range(dynamic_count):
		chunk_objs.id_dynamic[i] = data.decode_s64(offset)
		offset += 8
	
	for i: int in range(dynamic_count):
		chunk_objs.pos_dynamic[i] = Vector2(data.decode_float(offset), data.decode_float(offset + 4))
		offset += 8
	
	return chunk_objs
