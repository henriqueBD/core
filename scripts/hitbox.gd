class_name Hitbox
extends Area2D

var ingone_RIDS: Array[RID]

func _ready() -> void:
	collision_mask = Globals.LAYER_HURTBOX
	collision_layer = Globals.LAYER_HITBOX
	monitorable = false
	monitoring = true

func hit_single_frame() -> void:
	for area: Hurtbox in get_overlapping_areas():
		if area: area.hit.emit(1)

func hit_single_frame_ignore_RID() -> void:
	for area: Hurtbox in get_overlapping_areas():
		if area.get_rid() not in ingone_RIDS: area.hit.emit(1)
