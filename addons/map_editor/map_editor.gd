@tool
extends EditorPlugin

## N ativa o plugin ainda <<<<<<<<<

const ver = "1.7"

const TARGET_SCENE_PATH: String = "res://node_2d.tscn"
const INSTANCE_CHUNK_SCENE_PATH = "res://test.tscn"

var INSTANCIATE_CHUNK_INDEX: int = 1
var instance_tmp: Array[Node2D]

const RELOAD_TIME_MS: int = 2

var _timer: float = 0
var _chunk_scene: PackedScene

var _should_update: bool = true
var _same_scene: bool = true
var _same_workplace: bool = true

var _top_left

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree():
	if not _chunk_scene:
		print("chunk scene not found")
	self.main_screen_changed.connect(_on_work_place_changed)
	self.scene_changed.connect(_on_scene_changed)
	print(ver)

func _process(delta: float) -> void:
	_timer += delta
	
	if !_should_update or _timer < RELOAD_TIME_MS: return
	
	_timer = 0.0
	print("Buffering " + str(ver))
	
	var curspor_pos := EditorInterface.get_editor_viewport_2d().get_mouse_position()
	_top_left = curspor_pos
	
	var viewport := EditorInterface.get_editor_viewport_2d()
	var viewport_size := viewport.get_size()
	var camera_transform := viewport.get_canvas_transform()
	
	# The top-left corner of the visible area in world space
	var top_left := -camera_transform.origin
	
	# Convert the viewport size from screen to world coordinates
	var world_rect := Rect2(top_left, viewport_size * (1.0 / camera_transform.get_scale().x))
	
	print(world_rect)
	
	var buffer := _chunk_scene.instantiate() as Node2D
	var scene_root: Node2D = EditorInterface.get_edited_scene_root().get_child(INSTANCIATE_CHUNK_INDEX)
	if not buffer or not scene_root:
		printerr("Failed to instantiate chunk.")
		return
	
	buffer.position = _top_left
	buffer.name = "Buffer"
	
	scene_root.add_child(buffer)
	buffer.owner = scene_root
	instance_tmp.append(buffer)

func _on_work_place_changed(screen_name: String) -> void:
	if screen_name != "2D": 
		_same_workplace = false
		unload_stuff()
	else:
		print("Loading chunks")
		_same_workplace = true
	_check_if_should_update()

func _on_scene_changed(scene_root: Node) -> void:
	if not scene_root:
		print("oops")
		_same_scene = false
		_check_if_should_update()
		return
	print("chenged scene")
	if str(scene_root.get_path()) != TARGET_SCENE_PATH:
		print("Not same path")
		_same_scene = false
	else:
		_same_scene = true
		print("Same path :>")
	_check_if_should_update()

func _check_if_should_update() -> void:
	_should_update = _same_scene and _same_workplace

func unload_stuff() -> void:
	var target: Node2D = EditorInterface.get_edited_scene_root().get_child(INSTANCIATE_CHUNK_INDEX)
	if not target: return
	for n: Node in target.get_children():
		target.remove_child(n)

func _exit_tree():
	unload_stuff()
