extends Control

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const BACKGROUND_TEXTURE := preload("res://assets/generated/gameplay_stage_v2.png")
const TILE_TEXTURE := preload("res://assets/generated/gameplay_tile_v2.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("221c32"))
	var scale_factor := size.x / DESIGN_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	# Fixed stage geometry follows the same design coordinates as live slots.
	draw_texture_rect(BACKGROUND_TEXTURE, Rect2(Vector2.ZERO, DESIGN_SIZE), false)
	var extra_height := size.y / maxf(scale_factor, 0.001) - DESIGN_SIZE.y
	if extra_height > 0.0:
		var texture_size := BACKGROUND_TEXTURE.get_size()
		# Stretch only the floor from its original start; avoid a repeated-texture seam.
		var floor_start := 1720.0
		draw_texture_rect_region(BACKGROUND_TEXTURE, Rect2(0.0, floor_start, DESIGN_SIZE.x, DESIGN_SIZE.y - floor_start + extra_height), Rect2(0.0, texture_size.y * floor_start / DESIGN_SIZE.y, texture_size.x, texture_size.y * (DESIGN_SIZE.y - floor_start) / DESIGN_SIZE.y))
	var board := get_node_or_null("../BoardController") as Control
	if board == null:
		return
	for index in range(9):
		var slot: Control = board.get_slot(index)
		if slot == null:
			continue
		var depth := slot.scale.x / maxf(scale_factor, 0.001)
		var base := slot.position / scale_factor
		# The feet sit below the box silhouette; the top extends around its base.
		_draw_tile(Rect2(base + Vector2(-15.0, 258.0) * depth, Vector2(320.0, 122.0) * depth))

func _draw_tile(rect: Rect2) -> void:
	draw_texture_rect_region(TILE_TEXTURE, rect, Rect2(45.0, 104.0, 2090.0, 504.0))
