extends Area2D

const MAX_FALLING_SEC: float = 10
const DESTROY_AFTER_TOUCH_SEC: float = 0.2
const FALLING_SPEED: float = 120
const BREAK_FORCE: int = 2

static var TERRAIN_DESTROY_MASK: BitMap = TerrainBreaker.create_bitmap("res://entities/falling_spike_big/big_spike_destroy_mask.png")

var _timer_self_destroy: float = 0.0
var _timer_touch: float = 0.0
var _breaker: TerrainBreaker = TerrainBreaker.new()
var _chunks: chunk_mng

@onready var player_detection: CollisionShape2D = $CollisionShape2D
@onready var tracker: DynamicObjTracker = $Node2D

func _ready() -> void:
	var sprite_2d: Sprite2D = $Sprite2D
	sprite_2d.z_index = Globals.LAYER_ENTITY
	_chunks = Global.chunks
	_breaker.set_parameters(BREAK_FORCE, TERRAIN_DESTROY_MASK, 5)
	tracker.define_bounds(Rect2(global_position, TERRAIN_DESTROY_MASK.get_size()))
	set_process(false)

func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.owner
	if !parent: return
	
	if parent == Global.player_node:
		_fall()

func _fall() -> void:
	if player_detection:
		player_detection.queue_free()
		set_process(true)

#Falling logic
func _process(delta: float) -> void:
	_timer_self_destroy += delta
	
	if _timer_self_destroy > MAX_FALLING_SEC:
		_destroy()
		return
	
	global_position.y += FALLING_SPEED * delta
	tracker.move(global_position)
	
	var res: Vector2 = _chunks.eval_area_mask(global_position, TERRAIN_DESTROY_MASK, 4)
	
	if _timer_touch > 0.0 or !is_nan(res.y):
		_timer_touch += delta
	
	if _timer_touch > DESTROY_AFTER_TOUCH_SEC:
		_destroy()
	
	#_chunks.break_tiles_mask(self.global_position, TERRAIN_DESTROY_MASK, 2)
	_breaker.break_terrain(global_position)

func _destroy() -> void:
	queue_free()
