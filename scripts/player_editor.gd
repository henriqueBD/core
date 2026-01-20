class_name Editor
extends CanvasItem

@onready var parent: Node2D = self.get_parent()
static var chunk: chunk_mng

enum EDITOR_STATE {
	unreachable,
	place_obj,
	delete_obj,
	terraform,
	add_chunk,
}

static var curr_update: EDITOR_STATE = EDITOR_STATE.place_obj
static var is_active: bool = false

static var num_tiles: int = 0

static var curr_obj_index: int = 0
static var curr_obj: PackedScene
static var curr_obj_instance: Node2D

static var obj_name_list: Array[String]
static var obj_name_hash: Array[int]

static var break_radius: int = 20

static var cursor_position: Vector2

func _ready() -> void:
	set_num_tiles()
	if OS.has_feature("editor"):
		print("Debug allowed")
	else:
		print("level editor only on engine")
		curr_update = EDITOR_STATE.unreachable
		self.set_script(null)
		return
	
	populate_obj_arrays()
	
	chunk = Global.chunks
	chunk.late_ready()

static func set_num_tiles() -> void:
	num_tiles = chunk_tile.TILE_TYPE.keys().size()

static func populate_obj_arrays() -> void:
	var dir: DirAccess = DirAccess.open(Global.objs_path)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var id_to_name_tmp: Dictionary[int, String] = {}
	while file_name != "":
		if dir.current_is_dir():
			obj_name_list.append(file_name)
			#var hash_id: int = hash(file_name)
			var hash_id: int = Entity_loader.hash_string(file_name)
			obj_name_hash.append(hash_id)
			id_to_name_tmp[hash_id] = file_name
		file_name = dir.get_next()
	dir.list_dir_end()
	if chunk: chunk.id_to_name = id_to_name_tmp
	print(obj_name_hash)

func activate() -> void:
	curr_obj = load(get_obj_scene_path(get_curr_obj_name()))
	curr_obj_instance = curr_obj.instantiate()
	add_child(curr_obj_instance)

func deactivate() -> void:
	remove_child(curr_obj_instance)

func reload() -> void:
	deactivate()
	activate()

func update() -> void:
	cursor_position = floor(get_global_mouse_position())
	
	if Input.is_action_just_pressed("editor_place_obj_toggle"):
		change_state(EDITOR_STATE.place_obj)
	elif Input.is_action_just_pressed("editor_add_chunk_toggle"):
		change_state(EDITOR_STATE.add_chunk)
	elif Input.is_action_just_pressed("editor_terraform"):
		change_state(EDITOR_STATE.terraform)
	
	_move()
	match curr_update:
		EDITOR_STATE.place_obj:
			place_objects()
		EDITOR_STATE.delete_obj:
			delete_object()
		EDITOR_STATE.terraform:
			_terraform_game()
		EDITOR_STATE.add_chunk:
			add_chunk()

func change_state(new: EDITOR_STATE) -> void:
	
	match curr_update:
		EDITOR_STATE.unreachable:
			return
		EDITOR_STATE.place_obj:
			curr_obj_instance.hide()
	
	match new:
		EDITOR_STATE.place_obj:
			curr_obj_instance.show()
		EDITOR_STATE.delete_obj:
			curr_obj_instance.hide()
	
	curr_update = new

func _move() -> void:
	var horizontal_input: float = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var vertical_input: float = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	parent.global_position += Vector2(horizontal_input * 0.5, vertical_input * 0.5)

func place_objects() -> void:
	
	curr_obj_instance.global_position = cursor_position
	if Input.is_key_pressed(KEY_SHIFT):
		change_state(EDITOR_STATE.delete_obj)
		return
	
	if Input.is_action_just_pressed("place_object"):
		print("Placing %s at %s" % [get_curr_obj_name(), str(cursor_position)])
		var obj_to_add: Node2D = curr_obj.instantiate()
		obj_to_add.global_position = cursor_position
		chunk.add_object_chunk(cursor_position, obj_to_add, obj_name_hash[curr_obj_index])
	
	if Input.is_action_just_pressed("scroll_up"):
		curr_obj_index += 1
		if curr_obj_index == len(obj_name_list):
			curr_obj_index = 0
		print(get_curr_obj_name())
		reload()
	elif Input.is_action_just_pressed("scroll_down"):
		curr_obj_index -= 1
		if curr_obj_index < 0:
			curr_obj_index = len(obj_name_list) - 1
		reload()

func get_obj_scene_path(obj_name: String) -> String:
	return Global.objs_path + obj_name + "/" + obj_name + ".tscn"

func get_curr_obj_name() -> String:
	return obj_name_list[curr_obj_index]

func delete_object() -> void:
	if !Input.is_key_pressed(KEY_SHIFT):
		change_state(EDITOR_STATE.place_obj)
		return
	if Input.is_action_just_pressed("place_object"):
		pass

func move_object() -> void:
	if !Input.is_key_pressed(KEY_SHIFT):
		change_state(EDITOR_STATE.place_obj)
		return

## TERRAFORM

static var curr_tile_index: int = 0
static var tile_hot_bar: Array[int] = [0, 1, 2, 3 ,4 ,5 ,6 ,7 ,8 ,9]
const hot_bar: Array[int] = [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

func _terraform_game() -> void:
	terraform(
		Input.is_action_just_pressed("scroll_up"), 
		Input.is_action_just_pressed("scroll_down"),
		Input.is_key_pressed(KEY_SHIFT),
		Input.is_action_pressed("place_object"),
		cursor_position
	)

static func terraform(scroll_up: bool, scroll_down: bool, shift: bool, 
	mouse_hold: bool, cursor_pos: Vector2, chunk_m: chunk_mng = chunk) -> int:
	
	if shift:
		if scroll_up:
			break_radius += 1
			break_radius = min(255, break_radius)
			print("Brush radius: " + str(break_radius))
		elif scroll_down:
			break_radius -= 1
			break_radius = max(1, break_radius)
			print("Brush radius: " + str(break_radius))
	
	if mouse_hold:
		#if curr_tile_index < 0 or curr_tile_index >= num_tiles:
			#print("Invalid tile with index: " + str(curr_tile_index))
			#return break_radius
		
		var brush_size: Vector2 = Vector2(break_radius, break_radius)
		
		if Input.is_key_pressed(KEY_ALT):
			chunk_m.change_tiles(Rect2(cursor_pos - brush_size / 2, brush_size), 0)
		else:
			chunk_m.change_tiles(Rect2(cursor_pos - brush_size / 2, brush_size), curr_tile_index)
	
	return break_radius

func terraform_render() -> void:
	var icon_size: Vector2 = Vector2(break_radius, break_radius)
	var brush_rect: Rect2 = Rect2(cursor_position - icon_size / 2, icon_size)
	draw_rect(brush_rect, Color.from_rgba8(255,0,100,100))

## ADD CHUNK

func add_chunk() -> void:
	if Input.is_action_just_pressed("place_object"):
		var coords: Vector2i = chunk_mng.world_to_chunk_key(cursor_position)
		chunk.createEmptyChunk(coords)

static func terraform_from_plugin(material_info: Dictionary, mouse_pos: Vector2, b_radius: int, chunk_m: chunk_mng) -> void:
	if not material_info or not chunk_m:
		return

	var tile_to_paint: int = int(material_info.id)

	var brush_size: Vector2 = Vector2(b_radius, b_radius)
	
	if Input.is_key_pressed(KEY_ALT):
		chunk_m.change_tiles(Rect2(mouse_pos - brush_size / 2, brush_size), 0)
	else:
		chunk_m.change_tiles(Rect2(mouse_pos - brush_size / 2, brush_size), tile_to_paint)
