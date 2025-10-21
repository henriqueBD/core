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

var _curr_obj_index: int
var _curr_obj_preview: Texture2D

var _obj_names: Array[String]

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

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
			_chunks = curr_scene.get_node_or_null("Chunk")
			if not _chunks:
				print("failed to get chunk_mng")
			else:
				_chunks.late_ready()
				_should_update = true
	
	if chunk_mng.obj_id_to_name.is_empty():
		printerr("Could not get objs list")
	else:
		for key: int in chunk_mng.obj_id_to_name.keys():
			_obj_names.append(chunk_mng.obj_id_to_name[key])
	
	self.main_screen_changed.connect(_on_work_place_changed)
	self.scene_changed.connect(_on_scene_changed)
	print("Ver: " + str(ver))

func _process(delta: float) -> void:
	_timer += delta
	
	if Input.is_key_label_pressed(KEY_1):
		_change_state(EDITOR_STATE.place_obj)
	elif Input.is_key_label_pressed(KEY_2):
		_change_state(EDITOR_STATE.terraform)
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
	var img_tmp: Image = Image.new()
	var obj_name := _obj_names[_curr_obj_index]
	var path := Global.objs_path + obj_name + "/" + obj_name + "_preview.png"
	var error := img_tmp.load(path)
	if error != OK:
		push_error("Failed to load image at path: %s" % path)
		return
	_curr_obj_preview = ImageTexture.create_from_image(img_tmp)

func _place_obj(event: InputEvent, mouse_pos: Vector2) -> bool:
	var leave: bool = false
	
	if event is InputEventMouseButton:
		leave = event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	
	return !leave

#endregion

#region state draw

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	match _curr_state:
		EDITOR_STATE.place_obj:
			_place_obj_draw(viewport_control)
		EDITOR_STATE.terraform:
			_terraform_draw(viewport_control)

func _terraform_draw(viewport_control: Control) -> void:
	var zoom: float = _get_editor_zoom_ammount()
	var radius: float = Editor.break_radius * zoom
	var rect_draw := Rect2(viewport_control.get_local_mouse_position(), Vector2(radius, radius))
	rect_draw.position -= rect_draw.size / 2
	viewport_control.draw_rect(rect_draw, Color.from_rgba8(255, 0, 255, 100))

func _place_obj_draw(viewport_control: Control) -> void:
	var zoom: float = _get_editor_zoom_ammount()
	if _curr_obj_preview:
		var texture_size: Vector2 = _curr_obj_preview.get_size() * zoom
		var mouse_pos: Vector2 = viewport_control.get_local_mouse_position()
		var draw_pos: Vector2 = mouse_pos - texture_size * 0.5
		var rect := Rect2(draw_pos, texture_size)
		viewport_control.draw_texture_rect(_curr_obj_preview, rect, false)

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
