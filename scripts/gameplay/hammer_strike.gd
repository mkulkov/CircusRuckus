extends Control

const HAMMER_TEXTURE := preload("res://assets/generated/toy_hammer.png")
const IMPACT_ROTATION := 0.0
const IMPACT_CONTACT_LOCAL := Vector2(18.0, 194.0)
const WINDUP_ROTATION := deg_to_rad(135.0)

signal impact(slot_index: int)

var _slot_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190.0, 270.0)
	size = custom_minimum_size
	pivot_offset = Vector2(203.0, 124.0)
	queue_redraw()


func play(target_position: Vector2, slot_index: int, swing_duration: float) -> void:
	_slot_index = slot_index
	# Keep the far edge of the handle fixed as the pivot. The head starts above and
	# to the right, then sweeps in a large arc down onto the clown.
	var impact_position := target_position - pivot_offset - (IMPACT_CONTACT_LOCAL - pivot_offset).rotated(IMPACT_ROTATION)
	position = impact_position
	rotation = WINDUP_ROTATION
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.045)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(118.0), 0.055).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", IMPACT_ROTATION, swing_duration - 0.055).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(_emit_impact)
	tween.tween_property(self, "scale", Vector2(1.08, 0.92), 0.045)
	tween.tween_property(self, "rotation", deg_to_rad(-18.0), 0.070).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.070)
	tween.tween_callback(queue_free)


func _emit_impact() -> void:
	impact.emit(_slot_index)


func _draw() -> void:
	draw_texture_rect(HAMMER_TEXTURE, Rect2(-65.0, -15.0, 300.0, 300.0), false, Color.WHITE)
