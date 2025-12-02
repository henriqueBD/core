class_name Globals
extends Node

#region signals
@warning_ignore_start("unused_signal")

signal player_spawned
signal terrain_break(area: Rect2i)

@warning_ignore_restore("unused_signal")
#endregion

const objs_path: String = "res://entities/"
const CHUNK_SIDE: int = 255
const CHUNK_SIZE: int = CHUNK_SIDE * CHUNK_SIDE
const CHUNK_COMPRESSION_METHOD: int = FileAccess.COMPRESSION_ZSTD
const NO_COLLISION_RAYCAST: float = -INF

var main_node: Node
var chunks: chunk_mng
var player_node: Node2D
