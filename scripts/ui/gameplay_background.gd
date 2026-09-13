extends Control

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const BACKGROUND_TEXTURE := preload("res://assets/generated/circus_background.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("8c482b"))
	var scale_factor: float = size.x / DESIGN_SIZE.x
	var origin := Vector2.ZERO
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)

	var visible_design_height := maxf(DESIGN_SIZE.y, size.y / scale_factor)
	draw_texture_rect(
		BACKGROUND_TEXTURE,
		Rect2(Vector2.ZERO, Vector2(DESIGN_SIZE.x, visible_design_height)),
		false
	)
	_draw_wood_board()


func _draw_wood_board() -> void:
	# Deep shadow and front thickness make the board read as a raised stage prop.
	var platform_shadow := PackedVector2Array([
		Vector2(72.0, 724.0), Vector2(1008.0, 724.0),
		Vector2(1068.0, 1668.0), Vector2(12.0, 1668.0),
	])
	draw_colored_polygon(platform_shadow, Color(0.10, 0.035, 0.025, 0.62))

	var front_face := PackedVector2Array([
		Vector2(22.0, 1588.0), Vector2(1058.0, 1588.0),
		Vector2(1022.0, 1665.0), Vector2(58.0, 1665.0),
	])
	draw_colored_polygon(front_face, Color("713317"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(22.0, 1588.0), Vector2(1058.0, 1588.0),
		Vector2(1050.0, 1614.0), Vector2(30.0, 1614.0),
	]), Color("e08a3b"))
	draw_line(Vector2(58.0, 1659.0), Vector2(1022.0, 1659.0), Color("3f1b12"), 10.0)

	var band_edges := [704.0, 842.0, 1010.0, 1205.0, 1400.0, 1588.0]
	var band_colors := [Color("b96b38"), Color("b66234"), Color("aa572e"), Color("9e4d29"), Color("914322")]
	for band_index in range(band_colors.size()):
		draw_colored_polygon(_platform_slice(band_edges[band_index], band_edges[band_index + 1]), band_colors[band_index])

	# Plank seams converge toward the circus entrance to sell forced perspective.
	for seam_index in range(1, 7):
		var top_x := lerpf(74.0, 1006.0, float(seam_index) / 7.0)
		var bottom_x := lerpf(22.0, 1058.0, float(seam_index) / 7.0)
		draw_line(Vector2(top_x, 704.0), Vector2(bottom_x, 1588.0), Color(0.24, 0.09, 0.045, 0.43), 5.0)
		draw_line(Vector2(top_x + 5.0, 704.0), Vector2(bottom_x + 5.0, 1588.0), Color(1.0, 0.55, 0.25, 0.12), 2.0)

	for seam_y in [842.0, 1010.0, 1205.0, 1400.0]:
		var seam_points := _platform_slice(seam_y, seam_y + 1.0)
		draw_line(seam_points[0], seam_points[1], Color(0.24, 0.08, 0.04, 0.52), 7.0)
		draw_line(seam_points[0] + Vector2(0.0, 6.0), seam_points[1] + Vector2(0.0, 6.0), Color(1.0, 0.58, 0.27, 0.16), 3.0)
	for grain_index in range(18):
		var grain_ratio := float(grain_index) / 17.0
		var grain_y := lerpf(744.0, 1540.0, grain_ratio)
		var grain_slice := _platform_slice(grain_y, grain_y + 1.0)
		var start_x := lerpf(grain_slice[0].x, grain_slice[1].x, fmod(grain_ratio * 2.73, 0.72))
		draw_line(Vector2(start_x, grain_y), Vector2(minf(start_x + 125.0 + grain_index * 3.0, grain_slice[1].x), grain_y + 2.0), Color(0.25, 0.09, 0.04, 0.20), 2.0)

	var platform_outline := PackedVector2Array([
		Vector2(74.0, 704.0), Vector2(1006.0, 704.0),
		Vector2(1058.0, 1588.0), Vector2(22.0, 1588.0), Vector2(74.0, 704.0),
	])
	draw_polyline(platform_outline, Color("ef9c48"), 14.0, true)
	draw_line(Vector2(84.0, 720.0), Vector2(996.0, 720.0), Color(1.0, 0.72, 0.40, 0.42), 4.0)
	for corner in [Vector2(80.0, 720.0), Vector2(1000.0, 720.0), Vector2(42.0, 1572.0), Vector2(1038.0, 1572.0)]:
		draw_circle(corner, 9.0, Color("59301d"))
		draw_circle(corner - Vector2(2.0, 2.0), 6.0, Color("d99745"))


func _platform_slice(y_top: float, y_bottom: float) -> PackedVector2Array:
	var top_ratio := (y_top - 704.0) / 884.0
	var bottom_ratio := (y_bottom - 704.0) / 884.0
	return PackedVector2Array([
		Vector2(lerpf(74.0, 22.0, top_ratio), y_top),
		Vector2(lerpf(1006.0, 1058.0, top_ratio), y_top),
		Vector2(lerpf(1006.0, 1058.0, bottom_ratio), y_bottom),
		Vector2(lerpf(74.0, 22.0, bottom_ratio), y_bottom),
	])
