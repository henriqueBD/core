extends Area2D

const active_distance_squared: int = 50*50

var _player_cache: Node2D
var _chunks_cache: chunk_mng

func _on_area_entered(area: Area2D) -> void:
	#print("Dmg")
	pass

func _ready() -> void:
	_player_cache = Global.player_node
	_chunks_cache = Global.chunks

func _process(delta: float) -> void:
	if _player_cache.position.distance_squared_to(self.position) < active_distance_squared:
		if _chunks_cache.raycast_general_world(self.position, _player_cache.position) == Global.NO_COLLISION_RAYCAST:
			print("Locked tf in")
