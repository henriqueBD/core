extends Sprite2D

const MAX_FALLING_SEC: float = 10
const DESTROY_AFTER_TOUCH_SEC: float = 0.2
const FALLING_SPEED: float = 120
const BREAK_FORCE: int = 2

static var _mask: BitMap = TerrainBreaker.create_bitmap("res://entities/falling_spike_big/big_spike_destroy_mask.png")

var _timer_self_destroy: float = 0.0
var _timer_touch: float = 0.0
var _breaker: TerrainBreaker = TerrainBreaker.init([_mask], BREAK_FORCE, 5, false)
var _chunks: chunk_mng

@onready var tracker: DynamicObjTracker = $DynamicObjTracker

func _ready() -> void:
	z_index = Globals.LAYER_ENTITY
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_fall, true)
	_chunks = Global.chunks
	tracker.define_bounds(Rect2(global_position, _breaker._size))
	set_physics_process(false)

func _on_area_entered(area: Area2D) -> void:
	print(area.name)
	if area.is_in_group("Player"):
		_fall()

func _fall() -> void:
	print("Falling")
	set_physics_process(true)

#Falling logic
func _physics_process(delta: float) -> void:
	_timer_self_destroy += delta
	
	if _timer_self_destroy > MAX_FALLING_SEC:
		_destroy()
		return
	
	global_position.y += FALLING_SPEED * delta
	tracker.move(global_position)
	
	var res: Vector2 = _breaker.eval_area_override_force(global_position, 2)
	
	if _timer_touch > 0.0 or !is_nan(res.y):
		_timer_touch += delta
	
	if _timer_touch > DESTROY_AFTER_TOUCH_SEC:
		_destroy()
	
	#_chunks.break_tiles_mask(self.global_position, TERRAIN_DESTROY_MASK, 2)
	_breaker.break_terrain(global_position)

func _destroy() -> void:
	queue_free()
