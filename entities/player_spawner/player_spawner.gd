extends Node2D

var _player_scene: PackedScene = preload("res://scenes/player.tscn")
var _spawn_chunk: Vector2i

func _ready() -> void:
	_spawn_chunk = chunk_mng.world_to_chunk_key(self.global_position)

func _process(_delta: float) -> void:
	assert(Global.chunks != null, "WHAT")
	if Global.chunks._chunks_dict.has(_spawn_chunk):
		#Spawn player
		var add_to_main_node: bool = false
		var _player_instace: player_character
		
		if Global.player_node != null: 
			_player_instace = Global.player_node
		else: 
			_player_instace = _player_scene.instantiate()
			add_to_main_node = true
		
		_player_instace.teleport(self.global_position)
		if add_to_main_node: Global.main_node.add_child(_player_instace)
		queue_free()
