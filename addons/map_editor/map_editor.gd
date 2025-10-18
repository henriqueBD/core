@tool
extends EditorPlugin

const ver = "1.8"

const TARGET_SCENE_PATH: String = "Game"

var _chunks: chunk_mng

const RELOAD_TIME_SEC: float = 0.25

enum EDITOR_STATE {
	unreachable,
	place_obj,
	delete_obj,
	terraform,
	add_chunk,
}

var _curr_state: EDITOR_STATE = EDITOR_STATE.terraform

var _timer: float = 0
var _chunk_scene: PackedScene

var _should_update: bool = false
var _same_scene: bool = true
var _same_workplace: bool = true

var _curr_draw

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree():
	Editor.break_radius = 20
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
	
	self.main_screen_changed.connect(_on_work_place_changed)
	self.scene_changed.connect(_on_scene_changed)
	print("Ver: " + str(ver))

func _process(delta: float) -> void:
	_timer += delta
	
	if !_should_update or _timer < RELOAD_TIME_SEC or not _chunks: return
	
	_timer = 0.0
	
	var curspor_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
	_chunks.load_nearby_chunks(curspor_pos)

func _handles(object: Object) -> bool:
	var mng: chunk_mng = object as chunk_mng
	return mng != null

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var mouse_pos: Vector2 = EditorInterface.get_editor_viewport_2d().get_mouse_position()
	if !_chunks.is_chunk_loaded(mouse_pos) or mouse_pos.x < 0 or mouse_pos.y < 0: return false
	
	#match _curr_state:
		#EDITOR_STATE.terraform:
			#return _terraform(event, mouse_pos)
		#null:
			#_curr_state = EDITOR_STATE.terraform
	return _terraform(event, mouse_pos)
	
	return false

func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	match _curr_state:
		EDITOR_STATE.terraform:
			_terraform_draw(viewport_control)

# TODO: problema com o scroll (zoom no editor e muda de tile ao msm tempo)
func _terraform(event: InputEvent, mouse_pos: Vector2) -> bool:
	var scroll_up: bool
	var scroll_down: bool
	var shift: bool
	var click: bool
	var leave: bool = false
	if event is InputEventMouseMotion:
		update_overlays()
	if event is InputEventMouseButton:
		scroll_up = event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed
		scroll_down = event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed
		leave = (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed or 
				event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed)
	click = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	shift = Input.is_key_pressed(KEY_SHIFT)
	Editor.terraform(scroll_up, scroll_down, shift, click, mouse_pos, 20, _chunks)
	return !leave

var brush_size_pixels: int = 20

func _terraform_draw(viewport_control: Control) -> void:
	#viewport_control.draw_circle(viewport_control.get_local_mouse_position(), 64, Color.from_rgba8(255, 0, 255, 100))
	pass

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
	print("chenged scene")
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

func unload_stuff() -> void:
	if not _chunks: return
	_chunks.unload_all_chunks()

func _clear() -> void:
	print("Clearing")
	unload_stuff()

func _exit_tree():
	unload_stuff()
