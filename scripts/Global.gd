extends Node

const objs_path: String = "res://entities/"

const CHUNK_SIDE: int = 255
const CHUNK_SIZE: int = CHUNK_SIDE * CHUNK_SIDE
const NO_COLLISION_RAYCAST: float = -INF

var chunks: chunk_mng
var player_node: Node2D
