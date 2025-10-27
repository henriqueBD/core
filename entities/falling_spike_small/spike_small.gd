extends Area2D

const MAX_FALLING_SEC: float = 1.0
const FALLING_SPEED: float = 100

var timer_self_destroy: float = 0.0

@onready var player_detection: CollisionShape2D = $player_detection
@onready var spike_collision: CollisionShape2D = $spike_collision

var chunks: chunk_mng
var destroy_rect: Rect2

func _ready() -> void:
	chunks = Global.chunks
	destroy_rect = spike_collision.shape.get_rect()
	destroy_rect.position = to_global(destroy_rect.position)
	set_process(false)

func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.owner
	if !parent: return
	
	if parent == Global.player_node:
		_fall()

func _fall() -> void:
	print("falling")
	if player_detection:
		player_detection.queue_free()
		set_process(true)

#Falling logic
func _process(delta: float) -> void:
	timer_self_destroy += delta
	
	if timer_self_destroy > MAX_FALLING_SEC:
		_bye_bye()
		return
	
	self.global_position.y += FALLING_SPEED * delta
	destroy_rect.position.y = self.global_position.y
	
	chunks.break_tiles(destroy_rect, 1)

func _bye_bye() -> void:
	queue_free()
