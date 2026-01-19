extends AnimatedSprite2D

const MAX_FALLING_SEC: float = 10
const DESTROY_AFTER_TOUCH_SEC: float = 0.2
const FALLING_SPEED: float = 120
const BREAK_FORCE: int = 2

static var _mask: BitMap = TerrainBreaker.create_bitmap("res://entities/falling_spike/big_spike_destroy_mask.png")

var _timer_self_destroy: float = 0.0
var _timer_touch: float = 0.0
var _breaker: TerrainBreaker = TerrainBreaker.init([_mask], BREAK_FORCE, 5, false)
var _chunks: chunk_mng
var _set_to_break: bool = false

@onready var tracker: DynamicObjTracker = $DynamicObjTracker

func _ready() -> void:
	stop()
	z_index = Globals.LAYER_ENTITY
	var player_detection: PlayerDetection = $PlayerDetection
	player_detection.set_response_enter(_edge_fall, true)
	_chunks = Global.chunks
	tracker.define_bounds(Rect2(global_position, _breaker._size))
	set_physics_process(false)


func _edge_fall() -> void:
	play("pre_fall")
	animation_finished.connect(_fall, CONNECT_ONE_SHOT)

func _fall() -> void:
	stop()
	set_physics_process(true)

func _eval_callback(_angle: float) -> void:
	if _set_to_break: return
	_set_to_break = true
	print("Call")
	_timer_touch = 0.01

#Falling logic
func _physics_process(delta: float) -> void:
	_timer_self_destroy += delta
	
	if _timer_self_destroy > MAX_FALLING_SEC:
		_destroy()
		return
	
	global_position.y += FALLING_SPEED * delta
	tracker.move(global_position)
	
	if _timer_touch > 0.0:
		_timer_touch += delta
	
	if _timer_touch > DESTROY_AFTER_TOUCH_SEC:
		_destroy()
	
	#_breaker.break_terrain(global_position)
	_breaker.eval_break_area(global_position, 2, _eval_callback)

func _destroy() -> void:
	queue_free()
