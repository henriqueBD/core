@tool
extends VBoxContainer

signal material_selected(info)


const TERRAIN_PATH := "res://terrain_types/terrain_sprites/"

var tile_size: int = 64
var padding: int = 6

var _grid: GridContainer

func _ready() -> void:
	# === Title ===
	var title := Label.new()
	title.text = "Map Tools"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# === Scroll + Grid ===
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(180, 220)
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.name = "grid"
	scroll.add_child(_grid)

	# === Load terrain textures ===
	_load_terrain_textures(_grid)

	# === Bottom bar ===
	var bottom := HBoxContainer.new()
	bottom.name = "bottom"
	bottom.custom_minimum_size = Vector2(0, 32)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(bottom)

	var sel_label := Label.new()
	sel_label.name = "sel_label"
	sel_label.text = "Selected: —"
	sel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sel_label)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	bottom.add_child(clear_btn)

	connect("resized", _on_size_changed)


# -------------------------------------------------------------------
# LOADERS AND HELPERS
# -------------------------------------------------------------------

func _load_terrain_textures(grid: GridContainer) -> void:
	var dir := DirAccess.open(TERRAIN_PATH)
	if dir == null:
		push_error("Could not open terrain directory: %s" % TERRAIN_PATH)
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			var tex_path := "%s/%s" % [TERRAIN_PATH, file]
			var tex: Texture2D = load(tex_path)  # safe now
			if tex:
				_add_texture_button(grid, file.get_basename(), tex, tex_path)
		file = dir.get_next()
	dir.list_dir_end()


func _add_texture_button(grid: GridContainer, name: String, tex: Texture2D, path: String) -> void:
	var tb := TextureButton.new()
	tb.focus_mode = Control.FOCUS_NONE
	tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tb.custom_minimum_size = Vector2(tile_size + padding * 2, tile_size + padding * 2)
	tb.texture_normal = tex
	tb.tooltip_text = name

	tb.set_meta("info", {"id": name, "kind": "material", "path": path})
	tb.pressed.connect(_on_item_pressed.bind(tb))
	grid.add_child(tb)


# -------------------------------------------------------------------
# SIGNAL HANDLERS
# -------------------------------------------------------------------

func _on_item_pressed(tb: TextureButton) -> void:
	var info = tb.get_meta("info")
	emit_signal("material_selected", info)
	_update_selected_label(info)

func _on_clear_pressed() -> void:
	emit_signal("material_selected", null)
	_update_selected_label(null)

func _update_selected_label(info) -> void:
	var lbl: Label = get_node("bottom/sel_label")
	lbl.text = "Selected: %s" % info.id if info else "Selected: —"

func _on_size_changed() -> void:
	if _grid.get_child_count() == 0: return
	
	var button := _grid.get_child(0) as TextureButton
	if !button: return
	
	var button_size: float = button.size.x
	var new_colums: int = max(size.x / button_size, 1)
	
	if _grid.columns != new_colums:
		_grid.columns = new_colums
