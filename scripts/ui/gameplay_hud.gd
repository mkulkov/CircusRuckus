extends Control

signal pause_pressed

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const MOBILE_HUD_VERTICAL_OFFSET := 28.0
const WEB_HUD_VERTICAL_OFFSET := 0.0
const SERIES_TEXTURE := preload("res://assets/ui/tickets/hud_series_v2.png")
const TICKET_TEXTURE := preload("res://assets/ui/tickets/hud_tickets_ru_v1.png")
# Regions reference the approved PNG directly; the artwork is not edited.
const TICKET_REGIONS := {
	&"time": Rect2(61, 68, 802, 216),
	&"score": Rect2(30, 321, 882, 205),
	&"series": Rect2(935, 331, 566, 190),
	&"lives": Rect2(90, 771, 948, 192),
	&"pause": Rect2(1182, 739, 236, 235),
}

const HAMMER_TEXTURE := preload("res://assets/generated/toy_hammer.png")



var _score: int = 0
var _max_combo: int = 0
var _combo: int = 0
var _lives: int = 3
var _remaining_time: float = 25.0
var _round_index: int = 1
var _phase: String = ""
var _pattern: String = ""
var _feedback_text: String = ""
var _feedback_time: float = 0.0
var _message_font: FontVariation
var _pause_button: Button
var _combo_scale: float = 1.0
var _hammer_scales: Array[float] = [1.0, 1.0, 1.0]
var _flying_hammer_visible: bool = false
var _flying_hammer_position: Vector2 = Vector2.ZERO
var _hammer_tweens: Array[Tween] = [null, null, null]
var _flight_tween: Tween
var _panel_styles: Dictionary = {}
var _warning_inset: StyleBoxFlat


func _ready() -> void:
	_message_font = FontVariation.new()
	_message_font.base_font = ThemeDB.fallback_font
	_message_font.variation_embolden = 0.8
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


func set_round(index: int, phase: String, pattern: String = "") -> void:
	_round_index = clampi(index, 1, 9007199254740991)
	_phase = phase
	_pattern = pattern
	queue_redraw()


func set_run_details(max_combo: int, _recovery_hits: int, _recovery_available: bool) -> void:
	var next_max := clampi(max_combo, 0, 9007199254740991)
	if _max_combo == next_max:
		return
	_max_combo = next_max
	queue_redraw()


func show_feedback(text: String) -> void:
	_feedback_text = text
	_feedback_time = 1.6
	queue_redraw()


func set_score(value: int) -> void:
	_score = clampi(value, 0, 9007199254740991)
	queue_redraw()


func set_combo(value: int) -> void:
	_combo = clampi(value, 0, 9007199254740991)
	if value in [3, 5, 10]:
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
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	var vertical_offset := _get_vertical_offset()
	_flying_hammer_visible = true
	_flying_hammer_position = (get_global_transform().affine_inverse() * global_start) / maxf(size.x / DESIGN_SIZE.x, 0.001) - Vector2(0.0, vertical_offset)
	var target := _life_hammer_center(clampi(_lives - 1, 0, 2))
	_flight_tween = create_tween()
	_flight_tween.tween_method(
		func(position_value: Vector2) -> void: _flying_hammer_position = position_value; queue_redraw(),
		_flying_hammer_position,
		target,
		0.42
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_flight_tween.tween_callback(func() -> void: _flying_hammer_visible = false; queue_redraw())


func set_time(value: float) -> void:
	var previous_second := ceili(_remaining_time)
	_remaining_time = maxf(value, 0.0)
	if ceili(_remaining_time) != previous_second:
		queue_redraw()


func set_pause_enabled(value: bool) -> void:
	_pause_button.disabled = not value


func _draw() -> void:
	var scale_factor: float = size.x / DESIGN_SIZE.x
	var origin := Vector2(0.0, _get_vertical_offset() * scale_factor)
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)

	_draw_pause_button(Vector2(74.0, 68.0))
	_draw_ticket_values(scale_factor)
	var message_rect := Rect2(40.0, 222.0, 1000.0, 86.0)
	if not _feedback_text.is_empty():
		var feedback_color := Color("fff1a3")
		var warning := _feedback_text in [tr("BOMB_LIFE"), tr("GLUTTON_ESCAPED"), tr("THREE_MISSES_LIFE")]
		if warning:
			feedback_color = Color("ff9a87")
		elif _feedback_text == tr("HAMMER_CONFUSED"):
			feedback_color = Color("e0b7ff")
		_draw_message_banner(_feedback_text, message_rect, feedback_color, warning)


func _draw_ticket(kind: StringName, rect: Rect2) -> void:
	if kind == &"series":
		draw_texture_rect_region(SERIES_TEXTURE, rect, Rect2(40, 182, 2092, 357))
		return
	draw_texture_rect_region(TICKET_TEXTURE, rect, TICKET_REGIONS[kind])


func _draw_ticket_values(scale_factor: float) -> void:
	_draw_ticket(&"time", Rect2(150, 24, 288, 88))
	_draw_text(_format_time(_remaining_time), Rect2(226, 37, 192, 54), 42, Color.WHITE)
	# Procedural caption: the approved level ticket contains baked campaign text.
	_draw_blank_ticket(Rect2(454, 24, 288, 88))
	_draw_text(tr("PRACTICE_LABEL") if _phase == "tutorial" else tr("ROUND"), Rect2(492, 42, 212, 24), 22, Color.WHITE)
	_draw_text(str(_round_index), Rect2(492, 69, 212, 27), 32, Color.WHITE)
	_draw_ticket(&"lives", Rect2(758, 24, 288, 88))
	for index in range(3):
		_draw_life_hammer(_life_hammer_center(index), index < _lives, _hammer_scales[index], scale_factor)
	if _flying_hammer_visible:
		_draw_life_hammer(_flying_hammer_position, true, 0.72, scale_factor)
	_draw_blank_ticket(Rect2(40, 126, 488, 82))
	_draw_text(tr("SCORE"), Rect2(100, 145, 160, 44), 28, Color.WHITE)
	_draw_text(str(_score), Rect2(280, 145, 188, 44), 34, Color.WHITE)
	if TranslationServer.get_locale().to_lower().begins_with("ru"):
		_draw_ticket(&"series", Rect2(552, 126, 488, 82))
	else:
		_draw_blank_ticket(Rect2(552, 126, 488, 82))
		_draw_text(tr("COMBO"), Rect2(610, 148, 165, 34), 28, Color.WHITE)
	_draw_text(str(_combo), Rect2(790, 138, 190, 28), roundi(32 * _combo_scale), Color.WHITE)
	_draw_text(tr("BEST_COMBO_VALUE") % _max_combo, Rect2(790, 170, 190, 22), 22, Color.WHITE)


func _draw_blank_ticket(rect: Rect2) -> void:
	# Reuse the approved ticket edges and blank paper; keep labels dynamic.
	# The center patches come from the unprinted right half of the series art.
	var cap := minf(rect.size.y * 0.55, rect.size.x * 0.15)
	var trim := rect.size.y * 65.0 / 357.0
	var source_x := [40.0, 1120.0, 1812.0]
	var source_width := [320.0, 650.0, 320.0]
	var source_y := [182.0, 247.0, 474.0]
	var source_height := [65.0, 227.0, 65.0]
	var dest_x := [rect.position.x, rect.position.x + cap, rect.end.x - cap]
	var dest_width := [cap, rect.size.x - cap * 2.0, cap]
	var dest_y := [rect.position.y, rect.position.y + trim, rect.end.y - trim]
	var dest_height := [trim, rect.size.y - trim * 2.0, trim]
	for row in range(3):
		for column in range(3):
			draw_texture_rect_region(SERIES_TEXTURE,
				Rect2(dest_x[column], dest_y[row], dest_width[column], dest_height[row]),
				Rect2(source_x[column], source_y[row], source_width[column], source_height[row]))


func _draw_message_banner(text: String, rect: Rect2, color: Color, warning: bool = false) -> void:
	draw_style_box(_make_panel_style(Color("405579")), rect)
	if warning:
		if _warning_inset == null:
			_warning_inset = StyleBoxFlat.new()
			_warning_inset.bg_color = Color("762333")
			_warning_inset.set_corner_radius_all(12)
		draw_style_box(_warning_inset, rect.grow(-12.0))
	_draw_star(Vector2(rect.position.x + 39.0, rect.get_center().y), 16.0)
	_draw_star(Vector2(rect.end.x - 39.0, rect.get_center().y), 16.0)
	if text.is_empty():
		return
	var available_width := rect.size.x - 120.0
	var lines: Array[String] = []
	var line := ""
	var font_size := 32
	for word in text.to_upper().split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and _message_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > available_width:
			lines.append(line)
			line = word
		else:
			line = candidate
	lines.append(line)
	var line_height := 36.0
	var top := rect.get_center().y - line_height * float(lines.size()) * 0.5
	for index in range(lines.size()):
		var width := _message_font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var baseline := Vector2(rect.get_center().x - width * 0.5, top + float(index) * line_height + _message_font.get_ascent(font_size))
		draw_string_outline(_message_font, baseline, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, Color("251221"))
		draw_string(_message_font, baseline, lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("fff1b8") if warning else color)


func _draw_status_chip(rect: Rect2, text: String, fill: Color) -> void:
	_draw_panel(rect, fill)
	_draw_text(text, rect.grow(-6.0), 25, Color("ff9a87") if fill == Color("a72c2c") else Color("fff1b8"))


func _draw_panel(rect: Rect2, _fill: Color) -> void:
	draw_style_box(_make_panel_style(Color(1.0, 0.91, 0.72, 0.96)), rect)


func _make_panel_style(fill: Color) -> StyleBoxFlat:
	if _panel_styles.has(fill):
		return _panel_styles[fill]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("c78b3c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.02, 0.01, 0.04, 0.25)
	style.shadow_size = 3
	_panel_styles[fill] = style
	return style


func _draw_pause_button(center: Vector2) -> void:
	_draw_ticket(&"pause", Rect2(center - Vector2(44, 44), Vector2(88, 88)))


func _draw_clock(center: Vector2) -> void:
	draw_circle(center, 23.0, Color("efe4d3"))
	draw_arc(center, 23.0, 0.0, TAU, 32, Color("d3ae65"), 2.0, true)
	draw_line(center, center + Vector2(0.0, -15.0), Color("513c35"), 3.0)
	draw_line(center, center + Vector2(10.0, 5.0), Color("513c35"), 3.0)


func _draw_life_hammer(center: Vector2, active: bool, hammer_scale: float = 1.0, design_scale: float = 1.0) -> void:
	var vertical_offset := _get_vertical_offset()
	draw_set_transform((center + Vector2(0.0, vertical_offset)) * design_scale, 0.0, Vector2.ONE * hammer_scale * design_scale)
	var tint := Color.WHITE if active else Color("625c67")
	draw_texture_rect(HAMMER_TEXTURE, Rect2(-30.0, -30.0, 60.0, 60.0), false, tint)
	draw_set_transform(Vector2(0.0, vertical_offset * design_scale), 0.0, Vector2.ONE * design_scale)


func _set_combo_scale(value: float) -> void:
	_combo_scale = value
	queue_redraw()


func _animate_hammer(index: int, restored: bool) -> void:
	if index < 0 or index >= _hammer_scales.size():
		return
	if _hammer_tweens[index] != null and _hammer_tweens[index].is_valid():
		_hammer_tweens[index].kill()
	var tween := create_tween()
	_hammer_tweens[index] = tween
	if restored:
		_hammer_scales[index] = 0.25
		tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 0.25, 1.25, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.25, 1.0, 0.10)
	else:
		tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.0, 1.18, 0.08)
		tween.tween_method(func(value: float) -> void: _hammer_scales[index] = value; queue_redraw(), 1.18, 0.2, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void: _hammer_scales[index] = 1.0; queue_redraw())


func _life_hammer_center(index: int) -> Vector2:
	return Vector2(827 + index * 75, 68)


func _draw_star(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for point_index in range(10):
		var point_radius := radius if point_index % 2 == 0 else radius * 0.45
		var angle := -PI * 0.5 + float(point_index) * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	draw_colored_polygon(points, Color("ffc52f"))


func _draw_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var text_width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var fitted_size := font_size
	if text_width > rect.size.x:
		fitted_size = maxi(1, floori(float(font_size) * rect.size.x / text_width))
	var font := ThemeDB.fallback_font
	var text_width_fitted := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x
	var baseline := Vector2(rect.get_center().x - text_width_fitted * 0.5, rect.get_center().y + (font.get_ascent(fitted_size) - font.get_descent(fitted_size)) * 0.5)
	var ink := Color("59402f")
	if color == Color("ff9a87"):
		ink = Color("a52f35")
	elif color == Color("baffc1"):
		ink = Color("24633b")
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size, ink)


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
