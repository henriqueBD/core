class_name obj_chunk

var id: Array[int]
var pos: Array[Vector2]

static func serialize_and_save(data: obj_chunk, coord_to_save: Vector2i) -> void:
	var file_path: String = chunk_tile.get_entities_map(coord_to_save)
	
	if data.id.is_empty():
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		return
	
	if data.pos.size() != data.id.size():
		printerr("Error in saving objs for chunk " + str(coord_to_save))
		return
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(data.pos.size() * 8 + data.id.size() * 8) # assuming 8 bytes per Vector2/Int64 component
	var offset: int = 0
	
	for p: Vector2 in data.pos:
		bytes.encode_float(offset, p.x)
		bytes.encode_float(offset + 4, p.y)
		offset += 8
	
	for id_tmp: int in data.id:
		bytes.encode_s64(offset, id_tmp)
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
	chunk_objs.pos = []
	chunk_objs.id = []
	
	var count: int = size / 16
	
	# Read positions
	for i: int in count:
		var x: float = stream.get_float()
		var y: float = stream.get_float()
		chunk_objs.pos.append(Vector2(x, y))
	
	# Read IDs
	for i: int in count:
		var id_val: int = stream.get_64()
		chunk_objs.id.append(id_val)
	
	return chunk_objs
