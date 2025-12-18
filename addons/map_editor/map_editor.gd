@tool
extends EditorPlugin

const TARGET_SCENE_PATH: String = "Game"

var _chunks: chunk_mng

const DockScene = preload("res://addons/map_editor/material_dock.tscn")
var _material_dock: Control = null

const RELOAD_TIME_SEC: float = 0.25

enum EDITOR_STATE {
	unreachable,
	place_obj,
	terraform,
	select_chunk,
}

var _curr_state: EDITOR_STATE = EDITOR_STATE.terraform

var _timer: float = 0
var _chunk_scene: PackedScene

var _should_update: bool = false
var _same_scene: bool = true
var _same_workplace: bool = true

var _curr_chunk_selected: Vector2i
var _chunks_selected: Array[Vector2i]

var _color_to_tile_ID: Dictionary[int, int]

var _curr_obj_index: int
var _obj_names: Array[String]
var _obj_ids: Array[int]
var _curr_obj_preview: Texture2D
var _obj_id_to_index: Dictionary[int, int]

func _enter_tree():
	Editor.break_radius = 20
	_material_dock = DockScene.instantiate() 
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _material_dock) 
	_material_dock.material_selected.connect(_on_material_selected) 
	print("Material dock added:", _material_dock)
	var curr_scene := EditorInterface.get_edited_scene_root()
	
	if curr_scene:
		if curr_scene.name == TARGET_SCENE_PATH:
			#_try_connect_signal()
			_chunks = curr_scene.get_node_or_null("Chunk")
			if not _chunks:
				print("failed to get chunk_mng")
			else:
				_chunks.late_ready()
				_should_update = true
	
	self.main_screen_changed.connect(_on_work_place_changed)
	self.scene_changed.connect(_on_scene_changed)

func _process(delta: float) -> void:
	_timer += delta
	
	##TODO: Reimplementar o jeito de mudar de estado
	if Input.is_key_label_pressed(KEY_1):
		_change_state(EDITOR_STATE.terraform)
	elif Input.is_key_label_pressed(KEY_2):
		_change_state(EDITOR_STATE.select_chunk)
	elif Input.is_key_label_pressed(KEY_0):
		_change_state(EDITOR_STATE.unreachable)
	
	if !_should_update or _timer < RELOAD_TIME_SEC or not _chunks: return
	
	_timer = 0.0
	
	var curspor_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
	
	#var viewport_transform := EditorInterface.get_editor_viewport_2d().global_canvas_transform
	#print(viewport_transform.origin * viewport_transform.x.x)
	
	if _chunks._chunks_load_radius != _chunks._chunks_load_radius_editor:
		_chunks._chunks_load_radius = _chunks._chunks_load_radius_editor
	_chunks.load_nearby_chunks(curspor_pos)

func _handles(object: Object) -> bool:
	var mng: chunk_mng = object as chunk_mng
	return mng != null

func _change_state(new_state: EDITOR_STATE) -> void:
	if _curr_state == new_state: return
	print(EDITOR_STATE.keys()[int(new_state)])
	if new_state == EDITOR_STATE.select_chunk:
		_chunks_selected.clear()
	if new_state == EDITOR_STATE.terraform:
		Editor.set_num_tiles()
	_curr_state = new_state

#region state update

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var mouse_pos: Vector2 = EditorInterface.get_editor_viewport_2d().get_mouse_position()
	
	match _curr_state:
		EDITOR_STATE.terraform:
			update_overlays()
			return _terraform(event, mouse_pos)
		EDITOR_STATE.select_chunk:
			return _select_chunk(event, mouse_pos)
	
	return false

func _terraform(event: InputEvent, mouse_pos: Vector2) -> bool:
	var scroll_up := false
	var scroll_down := false
	var shift := false
	var click := false
	
	if event is InputEventMouseMotion:
		update_overlays() 
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_change_state(EDITOR_STATE.unreachable)
		scroll_up = event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed
		scroll_down = event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed
	
	click = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	shift = Input.is_key_pressed(KEY_SHIFT)
	
	Editor.terraform(scroll_up, scroll_down, shift, click, mouse_pos, _chunks)
	
	return true

func _select_chunk(event: InputEvent, mouse_pos: Vector2) -> bool:
	if event is InputEventMouseMotion:
		var new_chunk: Vector2i = chunk_mng.world_to_chunk_key(mouse_pos)
		if new_chunk != _curr_chunk_selected:
			_curr_chunk_selected = new_chunk
			update_overlays()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_change_state(EDITOR_STATE.unreachable)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.is_key_label_pressed(KEY_CTRL):
				delete_chunk()
			elif Input.is_key_label_pressed(KEY_SHIFT):
				create_new_chunk()
			else:
				if _chunks_selected.has(_curr_chunk_selected): _chunks_selected.erase(_curr_chunk_selected)
				else: _chunks_selected.append(_curr_chunk_selected)
		update_overlays()
	
	if event is InputEventKey:
		# Save chunk area as image
		if event.keycode == KEY_S and event.pressed and _chunks_selected.size() == 2:
			
			const max_lenght: int = 10
			
			var min_chunk: Vector2i
			var max_chunk: Vector2i
			if (_chunks_selected[0].x < _chunks_selected[1].x or 
			(_chunks_selected[0].x == _chunks_selected[1].x and 
			_chunks_selected[0].y < _chunks_selected[1].y)):
				min_chunk = _chunks_selected[0]
				max_chunk = _chunks_selected[1]
			else:
				min_chunk = _chunks_selected[1]
				max_chunk = _chunks_selected[0]
			
			var W: int = (max_chunk.x - min_chunk.x) + 1
			var H: int = (max_chunk.y - min_chunk.y) + 1
			
			if W > max_lenght or H > max_lenght:
				printerr("Image is too big")
				return true
			
			var img: Image = Image.create_empty(W * Globals.CHUNK_SIDE, H * Globals.CHUNK_SIDE, false, Image.FORMAT_RGB8)
			
			for x: int in range(min_chunk.x, max_chunk.x + 1):
				for y: int in range(min_chunk.y, max_chunk.y + 1):
					var curr_chunk: Vector2i = Vector2i(x, y)
					var offset_pixels: Vector2i = (curr_chunk - min_chunk) * Globals.CHUNK_SIDE
					var chunk_image: Image = get_chunk_image(curr_chunk)
					img.blit_rect(chunk_image, Rect2i(Vector2i(0,0), chunk_image.get_size()), offset_pixels)
			
			var name := "%d_%d=%d_%d" % [min_chunk.x, min_chunk.y, max_chunk.x, max_chunk.y]
			img.save_png("C:/Users/Henrique/Desktop/buffer" + "/" + name + ".png")
			print("Area saved")
		
		#load chunks from image
		elif event.keycode == KEY_L and event.pressed:
			var path_tarrain := "C:/Users/Henrique/Desktop/buffer"
			var dir: DirAccess = DirAccess.open(path_tarrain)
			if DirAccess.get_open_error():
				print("Error :(")
				return true
			
			for file_name: String in dir.get_files():
				if !file_name.ends_with(".png"): continue
				print("Loading chunks from image")
				decode_and_load_chunks_from_image(file_name)
	
	return true

func decode_and_load_chunks_from_image(file_name: String) -> void:
	_color_to_tile_ID = {}
	
	# --- NEW DICTIONARY GENERATION LOGIC ---
	# Helper lambda to map a color AND its neighbors (rounding errors) to the same ID
	var register_color = func(col: Color, id: int):
		_color_to_tile_ID[col.to_abgr32()] = id
		
		# 2. The "Floor" conversion (Truncation)
		# This catches your specific bug where 45.79 became 45 instead of 46
		var col_floor = Color.from_rgba8(int(col.r * 255), int(col.g * 255), int(col.b * 255), int(col.a * 255))
		_color_to_tile_ID[col_floor.to_abgr32()] = id
		
		# 3. The "Ceil" conversion (Safety net)
		var col_ceil = Color8(int(ceil(col.r * 255)), int(ceil(col.g * 255)), int(ceil(col.b * 255)), int(ceil(col.a * 255)))
		_color_to_tile_ID[col_ceil.to_abgr32()] = id

	# Register Black (for empty space)
	register_color.call(Color.BLACK, 0)
	register_color.call(Color(0,0,0,0), 0) # Handle transparent black if needed

	# Register your Palette
	for i: int in range(len(chunk_mng.tile_edge_colors)):
		register_color.call(chunk_mng.tile_edge_colors[i], i)
	
	print("Dictionary built with fuzzy keys: ", _color_to_tile_ID)
	# ---------------------------------------

	var path_tarrain := "C:/Users/Henrique/Desktop/buffer"
	var image: Image = Image.load_from_file(path_tarrain + "/" + file_name)
	# ... (Rest of your existing function remains exactly the same)
	file_name = file_name.replace(".png", "") # Note: 'trim_suffix' doesn't modify in place, fixed this line for you too
	
	var parts := file_name.split("=")
	var v1_parts := parts[0].split("_")
	var v2_parts := parts[1].split("_")
	
	var min_chunk := Vector2i(int(v1_parts[0]), int(v1_parts[1]))
	var max_chunk := Vector2i(int(v2_parts[0]), int(v2_parts[1]))
	
	var chunks_to_reload: Array[Vector2i] = []
	
	for x: int in range(min_chunk.x, max_chunk.x + 1):
		for y: int in range(min_chunk.y, max_chunk.y + 1):
			var curr_chunk: Vector2i = Vector2i(x, y)
			# ... The rest of your code is fine ...
			var offset_pixels: Vector2i = (curr_chunk - min_chunk) * Globals.CHUNK_SIDE
			var chunk_rect: Image = image.get_region(
				Rect2i((curr_chunk - min_chunk) * Globals.CHUNK_SIDE, 
				Vector2i(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE))
			)
			decode_single_chunk(chunk_rect, curr_chunk)
			chunks_to_reload.append(curr_chunk)
	
	_chunks._curr_center_chunk = Vector2i(0,0)
	
	for reload: Vector2i in chunks_to_reload:
		if !_chunks._chunks_dict.has(reload): continue
		var reload_instance := _chunks._chunks_dict[reload]
		var terrain_data: PackedByteArray = chunk_tile.decompress_chunk(chunk_tile.get_bytes(reload))
		assert(terrain_data.size() == Globals.CHUNK_SIZE)
		var terrain_image: Image = chunk_tile.create_texture_from_terrain_data(terrain_data)
		reload_instance.data = terrain_data
		reload_instance.img = terrain_image
		var sprite := ImageTexture.create_from_image(terrain_image)
		reload_instance.tex = sprite
		reload_instance.texture = sprite

func decode_single_chunk(chunk_image: Image, coords: Vector2i) -> void:
	if chunk_image.get_size() != Vector2i(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE):
		printerr("Error in encode_single_chunk for " + str(coords))
		return
	
	var data: PackedByteArray = []
	data.resize(Globals.CHUNK_SIZE)
	
	for x: int in range(Global.CHUNK_SIDE):
		for y: int in range(Global.CHUNK_SIDE):
			var tile_id := _color_to_tile_ID.get(chunk_image.get_pixel(x, y).to_abgr32(), -1)
			if tile_id == -1:
				printerr("Invalid tile at chunk " + str(coords) + str(Vector2(x, y)) + str(chunk_image.get_pixel(x, y).to_abgr32()))
				return
			data[y * Global.CHUNK_SIDE + x] = tile_id
	
	var target_path: String = chunk_mng.get_chunk_path(coords)
	var file_to_save: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if file_to_save:
		print("Saving")
		var compressed_data: PackedByteArray = chunk_tile.compress_chunk(data)
		file_to_save.store_buffer(compressed_data)
	else:
		print("Probem trying to save chunk " + str(coords))

func get_chunk_image(coords: Vector2i) -> Image:
	if _chunks._chunks_dict.has(coords):
		return _chunks._chunks_dict[coords].get_terrain_image()
	
	if FileAccess.file_exists(chunk_mng.get_chunk_path(coords)):
		var terrain_data: PackedByteArray = chunk_tile.decompress_chunk(chunk_tile.get_bytes(coords))
		if terrain_data.size() == Globals.CHUNK_SIZE:
			return chunk_tile.get_terrain_image_static(terrain_data)
		else:
			printerr("Failed to decompress chunk in map_editor" + str(coords))
	
	var image_empty: Image = Image.create_empty(Globals.CHUNK_SIDE, Globals.CHUNK_SIDE, false, Image.FORMAT_RGB8)
	image_empty.fill(Color.BLACK)
	return image_empty

func create_new_chunk() -> void:
	if FileAccess.file_exists(chunk_mng.get_chunk_path(_curr_chunk_selected)): return
	print("Creating chunk " + str(_curr_chunk_selected))
	_chunks.create_empty_chunk(_curr_chunk_selected)

func delete_chunk() -> void:
	var save_previous: bool = _chunks.save_on_exit
	_chunks.save_on_exit = false
	_chunks.unload_chunk(_curr_chunk_selected)
	_chunks.save_on_exit = save_previous
	
	#chunk terrain path
	var path: String = chunk_mng.get_chunk_path(_curr_chunk_selected)
	if !FileAccess.file_exists(path): return
	print("Deleting chunk " + str(_curr_chunk_selected))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	
	#chunk entities path
	path = chunk_tile.get_entities_map(_curr_chunk_selected)
	if !FileAccess.file_exists(path): return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

#endregion

#region state draw

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	match _curr_state:
		EDITOR_STATE.terraform:
			_terraform_draw(viewport_control)
		EDITOR_STATE.select_chunk:
			_select_chunk_draw(viewport_control)

func _terraform_draw(viewport_control: Control) -> void:
	var zoom: float = _get_editor_zoom_ammount()
	var radius: float = Editor.break_radius * zoom
	var rect_draw := Rect2(viewport_control.get_local_mouse_position(), Vector2(radius, radius))
	rect_draw.position -= rect_draw.size / 2
	viewport_control.draw_rect(rect_draw, Color.from_rgba8(255, 0, 255, 100))

func _select_chunk_draw(viewport_control: Control) -> void:
	var camera: Transform2D = EditorInterface.get_editor_viewport_2d().global_canvas_transform
	var zoom_ammount: float = _get_editor_zoom_ammount()
	
	for highlight: Vector2i in _chunks_selected:
		var chunk_top_left: Vector2 = highlight * Global.CHUNK_SIDE
		var screen_pos: Vector2 = camera * chunk_top_left
		var chunk_side_scaled: Vector2 = Vector2(Global.CHUNK_SIDE, Global.CHUNK_SIDE) * zoom_ammount
		viewport_control.draw_rect(
			Rect2(screen_pos, chunk_side_scaled),
			 Color(0.0, 0.84, 0.215, 0.5) if _chunks._chunks_dict.has(highlight) else Color(0.704, 0.001, 0.798, 0.5)
		)
	
	var chunk_top_left: Vector2 = _curr_chunk_selected * Global.CHUNK_SIDE
	var screen_pos: Vector2 = camera * chunk_top_left
	var chunk_side_scaled: Vector2 = Vector2(Global.CHUNK_SIDE, Global.CHUNK_SIDE) * zoom_ammount
	viewport_control.draw_rect(
		Rect2(screen_pos, chunk_side_scaled),
		 Color(0, 0, 1, 0.5) if _chunks._chunks_dict.has(_curr_chunk_selected) else Color(1, 0, 0, 0.5)
	)

#endregion

func _get_editor_zoom_ammount() -> float:
	return EditorInterface.get_editor_viewport_2d().get_final_transform().x.x

func _on_work_place_changed(screen_name: String) -> void:
	if screen_name != "2D": 
		_same_workplace = false
		unload_stuff()
	else:
		_same_workplace = true
		if not _chunks and _same_scene:
			var curr_scene := EditorInterface.get_edited_scene_root()
			_chunks = curr_scene.get_node_or_null("Chunk")
			_chunks.late_ready()
	
	_check_if_should_update()

func _on_scene_changed(scene_root: Node) -> void:
	if not scene_root:
		printerr("oops")
		_same_scene = false
		unload_stuff()
		_check_if_should_update()
		return
	if str(scene_root.name) != TARGET_SCENE_PATH:
		#unload_stuff()
		_same_scene = false
	else:
		_same_scene = true
		if not _chunks and _same_workplace:
			var curr_scene := EditorInterface.get_edited_scene_root()
			_chunks = curr_scene.get_node_or_null("Chunk")
			_chunks.late_ready()
	_check_if_should_update()

func _check_if_should_update() -> void:
	var before_update: bool = _should_update
	_should_update = _same_scene and _same_workplace
	if _should_update and !before_update:
		print("Updating now")
	self.set_process(_should_update)

func _on_material_selected(info) -> void:
	if info == null:
		Editor.curr_tile_index = 0 
		print("Editor tile cleared (set to index 0)")
		return

	var tile_name: String = info.id

	if tile_name in chunk_tile.TILE_TYPE:
		var tile_index: int = chunk_tile.TILE_TYPE[tile_name]
		Editor.curr_tile_index = tile_index
		print("Editor tile set to: '%s' (index %d)" % [tile_name, tile_index])
	else:
		push_error("Selected material '%s' does not exist in chunk_tile.TILE_TYPE!" % tile_name)

func unload_stuff() -> void:
	if not _chunks: return
	_chunks.unload_all_chunks()

func _clear() -> void:
	print("Clearing")
	unload_stuff()

func _exit_tree():
	unload_stuff()
	if _material_dock:
		remove_control_from_docks(_material_dock)
		_material_dock.queue_free()
		_material_dock = null
