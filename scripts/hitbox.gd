class_name Hitbox
extends Area2D

func _ready() -> void:
	collision_mask = Globals.LAYER_HURTBOX
	collision_layer = Globals.LAYER_HITBOX
	monitorable = false
	monitoring = true

func hit_single_frame() -> void:
	for area: Hurtbox in get_overlapping_areas():
		if area: area.hit_signal.emit(1)
