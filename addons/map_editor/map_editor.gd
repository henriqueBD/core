@tool
extends EditorPlugin

const ver = "1.8"

const TARGET_SCENE_PATH: String = "Game"

var _chunks: chunk_mng

const RELOAD_TIME_SEC: float = 0.25

var _timer: float = 0
var _chunk_scene: PackedScene

var _should_update: bool = false
var _same_scene: bool = true
var _same_workplace: bool = true

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree():
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
		_check_if_should_update()
		return
	print("chenged scene")
	if str(scene_root.name) != TARGET_SCENE_PATH:
		print("Not same path")
		_same_scene = false
	else:
		_same_scene = true
		if not _chunks and _same_workplace:
			var curr_scene := EditorInterface.get_edited_scene_root()
			_chunks = curr_scene.get_node_or_null("Chunk")
			_chunks.late_ready()
	_check_if_should_update()

func _check_if_should_update() -> void:
	_should_update = _same_scene and _same_workplace

func unload_stuff() -> void:
	if not _chunks: return
	_chunks.unload_all_chunks()

func _exit_tree():
	unload_stuff()
