extends Control

const BOX_TEXTURE := preload("res://assets/generated/open_box.png")

var _lid_open: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func set_lid_open(value: float) -> void:
	_lid_open = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _lid_open <= 0.001:
		return
	# Repaint only the lower half above the clown so the character remains inside
	# the cavity while the lid and rear rim stay behind it.
	draw_texture_rect_region(
		BOX_TEXTURE,
		# The open-box source is aligned lower than the closed asset so the
		# front face stays on the same physical baseline throughout the lid tween.
		Rect2(-7.0, 223.0, 304.0, 160.0),
		Rect2(0.0, 624.0, 1254.0, 630.0),
		Color(1.0, 1.0, 1.0, _lid_open)
	)
