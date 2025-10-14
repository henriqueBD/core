class_name CollisionObj
extends Node2D

var _global_bounds: Rect2

var above_collision: bool = false
var below_collision: bool = false
var left_collision: bool = false
var right_collision: bool = false

# A small buffer distance to cast rays from inside the collider.
const _SKIN_WIDTH: float = 2

var _active: bool = true
var check_collisions_while_deactivated: bool = false

# The number of rays to cast, calculated at runtime.
var _horizontal_ray_count: int
var _vertical_ray_count: int

var _vertical_ray_spacing: float
var _horizontal_ray_spacing: float

# Cached corner positions of the bounds.
var _bottom_right: Vector2
var _bottom_left: Vector2
var _top_right: Vector2
var _top_left: Vector2

## Spacing between rays.
#var _horizontal_spacing: float
#var _vertical_spacing: float

var _terrain: chunk_mng
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _parent: Node2D = self.get_parent()

const no_collision: float = -INF

func _ready() -> void:
	_terrain = Global.chunks
	assert(_terrain != null)
	assert(collision_shape != null)
	
	change_rect(collision_shape.shape.get_rect())
	
	remove_child(collision_shape)
	collision_shape.queue_free()

## PUBLIC MOVEMENT METHOD ##

func activate() -> void:
	_active = true

func deactivate() -> void:
	_reset_collisions()
	_active = false

func move(velocity: Vector2) -> void:
	if _active:
		_reset_collisions()
		
		if velocity == Vector2.ZERO:return
		
		_update_bounds()
		
		if velocity.x != 0.0: velocity = _horizontal_collisions(velocity)
		if velocity.y != 0.0: velocity.y = _vertical_collisions(velocity.y)
		
	elif check_collisions_while_deactivated:
		_reset_collisions()
		
		if velocity == Vector2.ZERO: return
		
		_update_bounds()
		
		if velocity.x != 0.0: _horizontal_collisions(velocity)
		if velocity.y != 0.0: _vertical_collisions(velocity.y)
	
	_global_bounds.position += velocity
	_parent.position += velocity

func teleport(new_pos: Vector2) -> void:
	_global_bounds.position = new_pos

func change_rect(new_rect: Rect2) -> void:
	_global_bounds.size = round(new_rect.size)
	_global_bounds.position = to_global(new_rect.position)
	_update_bounds()
	_reset_collisions()

	# Dynamically calculate ray counts based on the collider size and terrain pixel size.
	_vertical_ray_count = ceil(_global_bounds.size.x)
	_horizontal_ray_count = ceil(_global_bounds.size.y)

	var rect_tmp: Rect2 = _global_bounds.grow(-_SKIN_WIDTH)
	
	# vertical collision sweep in the horizontal axis and vice versa
	_vertical_ray_spacing = rect_tmp.size.x / float(_vertical_ray_count - 1)
	_horizontal_ray_spacing = rect_tmp.size.y / float(_horizontal_ray_count - 1)

## INTERNAL LOGIC ##

#region Collision Calculation

func _vertical_collisions(y_dir: float) -> float:
	if sign(y_dir) == 1.0: # moving down
		var len_ray: int = ceili(y_dir + _SKIN_WIDTH)
		for i: int in range(_vertical_ray_count):
			var col_point_y: float = _terrain.raycast_down_world(_bottom_left + (i * _vertical_ray_spacing * Vector2.RIGHT), len_ray)
			if col_point_y != no_collision:
				below_collision = true
				var dist: float = col_point_y - _bottom_left.y - _SKIN_WIDTH
				y_dir = dist
				len_ray = ceili(dist)
	else: #moving up
		var len_ray: int = ceili(abs(y_dir) + _SKIN_WIDTH)
		for i: int in range(_vertical_ray_count):
			var col_point_y: float = _terrain.raycast_up_world(_top_left + (i * _vertical_ray_spacing * Vector2.RIGHT), len_ray)
			if col_point_y != no_collision:
				above_collision = true
				var dist: float = _top_right.y - col_point_y - _SKIN_WIDTH
				y_dir = -dist
				len_ray = ceili(dist)
	
	return y_dir


## TODO: replace quick hack for ascending slopes
const slope_tolerance: int = 3
func _horizontal_collisions(xy_dir: Vector2) -> Vector2:
	
	var x_dir: float = xy_dir.x
	var max_collision_point: float = -1
	
	if sign(x_dir) == 1.0:
		var len_ray: int = ceili(x_dir + _SKIN_WIDTH)
		for i: int in range(slope_tolerance, _horizontal_ray_count):
			var col_point_x: float = _terrain.raycast_right_world(_bottom_right + (i * _horizontal_ray_spacing * Vector2.UP), len_ray)
			if col_point_x != no_collision:
				max_collision_point = i
				right_collision = true
				var dist: float = col_point_x - _bottom_right.x - _SKIN_WIDTH
				x_dir = dist
				len_ray = ceili(dist)
	else:
		var len_ray: int = ceili(abs(x_dir) + _SKIN_WIDTH)
		for i: int in range(slope_tolerance, _horizontal_ray_count):
			var col_point_x: float = _terrain.raycast_left_world(_bottom_left + (i * _horizontal_ray_spacing * Vector2.UP), len_ray)
			if col_point_x != no_collision:
				max_collision_point = i
				left_collision = true
				var dist: float = _bottom_left.x - col_point_x - _SKIN_WIDTH
				x_dir = -dist
				len_ray = ceili(dist)
	
	xy_dir.x = x_dir
	return xy_dir

#endregion

func _update_bounds() -> void:
	var collision_rect: Rect2 = _global_bounds.grow(-_SKIN_WIDTH)
	_top_left = collision_rect.position
	_top_right = Vector2(collision_rect.position.x + collision_rect.size.x, collision_rect.position.y)
	_bottom_left = Vector2(collision_rect.position.x, collision_rect.position.y + collision_rect.size.y)
	_bottom_right = collision_rect.position + collision_rect.size

func _reset_collisions() -> void:
	above_collision = false
	below_collision = false
	left_collision = false
	right_collision = false

#func _draw() -> void:
	#_draw_point(_top_left)
	#_draw_point(_top_right)
	#_draw_point(_bottom_right)
	#_draw_point(_bottom_left)
	#
#func _draw_point(point: Vector2) -> void:
	#point = to_local(point)
	#draw_line(point, Vector2(point.x, point.y+1), Color.RED, 2, false)
