class_name Hurtbox
extends Area2D

@warning_ignore("unused_signal")
signal hit(damage: float)

func _ready() -> void:
	monitorable = true
	collision_mask = Globals.LAYER_HITBOX
	collision_layer = Globals.LAYER_HURTBOX
