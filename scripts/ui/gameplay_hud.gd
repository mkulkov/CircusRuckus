extends Control

signal pause_pressed

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const MOBILE_HUD_VERTICAL_OFFSET := 112.0
const WEB_HUD_VERTICAL_OFFSET := 0.0
const HAMMER_TEXTURE := preload("res://assets/generated/toy_hammer.png")

var _score: int = 0
var _target_score: int = 150
var _combo: int = 0
var _lives: int = 3
var _remaining_time: float = 60.0
var _level_id: int = 1
var _golden_hits: int = 0
var _required_golden_hits: int = 0
var _confusion_remaining: int = 0
var _feedback_text: String = ""
var _feedback_time: float = 0.0
var _pause_button: Button
var _combo_scale: float = 1.0
var _hammer_scales: Array[float] = [1.0, 1.0, 1.0]
var _flying_hammer_visible: bool = false
var _flying_hammer_position: Vector2 = Vector2.ZERO
var _animation_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.flat = true
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.tooltip_text = tr("PAUSE")
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(_pause_button)
	resized.connect(_layout_pause_button)
	_layout_pause_button()
	queue_redraw()


func _process(delta: float) -> void:
	if _feedback_time <= 0.0:
		return
	_feedback_time = maxf(_feedback_time - delta, 0.0)
	if _feedback_time <= 0.0:
		_feedback_text = ""
	queue_redraw()


func set_level(value: int, target_score: int, required_golden: int = 0) -> void:
	_level_id = value
	_target_score = maxi(target_score, 0)
	_required_golden_hits = required_golden
	queue_redraw()


func set_golden_progress(value: int) -> void:
	_golden_hits = value
	queue_redraw()


func set_confusion(value: int) -> void:
	_confusion_remaining = maxi(value, 0)
	queue_redraw()


func show_feedback(text: String) -> void:
	_feedback_text = text
	_feedback_time = 1.05
	queue_redraw()


func set_score(value: int) -> void:
	_score = value
	queue_redraw()


func set_combo(value: int) -> void:
	_combo = value
	if value >= 3:
		_combo_scale = 1.0
		var tween := create_tween()
		tween.tween_method(_set_combo_scale, 1.0, 1.28, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_combo_scale, 1.28, 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func set_lives(value: int) -> void:
	var next_lives := clampi(value, 0, 3)
	if next_lives != _lives:
		var changed_index := next_lives if next_lives < _lives else next_lives - 1
		_animate_hammer(changed_index, next_lives > _lives)
	_lives = next_lives
	queue_redraw()


func fly_hammer_to_hud(global_start: Vector2) -> void:
	var vertical_offset := _get_vertical_offset()
	_flying_hammer_visible = true
	_flying_hammer_position = (get_global_transform().affine_inverse() * global_start) / maxf(size.x / DESIGN_SIZE.x, 0.001) - Vector2(0.0, vertical_offset)
	var target := Vector2(790.0 + float(clampi(_lives, 0, 2)) * 92.0, 77.0)
	var tween := create_tween()
	tween.tween_method(
		func(position_value: Vector2) -> void: _flying_hammer_position = position_value; queue_redraw(),
		_flying_hammer_position,
		target,
		0.42
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _flying_hammer_visible = false; queue_redraw())


func set_time(value: float) -> void:
	_remaining_time = maxf(value, 0.0)
	queue_redraw()


func set_pause_enabled(value: bool) -> void:
	_pause_button.disabled = not value


func _draw() -> void:
	var scale_factor: float = size.x / DESIGN_SIZE.x
	var origin := Vector2(0.0, _get_vertical_offset() * scale_factor)
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)

	_draw_pause_button(Vector2(74.0, 76.0))
	_draw_panel(Rect2(145.0, 36.0, 220.0, 92.0), Color("724023"))
	_draw_text(tr("LEVEL_VALUE") % _level_id, Rect2(154.0, 56.0, 202.0, 54.0), 29, Color("ffe48a"))

	_draw_panel(Rect2(390.0, 24.0, 325.0, 112.0), Color("9e2f2f"))
	_draw_clock(Vector2(442.0, 80.0))
	_draw_text(_format_time(_remaining_time), Rect2(478.0, 48.0, 210.0, 65.0), 54, Color.WHITE)

	_draw_panel(Rect2(748.0, 24.0, 292.0, 112.0), Color("254f94"))
	for hammer_index in range(3):
		_draw_life_hammer(Vector2(790.0 + hammer_index * 92.0, 77.0), hammer_index < _lives, _hammer_scales[hammer_index], scale_factor)
	if _flying_hammer_visible:
		_draw_life_hammer(_flying_hammer_position, true, 0.72, scale_factor)

	_draw_panel(Rect2(92.0, 158.0, 345.0, 94.0), Color("67391f"))
	_draw_star(Vector2(130.0, 205.0), 25.0)
	_draw_text(tr("SCORE"), Rect2(164.0, 180.0, 82.0, 48.0), 24, Color("ffe08a"))
	_draw_text("%d/%d" % [_score, _target_score], Rect2(245.0, 173.0, 176.0, 57.0), 32, Color.WHITE)

	_draw_panel(Rect2(642.0, 158.0, 345.0, 94.0), Color("67391f"))
	_draw_text(tr("COMBO"), Rect2(673.0, 180.0, 145.0, 48.0), 31, Color("ffe08a"))
	var combo_rect := Rect2(838.0, 170.0, 122.0, 62.0)
	var combo_size := 54 * _combo_scale
	_draw_text("x%d" % _combo, combo_rect, roundi(combo_size), Color.WHITE)

	if _required_golden_hits > 0:
		_draw_status_chip(Rect2(92.0, 270.0, 270.0, 58.0), tr("GOLD_VALUE") % [_golden_hits, _required_golden_hits], Color("bb7a12"))
	if _confusion_remaining > 0:
		_draw_status_chip(Rect2(718.0, 270.0, 270.0, 58.0), tr("CONFUSION_VALUE") % _confusion_remaining, Color("633b91"))
	if not _feedback_text.is_empty():
		var feedback_color := Color("fff1a3")
		if _feedback_text == tr("BOMB_LIFE") or _feedback_text == tr("GLUTTON_ESCAPED"):
			feedback_color = Color("ff9a87")
		elif _feedback_text.begins_with(tr("CONFUSION_STRIKES").get_slice("%d", 0)) or _feedback_text == tr("HAMMER_CONFUSED"):
			feedback_color = Color("e0b7ff")
		_draw_text(_feedback_text, Rect2(270.0, 302.0, 540.0, 72.0), 36, feedback_color)


func _draw_status_chip(rect: Rect2, text: String, fill: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("ffd166")
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	draw_style_box(style, rect)
	_draw_text(text, rect.grow(-6.0), 25, Color.WHITE)


func _draw_panel(rect: Rect2, fill: Color) -> void:
	draw_style_box(_make_panel_style(fill), rect)
	draw_line(rect.position + Vector2(16.0, 12.0), Vector2(rect.end.x - 16.0, rect.position.y + 12.0), Color(1.0, 0.72, 0.40, 0.34), 3.0, true)
	for corner in [rect.position + Vector2(13.0, 13.0), rect.end - Vector2(13.0, 13.0), Vector2(rect.end.x - 13.0, rect.position.y + 13.0), Vector2(rect.position.x + 13.0, rect.end.y - 13.0)]:
		draw_circle(corner, 5.0, Color("ffc64f"))


func _make_panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("e79b31")
	style.set_border_width_all(7)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.12, 0.04, 0.02, 0.55)
	style.shadow_size = 7
	return style


func _draw_pause_button(center: Vector2) -> void:
	draw_circle(center + Vector2(4.0, 7.0), 57.0, Color(0.08, 0.03, 0.15, 0.45))
	draw_circle(center, 56.0, Color("254f94"))
	draw_arc(center, 50.0, 0.0, TAU, 48, Color("8ec6ff"), 5.0, true)
	draw_rect(Rect2(center + Vector2(-19.0, -22.0), Vector2(12.0, 44.0)), Color.WHITE, true)
	draw_rect(Rect2(center + Vector2(7.0, -22.0), Vector2(12.0, 44.0)), Color.WHITE, true)


func _draw_clock(center: Vector2) -> void:
	draw_circle(center, 35.0, Color("efe4d3"))
	draw_arc(center, 35.0, 0.0, TAU, 32, Color("5b2e22"), 6.0, true)
	draw_line(center, center + Vector2(0.0, -20.0), Color("5b2e22"), 5.0)
	draw_line(center, center + Vector2(13.0, 6.0), Color("5b2e22"), 5.0)


func _draw_life_hammer(center: Vector2, active: bool, hammer_scale: float = 1.0, design_scale: float = 1.0) -> void:
	var vertical_offset := _get_vertical_offset()
	draw_set_transform((center + Vector2(0.0, vertical_offset)) * design_scale, 0.0, Vector2.ONE * hammer_scale * design_scale)
	var tint := Color.WHITE if active else Color("625c67")
	draw_texture_rect(HAMMER_TEXTURE, Rect2(-42.0, -42.0, 84.0, 84.0), false, tint)
	draw_set_transform(Vector2(0.0, vertical_offset * design_scale), 0.0, Vector2.ONE * design_scale)


func _set_combo_scale(value: float) -> void:
	_combo_scale = value
	queue_redraw()


func _animate_hammer(index: int, restored: bool) -> void:
	if index < 0 or index >= _hammer_scales.size():
		return
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.kill()
	_animation_tween = create_tween()
	if restored:
		_hammer_scales[index] = 0.25
		_animation_tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 0.25, 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_animation_tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.25, 1.0, 0.10)
	else:
		_animation_tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.0, 1.18, 0.08)
		_animation_tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.18, 0.2, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_animation_tween.tween_callback(func() -> void: _hammer_scales[index] = 1.0; queue_redraw())


func _draw_star(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for point_index in range(10):
		var point_radius := radius if point_index % 2 == 0 else radius * 0.45
		var angle := -PI * 0.5 + float(point_index) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	draw_colored_polygon(points, Color("ffc52f"))


func _draw_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	CircusUIStyle.draw_text(self, text, rect, font_size, color, 2)


func _layout_pause_button() -> void:
	if _pause_button == null:
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	_pause_button.position = Vector2(10.0, 10.0 + _get_vertical_offset()) * scale_factor
	_pause_button.size = Vector2(128.0, 128.0) * scale_factor


func _get_vertical_offset() -> float:
	return WEB_HUD_VERTICAL_OFFSET if OS.has_feature("web") else MOBILE_HUD_VERTICAL_OFFSET


func _format_time(value: float) -> String:
	var total_seconds := ceili(value)
	return "%02d:%02d" % [floori(total_seconds / 60.0), total_seconds % 60]
