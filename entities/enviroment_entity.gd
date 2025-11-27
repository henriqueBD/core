extends Area2D

enum type {
	GROUNDED,
	HANGING,
	BURIED,
	FLOATING,
}

@export var terrain_relation: type

@onready var _collision_shape_2d: CollisionShape2D = $CollisionShape2D

var _main_chunk: chunk_tile
var _global_bounds: Rect2i
var _destroy_check_X: int
var _destroy_check_Y: int

func _ready() -> void:
	_global_bounds = _collision_shape_2d.shape.get_rect() as Rect2i
	_global_bounds.position = self.to_global(_global_bounds.position) as Vector2i
	_main_chunk = Global.chunks.world_to_chunk(self.global_position)
	
	var local_coords: Vector2i = _main_chunk.world_to_grid(
		Vector2(_global_bounds.position.x, _global_bounds.position.y + _global_bounds.size.y)
	)
	_destroy_check_X = local_coords.x
	_destroy_check_Y = local_coords.y
	
	Global.terrain_break.connect(_on_terrain_break)

func _on_terrain_break(destroy_bounds: Rect2i) -> void:
	if _should_destroy(destroy_bounds):
		_destroy()

func _should_destroy(destroy_bounds: Rect2i) -> bool:
	#try skip check
	if !destroy_bounds.intersects(_global_bounds): return false
	
	for X: int in range(_destroy_check_X, _destroy_check_X + _global_bounds.size.x):
		if _main_chunk._get_tile_safe(X, _destroy_check_Y) != chunk_tile.TILE_TYPE.AIR: 
			return false
	
	return true

func _destroy() -> void:
	queue_free()
