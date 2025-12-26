extends Node2D

const MAX_FALLING_SEC: float = 1.0
const DESTROY_AFTER_TOUCH_SEC: float = 0.1
const FALLING_SPEED: float = 100

static var _mask: BitMap = TerrainBreaker.create_bitmap("res://entities/falling_spike_small/falling_spike_small_mask.png")

var timer_self_destroy: float = 0.0
var timer_touch: float = 0.0
var _breaker: TerrainBreaker = TerrainBreaker.init([_mask], 1, false, 1)

var chunks: chunk_mng

@onready var player_detection: PlayerDetection = $PlayerDetection

func _ready() -> void:
	player_detection.response = _fall
	player_detection.one_shot = true
	chunks = Global.chunks
	set_process(false)

func _fall() -> void:
	print("falling")
	set_process(true)

#Falling logic
func _process(delta: float) -> void:
	timer_self_destroy += delta
	
	if timer_self_destroy > MAX_FALLING_SEC:
		_destroy()
		return
	
	self.global_position.y += FALLING_SPEED * delta
	
	var res: Vector2 = _breaker.eval_area(global_position)
	
	if timer_touch > 0.0 or !is_nan(res.x):
		timer_touch += delta
	
	if timer_touch > DESTROY_AFTER_TOUCH_SEC or !is_nan(res.y):
		_destroy()
	
	_breaker.break_terrain(global_position)

func _destroy() -> void:
	queue_free()
