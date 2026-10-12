extends Control

signal game_start_requested
signal round_continue_requested
signal resume_requested
signal retry_requested
signal menu_requested
signal tutorial_next_requested
signal rules_requested
signal tutorial_continue_requested
signal settings_requested

enum OverlayMode {
	NONE,
	COUNTDOWN,
	TRANSITION,
	PAUSE,
	RESULT,
	TUTORIAL,
}

const DESIGN_SIZE := Vector2(1080.0, 1920.0)
const PANEL_X := 205.0
const PANEL_TOP := 535.0
const PANEL_WIDTH := 670.0
const ACTION_SIZE := Vector2(460.0, 90.0)
const ACTION_GAP := 25.0
const PANEL_BOTTOM_PADDING := 40.0
const COUNTDOWN_GO_EN := preload("res://assets/ui/countdown_go_en.png")
const COUNTDOWN_GO_RU := preload("res://assets/ui/countdown_go_ru.png")
const CONFETTI_COLORS: Array[Color] = [
	Color("ff315d"), Color("ffcf2f"), Color("23d9ff"), Color("39ef89"),
	Color("b65cff"), Color("ff7a22"), Color("fff4b0"), Color("ff4fd8"),
]

var _training_complete := false
var _mode: OverlayMode = OverlayMode.NONE
var _countdown_text: String = ""
var _result_details: Dictionary = {}
var _tutorial_title: String = ""
var _tutorial_body: String = ""
var _tutorial_icon: Texture2D
var _rules_button: Button
var _continue_button: Button
var _result_score: int = 0
var _result_combo: int = 0
var _result_save_error: bool = false
var _resume_button: Button
var _retry_button: Button
var _menu_button: Button
var _advance_button: Button
var _settings_button: Button
var _countdown_is_final := false
var _countdown_burst_time := 0.0
var _confetti: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_button = _create_button(tr("RESUME"))
	_resume_button.name = "ResumeButton"
	_resume_button.pressed.connect(_on_resume_button)
	add_child(_resume_button)
	_retry_button = _create_button(tr("PLAY_AGAIN"))
	_retry_button.name = "RetryButton"
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	add_child(_retry_button)
	_menu_button = _create_button(tr("MENU"))
	_menu_button.name = "MenuButton"
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	add_child(_menu_button)
	_advance_button = _create_button(tr("TUTORIAL_ADVANCE"))
	_advance_button.name = "TutorialAdvanceButton"
	_advance_button.pressed.connect(func() -> void: tutorial_next_requested.emit())
	add_child(_advance_button)
	_settings_button = _create_button(tr("MENU_SETTINGS"))
	_settings_button.name = "OverlaySettingsButton"
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	add_child(_settings_button)
	_rules_button = _create_button(tr("RULES"))
	_rules_button.name = "RulesButton"
	_rules_button.pressed.connect(func() -> void: rules_requested.emit())
	add_child(_rules_button)
	_continue_button = _create_button(tr("RESUME"))
	_continue_button.name = "TutorialContinueButton"
	_continue_button.pressed.connect(_on_continue_button)
	add_child(_continue_button)
	resized.connect(_layout_buttons)
	_layout_buttons()
	hide_overlay()


func show_countdown(text: String) -> void:
	_countdown_text = text
	_countdown_is_final = not text.is_empty() and text not in ["3", "2", "1"]
	if _countdown_is_final:
		_start_countdown_burst()
	_rules_button.visible = false
	_continue_button.visible = false
	_mode = OverlayMode.COUNTDOWN if not text.is_empty() else OverlayMode.NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if _mode != OverlayMode.NONE else Control.MOUSE_FILTER_IGNORE
	_resume_button.visible = false
	_retry_button.visible = false
	_menu_button.visible = false
	_advance_button.visible = false
	_settings_button.visible = false
	_layout_buttons()
	queue_redraw()


func _on_resume_button() -> void:
	if is_showing_round_result():
		round_continue_requested.emit()
	else:
		resume_requested.emit()


func show_round_result(round_index: int, score: int, total_score: int, combo: int, lives: int, save_error: bool = false, practice: bool = false) -> void:
	hide_overlay()
	_result_details = {"round_result": true, "practice": practice, "round_index": round_index, "total_score": total_score, "lives": lives}
	_result_score = score
	_result_combo = combo
	_result_save_error = save_error
	_mode = OverlayMode.RESULT
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.text = tr("RESUME")
	_resume_button.visible = true
	_layout_buttons()
	queue_redraw()


func is_showing_round_result() -> bool:
	return _mode == OverlayMode.RESULT and bool(_result_details.get("round_result", false))


func show_pause() -> void:
	_rules_button.visible = true
	_continue_button.visible = false
	_mode = OverlayMode.PAUSE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.visible = true
	_retry_button.visible = true
	_retry_button.text = tr("RESTART")
	_menu_button.visible = true
	_advance_button.visible = false
	_settings_button.visible = true
	_layout_buttons()
	queue_redraw()


func show_run_result(score: int, max_combo: int, rounds: int, active_seconds: float, previous_best: int, save_error: bool = false) -> void:
	hide_overlay()
	_result_details = {"rounds": rounds, "active_seconds": active_seconds, "previous_best": previous_best}
	_mode = OverlayMode.RESULT
	_result_score = score
	_result_combo = max_combo
	_result_save_error = save_error
	mouse_filter = Control.MOUSE_FILTER_STOP
	_retry_button.visible = true
	_retry_button.text = tr("PLAY_AGAIN")
	_menu_button.visible = true
	_layout_buttons()
	queue_redraw()


func show_transition(text: String) -> void:
	hide_overlay()
	_mode = OverlayMode.TRANSITION
	_countdown_text = text
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_tutorial_advance(enabled: bool) -> void:
	_advance_button.visible = enabled and _mode == OverlayMode.NONE
	_layout_buttons()


func _on_continue_button() -> void:
	if _training_complete:
		game_start_requested.emit()
	else:
		tutorial_continue_requested.emit()


func show_training_complete() -> void:
	show_tutorial(tr("TRAINING_COMPLETE_TITLE"), tr("TRAINING_COMPLETE_BODY"))
	_training_complete = true
	_continue_button.text = tr("START_GAME")


func is_showing_training_complete() -> bool:
	return _mode == OverlayMode.TUTORIAL and _training_complete


func show_tutorial(title: String, body: String, icon: Texture2D = null) -> void:
	hide_overlay()
	_mode = OverlayMode.TUTORIAL
	_tutorial_title = title
	_tutorial_body = body
	_tutorial_icon = icon
	_continue_button.text = tr("RESUME")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_continue_button.visible = true
	_layout_buttons()
	queue_redraw()


func is_showing_tutorial() -> bool:
	return _mode == OverlayMode.TUTORIAL


func hide_overlay() -> void:
	_training_complete = false
	_rules_button.visible = false
	_continue_button.visible = false
	_mode = OverlayMode.NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_button.visible = false
	_retry_button.visible = false
	_menu_button.visible = false
	_advance_button.visible = false
	_settings_button.visible = false
	_layout_buttons()
	queue_redraw()


func is_showing_pause() -> bool:
	return _mode == OverlayMode.PAUSE


func is_showing_result() -> bool:
	return _mode == OverlayMode.RESULT


func is_showing_countdown() -> bool:
	return _mode == OverlayMode.COUNTDOWN


func is_showing_save_error() -> bool:
	return _mode == OverlayMode.RESULT and _result_save_error


func _draw() -> void:
	if _mode == OverlayMode.NONE and _confetti.is_empty():
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)

	if _mode == OverlayMode.COUNTDOWN:
		_draw_countdown()
	elif _mode == OverlayMode.TRANSITION:
		_draw_text(_countdown_text, Rect2(100, 660, 880, 100), 54, Color.WHITE)
	elif _mode == OverlayMode.PAUSE:
		_draw_pause()
	elif _mode == OverlayMode.TUTORIAL:
		_draw_tutorial()
	elif _mode == OverlayMode.RESULT:
		_draw_result()
	_draw_confetti()


func _draw_countdown() -> void:
	if not _countdown_is_final:
		_draw_text(_countdown_text, Rect2(410.0, 670.0, 260.0, 170.0), 118, Color.WHITE)
		return
	var texture := COUNTDOWN_GO_RU if TranslationServer.get_locale().begins_with("ru") else COUNTDOWN_GO_EN
	var reveal := clampf(_countdown_burst_time / 0.16, 0.0, 1.0)
	var fade := 1.0 - clampf((_countdown_burst_time - 0.38) / 0.24, 0.0, 1.0)
	var pop_scale := lerpf(0.45, 1.08, sin(reveal * PI * 0.5))
	var target_size := Vector2(650.0, 230.0) if texture == COUNTDOWN_GO_RU else Vector2(470.0, 260.0)
	target_size *= pop_scale
	var target_rect := Rect2(Vector2(540.0, 760.0) - target_size * 0.5, target_size)
	draw_texture_rect(texture, target_rect, false, Color(1.0, 1.0, 1.0, fade))


func _process(delta: float) -> void:
	if not _countdown_is_final and _confetti.is_empty():
		return
	_countdown_burst_time += delta
	for piece in _confetti:
		piece.position += piece.velocity * delta
		piece.velocity.y += 980.0 * delta
		piece.rotation += piece.spin * delta
		piece.life -= delta
	for index in range(_confetti.size() - 1, -1, -1):
		if float(_confetti[index].life) <= 0.0:
			_confetti.remove_at(index)
	queue_redraw()


func _start_countdown_burst() -> void:
	_countdown_burst_time = 0.0
	_confetti.clear()
	var random := RandomNumberGenerator.new()
	random.seed = 0xC1AC05
	for index in range(92):
		var angle := random.randf_range(-PI * 0.92, -PI * 0.08)
		var speed := random.randf_range(430.0, 980.0)
		_confetti.append({
			"position": Vector2(540.0 + random.randf_range(-105.0, 105.0), 760.0 + random.randf_range(-25.0, 25.0)),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"rotation": random.randf_range(0.0, TAU),
			"spin": random.randf_range(-13.0, 13.0),
			"size": Vector2(random.randf_range(10.0, 25.0), random.randf_range(5.0, 13.0)),
			"color": CONFETTI_COLORS[index % CONFETTI_COLORS.size()],
			"life": random.randf_range(0.72, 1.18),
			"shape": index % 5,
		})


func _draw_confetti() -> void:
	for piece in _confetti:
		var alpha := clampf(float(piece.life) / 0.3, 0.0, 1.0)
		var color: Color = piece.color
		color.a = alpha
		var transform := Transform2D(float(piece.rotation), piece.position)
		draw_set_transform_matrix(transform)
		var piece_size: Vector2 = piece.size
		match int(piece.shape):
			0:
				draw_rect(Rect2(-piece_size * 0.5, piece_size), color)
				draw_line(Vector2(-piece_size.x * 0.28, 0.0), Vector2(piece_size.x * 0.28, 0.0), Color(1, 1, 1, alpha * 0.9), 2.0)
			1:
				var diamond := PackedVector2Array([Vector2(0, -piece_size.x * 0.55), Vector2(piece_size.x * 0.5, 0), Vector2(0, piece_size.x * 0.55), Vector2(-piece_size.x * 0.5, 0)])
				draw_colored_polygon(diamond, color)
				draw_circle(Vector2(-1.5, -2.0), 2.3, Color(1, 1, 1, alpha))
			2:
				draw_circle(Vector2.ZERO, piece_size.x * 0.42, color)
				draw_circle(Vector2(-piece_size.x * 0.12, -piece_size.x * 0.14), piece_size.x * 0.12, Color(1, 1, 1, alpha * 0.95))
			3:
				var ribbon := PackedVector2Array([Vector2(-piece_size.x * 0.6, -piece_size.y), Vector2(-piece_size.x * 0.12, piece_size.y), Vector2(piece_size.x * 0.6, -piece_size.y * 0.5), Vector2(piece_size.x * 0.12, piece_size.y)])
				draw_polyline(ribbon, color, 5.0, true)
			_:
				draw_line(Vector2(-piece_size.x * 0.55, 0), Vector2(piece_size.x * 0.55, 0), color, 4.0)
				draw_line(Vector2(0, -piece_size.x * 0.55), Vector2(0, piece_size.x * 0.55), Color(1, 1, 1, alpha), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), Color(0.05, 0.02, 0.10, 0.68))
	_draw_modal_panel()
	_draw_text(tr("PAUSE_TITLE"), Rect2(315.0, 620.0, 450.0, 95.0), 68, Color("ffe190"))
	_draw_text(tr("PAUSE_MESSAGE"), Rect2(315.0, 720.0, 450.0, 60.0), 34, Color.WHITE)


func _draw_tutorial() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(DESIGN_SIZE.x, maxf(DESIGN_SIZE.y, size.y / maxf(size.x / DESIGN_SIZE.x, 0.001)))), Color(0.05, 0.02, 0.10, 0.78))
	_draw_modal_panel()
	_draw_text(_tutorial_title, Rect2(245.0, 570.0, 590.0, 80.0), 44, Color("ffe190"))
	if _tutorial_icon != null:
		draw_texture_rect(_tutorial_icon, Rect2(460.0, 655.0, 160.0, 160.0), false)
	var lines := _wrap_text(_tutorial_body, 560.0, 32)
	for index in range(lines.size()):
		_draw_text(lines[index], Rect2(260.0, 830.0 + index * 46.0, 560.0, 46.0), 32, Color.WHITE)


func _wrap_text(text: String, width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var font := ThemeDB.fallback_font
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var candidate := word if line.is_empty() else line + " " + word
			if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				lines.append(line)
				line = word
			else:
				line = candidate
		lines.append(line)
	return lines


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(DESIGN_SIZE.x, maxf(DESIGN_SIZE.y, size.y / maxf(size.x / DESIGN_SIZE.x, 0.001)))), Color(0.05, 0.02, 0.10, 0.70))
	_draw_modal_panel()
	var title := tr("PRACTICE_RESULT_TITLE" if bool(_result_details.get("practice", false)) else "ROUND_RESULT_TITLE") % int(_result_details.round_index) if is_showing_round_result() else tr("RUN_COMPLETE")
	_draw_text(title, Rect2(245.0, 565.0, 590.0, 85.0), 46, Color("ffe190"))
	var lines := _get_result_lines()
	for index in range(lines.size()):
		_draw_text(lines[index], Rect2(240.0, 670.0 + index * 48.0, 600.0, 46.0), 30, Color.WHITE)


func _get_result_lines() -> Array[String]:
	if is_showing_round_result():
		var round_lines: Array[String] = [tr("ROUND_SCORE_VALUE") % _result_score, tr("TOTAL_SCORE_VALUE") % int(_result_details.total_score), tr("BEST_COMBO_VALUE") % _result_combo, tr("ROUND_LIVES_VALUE") % int(_result_details.lives)]
		if _result_save_error:
			round_lines.append(tr("PROGRESS_NOT_SAVED"))
		return round_lines
	var total := maxi(0, floori(float(_result_details.get("active_seconds", 0.0))))
	var duration := "%d:%02d" % [total / 60, total % 60]
	var previous_best := int(_result_details.get("previous_best", 0))
	var lines: Array[String] = [tr("SCORE_VALUE") % _result_score, tr("HISTORICAL_BEST") % previous_best, tr("BEST_COMBO_VALUE") % _result_combo, tr("RUN_ROUNDS") % int(_result_details.get("rounds", 0)), tr("RUN_TIME") % duration]
	if _result_score > previous_best and not _result_save_error:
		lines.append(tr("NEW_RECORD"))
	if _result_save_error:
		lines.append(tr("PROGRESS_NOT_SAVED"))
	var wrapped: Array[String] = []
	for line in lines:
		wrapped.append_array(_wrap_text(line, 580.0, 30))
	return wrapped


func _draw_modal_panel() -> void:
	var style := CircusUIStyle.panel_style()
	draw_style_box(style, _get_modal_panel_rect())


func _get_modal_panel_rect() -> Rect2:
	var action_count := 0
	for button in [_resume_button, _retry_button, _advance_button, _menu_button, _settings_button, _rules_button, _continue_button]:
		if button != null and button.visible:
			action_count += 1
	var action_start_y := _get_action_start_y()
	var panel_bottom := action_start_y + action_count * ACTION_SIZE.y + maxi(0, action_count - 1) * ACTION_GAP + PANEL_BOTTOM_PADDING
	return Rect2(PANEL_X, PANEL_TOP, PANEL_WIDTH, panel_bottom - PANEL_TOP)


func _draw_text(text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var measured := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted := font_size if measured <= rect.size.x else maxi(12, floori(font_size * rect.size.x / measured))
	CircusUIStyle.draw_text(self, text, rect, fitted, color, 3)


func _create_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	CircusUIStyle.apply_button(button, 34, true)
	return button


func _get_action_start_y() -> float:
	if _mode == OverlayMode.RESULT:
		return maxf(1060.0, 680.0 + _get_result_lines().size() * 48.0)
	if _mode == OverlayMode.TUTORIAL:
		return maxf(1050.0, 840.0 + _wrap_text(_tutorial_body, 560.0, 32).size() * 46.0)
	return 800.0


func _layout_buttons() -> void:
	if _resume_button == null:
		return
	var scale_factor := size.x / DESIGN_SIZE.x
	if _mode == OverlayMode.NONE:
		var hud_offset := 0.0 if OS.has_feature("web") else 28.0
		_advance_button.position = Vector2(310, 334 + hud_offset) * scale_factor
		_advance_button.size = ACTION_SIZE * scale_factor
		_advance_button.add_theme_font_size_override("font_size", maxi(16, roundi(30 * scale_factor)))
		return
	var action_start_y := _get_action_start_y()
	var visible_buttons: Array[Button] = []
	for button in [_resume_button, _retry_button, _advance_button, _menu_button, _settings_button, _rules_button, _continue_button]:
		if button.visible:
			visible_buttons.append(button)
	for index in range(visible_buttons.size()):
		var button := visible_buttons[index]
		button.position = Vector2(310.0, action_start_y + index * (ACTION_SIZE.y + ACTION_GAP)) * scale_factor
		button.size = ACTION_SIZE * scale_factor
		button.add_theme_font_size_override("font_size", maxi(16, roundi(34.0 * scale_factor)))
	_settings_button.size = Vector2(460.0, 90.0) * scale_factor
	_resume_button.add_theme_font_size_override("font_size", maxi(20, roundi(34.0 * scale_factor)))
	_retry_button.add_theme_font_size_override("font_size", maxi(20, roundi(34.0 * scale_factor)))
	_advance_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
	_menu_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
	_settings_button.add_theme_font_size_override("font_size", maxi(20, roundi(31.0 * scale_factor)))
