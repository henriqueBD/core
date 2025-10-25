@tool
extends EditorPlugin

const ver = "1.8"

const TARGET_SCENE_PATH: String = "Game"

var _chunks: chunk_mng

const DockScene = preload("res://addons/map_editor/material_dock.tscn")
var _material_dock: Control = null

const RELOAD_TIME_SEC: float = 0.25

enum EDITOR_STATE {
	unreachable,
	place_obj,
	terraform,
	add_chunk,
}

var _curr_state: EDITOR_STATE = EDITOR_STATE.terraform

var _timer: float = 0
var _chunk_scene: PackedScene

var _should_update: bool = false
var _same_scene: bool = true
var _same_workplace: bool = true

var _curr_chunk_selected: Vector2i

# -============================(v)================================- #
## Utilize o dict chunk_mng.obj_id_to_name[id: int] para (id -> nome)
## Utilize chunk_mng.hash_string(nome: String) para (nome -> id)
## _obj_names e _obj_ids devem ser acessados apenas pelo _curr_obj_index
# -============================(^)================================- #

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
	
	if not curr_scene:
		print("Fail 1")
	else:
		if curr_scene.name != TARGET_SCENE_PATH:
			print("Fail 2")
		else:
			#_try_connect_signal()
			_chunks = curr_scene.get_node_or_null("Chunk")
			if not _chunks:
				print("failed to get chunk_mng")
			else:
				_chunks.late_ready()
				_should_update = true
	
	if !chunk_mng.obj_id_to_name.is_empty():
		_load_obj_list()
	
	self.main_screen_changed.connect(_on_work_place_changed)
	self.scene_changed.connect(_on_scene_changed)
	print("Ver: " + str(ver))

func _process(delta: float) -> void:
	_timer += delta
	
	##TODO: Reimplementar o jeito de mudar de estado
	if Input.is_key_label_pressed(KEY_1):
		_change_state(EDITOR_STATE.terraform)
	elif Input.is_key_label_pressed(KEY_2):
		_change_state(EDITOR_STATE.add_chunk)
	elif Input.is_key_label_pressed(KEY_0):
		_change_state(EDITOR_STATE.unreachable)
	
	if !_should_update or _timer < RELOAD_TIME_SEC or not _chunks: return
	
	_timer = 0.0
	
	var curspor_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
	_chunks.load_nearby_chunks(curspor_pos)

func _handles(object: Object) -> bool:
	var mng: chunk_mng = object as chunk_mng
	return mng != null

func _change_state(new_state: EDITOR_STATE) -> void:
	if _curr_state == new_state: return
	print(EDITOR_STATE.keys()[int(new_state)])
	match new_state:
		EDITOR_STATE.place_obj:
			_place_obj_enter()
	
	_curr_state = new_state

#region state update

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var mouse_pos: Vector2 = EditorInterface.get_editor_viewport_2d().get_mouse_position()
	
	match _curr_state:
		EDITOR_STATE.place_obj:
			update_overlays()
			return _place_obj(event, mouse_pos)
		EDITOR_STATE.terraform:
			update_overlays()
			return _terraform(event, mouse_pos)
		EDITOR_STATE.add_chunk:
			return _add_chunk(event, mouse_pos)
	
	return false

func _terraform(event: InputEvent, mouse_pos: Vector2) -> bool:
	var scroll_up := false
	var scroll_down := false
	var shift := false
	var click := false
	var leave := false

	if event is InputEventMouseMotion:
		update_overlays() 

	if event is InputEventMouseButton:
		scroll_up = event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed
		scroll_down = event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed
		
		leave = (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed or
				 event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed)

	click = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	shift = Input.is_key_pressed(KEY_SHIFT)

	Editor.terraform(scroll_up, scroll_down, shift, click, mouse_pos, _chunks)
	if scroll_up or scroll_down or click or (event is InputEventMouseMotion and click):
		return true

	if leave:
		return false
	
	return false

func _place_obj_enter() -> void:
	_change_selected_obj(_obj_names[clamp(_curr_obj_index, 0, len(_obj_names)-1)])

func _place_obj(event: InputEvent, mouse_pos: Vector2) -> bool:
	var leave: bool = false
	
	if event is InputEventKey:
		if event.keycode == KEY_P and event.pressed:
			_curr_obj_index = (_curr_obj_index + 1) % len(_obj_names)
			_change_selected_obj(_obj_names[_curr_obj_index])
	
	if event is InputEventMouseButton:
		leave = event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
		
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_chunks.add_object_viewport(floor(mouse_pos), _obj_ids[_curr_obj_index])
	
	return !leave

## Importante
func _change_selected_obj(obj_name: String) -> void:
	var img_tmp: Image = Image.new()
	var path := Global.objs_path + obj_name + "/" + obj_name + "_preview.png"
	var error := img_tmp.load(path)
	if error != OK:
		push_error("Failed to load image at path: %s" % path)
		return
	_curr_obj_preview = ImageTexture.create_from_image(img_tmp)
	_curr_obj_index = _obj_id_to_index[chunk_mng.hash_string(obj_name)]

func _add_chunk(event: InputEvent, mouse_pos: Vector2) -> bool:
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_change_state(EDITOR_STATE.unreachable)
	
	if event is InputEventMouseMotion:
		var new_chunk: Vector2i = chunk_mng.world_to_chunk_key(mouse_pos)
		if new_chunk != _curr_chunk_selected:
			_curr_chunk_selected = new_chunk
			update_overlays()
	
	return true

#endregion

#region state draw

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	match _curr_state:
		EDITOR_STATE.place_obj:
			_place_obj_draw(viewport_control)
		EDITOR_STATE.terraform:
			_terraform_draw(viewport_control)
		EDITOR_STATE.add_chunk:
			_add_chunk_draw(viewport_control)

func _terraform_draw(viewport_control: Control) -> void:
	var zoom: float = _get_editor_zoom_ammount()
	var radius: float = Editor.break_radius * zoom
	var rect_draw := Rect2(viewport_control.get_local_mouse_position(), Vector2(radius, radius))
	rect_draw.position -= rect_draw.size / 2
	viewport_control.draw_rect(rect_draw, Color.from_rgba8(255, 0, 255, 100))

# Improvements: change the filtering to remove blurring, snap the position to pixels
func _place_obj_draw(viewport_control: Control) -> void:
	var zoom: float = _get_editor_zoom_ammount()
	if _curr_obj_preview:
		var texture_size: Vector2 = _curr_obj_preview.get_size() * zoom
		var draw_pos: Vector2 = viewport_control.get_local_mouse_position() - texture_size * 0.5
		var rect := Rect2(draw_pos, texture_size)
		viewport_control.draw_texture_rect(_curr_obj_preview, rect, false)

func _add_chunk_draw(viewport_control: Control) -> void:
	var chunk_top_left: Vector2 = _curr_chunk_selected * Global.CHUNK_SIDE
	var camera: Transform2D = EditorInterface.get_editor_viewport_2d().global_canvas_transform

	print(camera)
	# Convert the global position (chunk's top-left corner) to screen position
	var screen_pos: Vector2 = camera * chunk_top_left
	# Draw the rectangle in the screen space
	# Assuming you want to draw on the `viewport_control` canvas:
	var chunk_side_scaled: Vector2 = Vector2(Global.CHUNK_SIDE, Global.CHUNK_SIDE) * _get_editor_zoom_ammount()
	viewport_control.draw_rect(
		Rect2(screen_pos, chunk_side_scaled),
		 Color(0, 0, 1, 0.5) if _chunks.chunksDict.has(_curr_chunk_selected) else Color(1, 0, 0, 0.5)
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
			_load_obj_list()
	
	_check_if_should_update()

func _on_scene_changed(scene_root: Node) -> void:
	if not scene_root:
		print("oops")
		_same_scene = false
		unload_stuff()
		_check_if_should_update()
		return
	print("changed scene")
	if str(scene_root.name) != TARGET_SCENE_PATH:
		print("Not same path")
		unload_stuff()
		_same_scene = false
	else:
		#_try_connect_signal()
		_same_scene = true
		if not _chunks and _same_workplace:
			var curr_scene := EditorInterface.get_edited_scene_root()
			_chunks = curr_scene.get_node_or_null("Chunk")
			_chunks.late_ready()
			_load_obj_list()
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

func _load_obj_list() -> void:
	if chunk_mng.obj_id_to_name.is_empty():
		printerr("obj list is empty")
		return
	_obj_id_to_index = {}
	_obj_ids = chunk_mng.obj_id_to_name.keys()
	for i: int in range(len(_obj_ids)):
		_obj_names.append(chunk_mng.obj_id_to_name[_obj_ids[i]])
		_obj_id_to_index[_obj_ids[i]] = i

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
