extends Area2D

enum type {
	GROUNDED,
	HANGING,
	BURIED,
}

@export var terrain_relation: type

@onready var _collision_shape_2d: CollisionShape2D = $CollisionShape2D

var _main_chunk: chunk_tile
var _global_bounds: Rect2i
var _destroy_check: Rect2i

func _ready() -> void:
	_global_bounds = _collision_shape_2d.shape.get_rect() as Rect2i
	_global_bounds.position = self.to_global(_global_bounds.position) as Vector2i
	
	_main_chunk = Global.chunks.world_to_chunk(self.global_position)
	
	match terrain_relation:
		type.GROUNDED:
			_destroy_check = Rect2i(
				_global_bounds.position.x, _global_bounds.position.y + _global_bounds.size.y,
				_global_bounds.size.x, 1
			)
		type.HANGING:
			_destroy_check = Rect2i(
				_global_bounds.position.x, _global_bounds.position.y,
				_global_bounds.size.x, 1
			)
		type.BURIED:
			_destroy_check = _global_bounds
	
	Global.terrain_break.connect(_on_terrain_break)

func _on_terrain_break(destroy_bounds: Rect2i) -> void:
	if _should_destroy(destroy_bounds):
		_destroy()

func _should_destroy(destroy_bounds: Rect2i) -> bool:
	return destroy_bounds.intersects(_destroy_check)

func _destroy() -> void:
	Global.chunks.set_no_respawn(global_position)
	queue_free()
