class_name obj_chunk

var id_static: Array[int]
var pos_static: Array[Vector2]

var id_dynamic: Array[int]
var pos_dynamic: Array[Vector2]

func add_obj(id_static_push: int, pos_static_push: Vector2, is_static: bool) -> void:
	if is_static:
		id_static.append(id_static_push)
		pos_static.append(pos_static_push)
	else:
		id_dynamic.append(id_static_push)
		pos_dynamic.append(pos_static_push)

func serialize_and_save(coord_to_save: Vector2i) -> void:
	var file_path: String = chunk_tile.get_entities_map(coord_to_save)
	
	if id_static.is_empty():
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		return
	
	if pos_static.size() != id_static.size():
		printerr("Error in saving objs for chunk " + str(coord_to_save))
		return
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(pos_static.size() * 8 + id_static.size() * 8) # assuming 8 bytes per Vector2/Int64 component
	var offset: int = 0
	
	for p: Vector2 in pos_static:
		bytes.encode_float(offset, p.x)
		bytes.encode_float(offset + 4, p.y)
		offset += 8
	
	for id_static_tmp: int in id_static:
		bytes.encode_s64(offset, id_static_tmp)
		offset += 8
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file: file.store_buffer(bytes)
	else: printerr(FileAccess.get_open_error())
	file.close()

static func deserialize(coords: Vector2i) -> obj_chunk:
	var file: FileAccess = FileAccess.open(chunk_tile.get_entities_map(coords), FileAccess.READ)
	if file == null:
		return obj_chunk.new()
	
	var size: int = file.get_length()
	var data: PackedByteArray = file.get_buffer(size)
	file.close()
	
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.data_array = data
	
	var chunk_objs: obj_chunk = obj_chunk.new()
	chunk_objs.pos_static = []
	chunk_objs.id_static = []
	
	var count: int = size / 16
	
	# Read pos_staticitions
	for i: int in count:
		var x: float = stream.get_float()
		var y: float = stream.get_float()
		chunk_objs.pos_static.append(Vector2(x, y))
	
	# Read id_statics
	for i: int in count:
		var id_static_val: int = stream.get_64()
		chunk_objs.id_static.append(id_static_val)
	
	return chunk_objs
