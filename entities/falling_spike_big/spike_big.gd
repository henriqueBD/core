extends Area2D

const MAX_FALLING_SEC: float = 10
const DESTROY_AFTER_TOUCH_SEC: float = 0.2
const FALLING_SPEED: float = 120

static var TERRAIN_DESTROY_MASK: Image = load("res://entities/falling_spike_big/big_spike_destroy_mask.png")

var timer_self_destroy: float = 0.0
var timer_touch: float = 0.0

@onready var player_detection: CollisionShape2D = $CollisionShape2D

var _chunks: chunk_mng

func _ready() -> void:
	var sprite_2d: Sprite2D = $Sprite2D
	sprite_2d.z_index = Globals.LAYER_ENTITY
	_chunks = Global.chunks
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
	timer_self_destroy += delta
	
	if timer_self_destroy > MAX_FALLING_SEC:
		_destroy()
		return
	
	self.global_position.y += FALLING_SPEED * delta
	
	var res: Vector2 = _chunks.eval_area_mask(self.global_position, TERRAIN_DESTROY_MASK, 1)
	
	if timer_touch > 0.0 or !is_nan(res.y):
		timer_touch += delta
	
	if timer_touch > DESTROY_AFTER_TOUCH_SEC:
		_destroy()
	
	_chunks.break_tiles_mask(self.global_position, TERRAIN_DESTROY_MASK, 2)

func _destroy() -> void:
	queue_free()
